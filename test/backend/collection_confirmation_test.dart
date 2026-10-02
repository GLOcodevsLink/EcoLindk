import 'dart:convert';

import 'package:ecolindk/core/rewards_config.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/services/collection_service.dart';
import 'package:ecolindk/services/geocoding_service.dart';
import 'package:ecolindk/services/live_tracking_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CollectionService service;
  late String id;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = CollectionService(
      firestore: db,
      geocoding: GeocodingService(client: MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'address': {'suburb': 'Bastos', 'city': 'Yaoundé'}
          })),
          200))),
    );
    // Un post de 6 kg de plastique, publié par le fournisseur.
    id = (await service.createRequest(
      householdUid: 'supplier',
      householdName: 'Awa',
      imageUrl: 'firestore://wastePhotos/p1',
      description: 'Plastic bottles',
      category: WasteCategory.plastic,
      quantityRange: '6 kg',
      aiRequested: false,
      address: 'Bastos, Yaoundé',
      latitude: 3.8950,
      longitude: 11.5100,
      locationIsApproximate: false,
    ))
        .id;
  });

  Future<CollectionRequest> reload() async => (await service.watchRequest(id).first)!;
  Future<List<String>> notificationTypes(String uid) async =>
      (await db.collection('notifications').doc(uid).collection('items').get())
          .docs
          .map((d) => d.data()['type'] as String)
          .toList();
  Future<int?> walletBalance(String uid) async =>
      ((await db.doc('wallets/$uid').get()).data()?['pointsBalance'] as num?)?.toInt();

  Future<void> acceptAndSubmit({double weight = 7, double price = 450}) async {
    await service.acceptRequest(id, collectorUid: 'collector', collectorName: 'Paul');
    await service.startCollection(id);
    await service.submitCollectionResult(id, weightKg: weight, priceFcfa: price);
  }

  group('Accepting and starting the pickup', () {
    test('a collector accepts the post and the supplier is notified', () async {
      await service.acceptRequest(id, collectorUid: 'collector', collectorName: 'Paul');
      final r = await reload();
      expect(r.status, RequestStatus.accepted);
      expect(r.collectorUid, 'collector');
      expect(await notificationTypes('supplier'), contains('requestAccepted'));
    });

    test('only one collector can accept a post', () async {
      await service.acceptRequest(id, collectorUid: 'collector', collectorName: 'Paul');
      await expectLater(service.acceptRequest(id, collectorUid: 'other', collectorName: 'Marie'), throwsStateError);
      expect((await reload()).collectorUid, 'collector');
    });

    test('starting the pickup notifies the supplier to share their location', () async {
      await service.acceptRequest(id, collectorUid: 'collector', collectorName: 'Paul');
      await service.startCollection(id);
      expect((await reload()).collectionStartedAt, isNotNull);
      expect(await notificationTypes('supplier'), contains('statusChanged'));
    });
  });

  group('Collection form (collector)', () {
    setUp(() async {
      await service.acceptRequest(id, collectorUid: 'collector', collectorName: 'Paul');
    });

    test('a weight within 5 kg of the declared weight is accepted', () async {
      await service.submitCollectionResult(id, weightKg: 11, priceFcfa: 500); // 6 + 5
      final r = await reload();
      expect(r.status, RequestStatus.inProgress);
      expect(r.pendingWeightKg, 11);
      expect(r.pendingPriceFcfa, 500);
    });

    test('a weight more than 5 kg away is rejected and nothing is saved', () async {
      await expectLater(service.submitCollectionResult(id, weightKg: 11.5, priceFcfa: 500), throwsFormatException);
      await expectLater(service.submitCollectionResult(id, weightKg: 0.5, priceFcfa: 500), throwsFormatException);
      expect((await reload()).status, RequestStatus.accepted);
    });

    test('an invalid price is rejected', () async {
      await expectLater(service.submitCollectionResult(id, weightKg: 6, priceFcfa: 0), throwsFormatException);
    });

    test('submitting the form creates the QR code to scan and notifies the supplier', () async {
      await service.submitCollectionResult(id, weightKg: 7, priceFcfa: 450);
      final r = await reload();
      expect(r.scanCode, hasLength(10));
      expect(r.qrPayload, 'ecolindk:collection:$id:${r.scanCode}');
      expect(await notificationTypes('supplier'), contains('statusChanged'));
    });
  });

  group('Confirmation by the supplier (QR scan)', () {
    test('accepting after the scan completes the transaction', () async {
      await acceptAndSubmit(weight: 7, price: 450);
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);

      final r = await reload();
      expect(r.status, RequestStatus.completed);
      expect(r.weightKg, 7);
      expect(r.valueFcfa, 450);
      expect(r.completedAt, isNotNull);
      expect(r.scanCode, isNull);
      expect(await notificationTypes('collector'), contains('requestCompleted'));
    });

    test('the supplier is credited points at the rate shown in the app', () async {
      await acceptAndSubmit(weight: 7);
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);

      final expected = RewardsConfig.pointsForCollection(WasteCategory.plastic, 7).round(); // 3 P/kg × 7
      expect(expected, 21);
      expect((await reload()).pointsEarned, expected);
      expect(await walletBalance('supplier'), expected);
      expect(await notificationTypes('supplier'), contains('pointsCredited'));
    });

    test('the collector commission is calculated from the commission rate', () async {
      await acceptAndSubmit(weight: 7);
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);

      final expected = RewardsConfig.commissionForCollection(WasteCategory.plastic, 7); // 10 FCFA/kg × 7
      expect((await reload()).commissionFcfa, expected);
      expect(expected, 70);
    });

    test('the completed pickup appears in the collector history', () async {
      await acceptAndSubmit();
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);
      final history = await service.watchCollectorHistory('collector').first;
      expect(history.map((r) => r.id), [id]);
    });

    test('live tracking positions are deleted after confirmation', () async {
      await acceptAndSubmit();
      await LiveTrackingService(firestore: db).updatePosition(id, TrackingRole.collector, 3.89, 11.51);
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);
      expect((await db.collection('liveTracking').doc(id).get()).exists, isFalse);
    });

    test('rejecting after the scan sends the form back to the collector', () async {
      await acceptAndSubmit();
      await service.rejectCollectionResult(id, scanCode: (await reload()).scanCode!);

      final r = await reload();
      expect(r.status, RequestStatus.accepted);
      expect(r.resultRejected, isTrue);
      expect(r.pendingWeightKg, isNull);
      expect(await notificationTypes('collector'), contains('collectionRejected'));
      expect(await walletBalance('supplier'), isNull); // aucun point
    });

    test('the collector can resubmit after a rejection and get it confirmed', () async {
      await acceptAndSubmit();
      await service.rejectCollectionResult(id, scanCode: (await reload()).scanCode!);
      await service.submitCollectionResult(id, weightKg: 8, priceFcfa: 500);
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);
      expect((await reload()).status, RequestStatus.completed);
      expect((await reload()).weightKg, 8);
    });

    test('without scanning the right QR code, confirmation is impossible', () async {
      await acceptAndSubmit();
      await expectLater(service.confirmCollectionResult(id, scanCode: 'WRONGCODE1'), throwsStateError);
      await expectLater(service.rejectCollectionResult(id, scanCode: ''), throwsStateError);
      expect((await reload()).status, RequestStatus.inProgress);
    });

    test('an old QR code no longer works after a new form is submitted', () async {
      await acceptAndSubmit();
      final oldCode = (await reload()).scanCode!;
      await service.rejectCollectionResult(id, scanCode: oldCode);
      await service.submitCollectionResult(id, weightKg: 7, priceFcfa: 450);
      await expectLater(service.confirmCollectionResult(id, scanCode: oldCode), throwsStateError);
    });

    test('points are credited only once, even if confirmation is replayed', () async {
      await acceptAndSubmit(weight: 7);
      await service.confirmCollectionResult(id, scanCode: (await reload()).scanCode!);
      await settleCompletedRequest(await reload(), firestore: db);
      await settleCompletedRequest(await reload(), firestore: db);
      expect(await walletBalance('supplier'), 21);
    });
  });
}
