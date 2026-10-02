import 'dart:convert';

import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/collection_zone.dart';
import 'package:ecolindk/services/collection_service.dart';
import 'package:ecolindk/services/commission_service.dart';
import 'package:ecolindk/services/collector_zone_service.dart';
import 'package:ecolindk/services/geocoding_service.dart';
import 'package:ecolindk/services/payment_gateway.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Quartiers de Yaoundé (coordonnées approximatives).
const bastos = (3.8950, 11.5100);
const mvan = (3.8200, 11.5250);
const essos = (3.8700, 11.5350);
const nkolbisson = (3.8700, 11.4400);

void main() {
  late FakeFirebaseFirestore db;
  late CollectionService service;

  /// Quartier renvoyé par le géocodage inverse de test (Nominatim), selon la
  /// latitude du post.
  String neighborhoodAt(double lat) => switch (lat) {
        3.8950 => 'Bastos',
        3.8200 => 'Mvan',
        3.8700 => 'Nkolbisson',
        _ => 'Akwa',
      };

  setUp(() {
    db = FakeFirebaseFirestore();
    service = CollectionService(
      firestore: db,
      geocoding: GeocodingService(client: MockClient((req) async {
        final lat = double.parse(req.url.queryParameters['lat']!);
        final city = lat < 3.95 ? 'Yaoundé' : 'Douala';
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'address': {'suburb': neighborhoodAt(lat), 'city': city}
            })),
            200);
      })),
    );
  });

  Future<List<Map<String, dynamic>>> notificationsOf(String uid) async =>
      (await db.collection('notifications').doc(uid).collection('items').get())
          .docs
          .map((d) => d.data())
          .toList();

  Future<CollectionRequest> post({String quantity = '5 kg', (double, double)? at}) => service.createRequest(
        householdUid: 'house',
        householdName: 'Awa',
        imageUrl: 'https://img.test/a.jpg',
        description: 'Bouteilles',
        category: WasteCategory.plastic,
        quantityRange: quantity,
        aiRequested: false,
        address: 'Akwa, Douala',
        latitude: at?.$1 ?? 4.0511,
        longitude: at?.$2 ?? 9.7679,
        locationIsApproximate: false,
      );

  CollectionZone zone(String name, (double, double) p) => CollectionZone(
      country: 'Cameroon', countryCode: 'CM', city: 'Yaoundé', neighborhood: name, latitude: p.$1, longitude: p.$2);

  Future<List<Map<String, dynamic>>> newPostNotifs(String uid) async =>
      (await notificationsOf(uid)).where((n) => n['type'] == 'newNearbyPost').toList();

  group('new post notifications by collection zone', () {
    late CollectorZoneService zones;

    setUp(() async {
      zones = CollectorZoneService(firestore: db);
      await db.collection('users').doc('collA').set({'role': 'collector'});
      await zones.save('collA', [zone('Mvan', mvan), zone('Bastos', bastos), zone('Essos', essos)]);
    });

    test('post in Bastos: the collector is notified ONCE (several nearby zones)', () async {
      final r = await post(at: bastos, quantity: '6 kg');

      expect(r.neighborhood, 'Bastos');
      expect(r.city, 'Yaoundé');
      final notifs = await newPostNotifs('collA');
      expect(notifs, hasLength(1));
      expect(notifs.single['title'], 'Nouveau post disponible');
      expect(notifs.single['body'], contains('Plastique'));
      expect(notifs.single['body'], contains('6 kg'));
      expect(notifs.single['body'], contains('Bastos'));
      expect(notifs.single['relatedRequestId'], r.id);
      // Identifiant fixe : une seule notification possible pour ce post.
      final doc = await db.collection('notifications').doc('collA').collection('items').doc('newpost_${r.id}').get();
      expect(doc.exists, isTrue);
    });

    test('address picked from the list: that neighborhood is kept and used for targeting', () async {
      final r = await service.createRequest(
        householdUid: 'house',
        householdName: 'Awa',
        imageUrl: 'firestore://wastePhotos/x',
        description: 'Cartons',
        category: WasteCategory.paperCardboard,
        quantityRange: '4 kg',
        aiRequested: true,
        address: 'Bastos, Yaoundé',
        latitude: bastos.$1,
        longitude: bastos.$2,
        locationIsApproximate: true,
        // Choisi par le Fournisseur : le géocodage inverse ne doit
        // pas être utilisé (il renverrait lui aussi Bastos ici, donc on
        // choisit un nom différent pour le prouver).
        neighborhood: 'Bastos Golf',
        city: 'Yaoundé',
      );
      expect(r.neighborhood, 'Bastos Golf');
      expect(r.city, 'Yaoundé');
      final notifs = await newPostNotifs('collA');
      expect(notifs.single['body'], contains('Bastos Golf'));
    });

    test('post outside the zones (Nkolbisson): not notified', () async {
      await post(at: nkolbisson);
      expect(await newPostNotifs('collA'), isEmpty);
    });

    test('updated zones: the next post uses the new configuration', () async {
      await zones.save('collA', [zone('Mvan', mvan), zone('Nkolbisson', nkolbisson)]);

      await post(at: nkolbisson);
      expect(await newPostNotifs('collA'), hasLength(1));

      // Bastos n'est plus dans ses zones, et à plus de 5 km de Mvan/Nkolbisson.
      await post(at: bastos);
      expect(await newPostNotifs('collA'), hasLength(1));
    });

    test('the current GPS of the collector is not used for targeting', () async {
      // Position en direct pendant une collecte, près de Nkolbisson : ne doit
      // pas le rendre éligible aux posts de Nkolbisson.
      await db.collection('liveTracking').doc('x').set({'collectorLat': nkolbisson.$1, 'collectorLng': nkolbisson.$2});
      await post(at: nkolbisson);
      expect(await newPostNotifs('collA'), isEmpty);
    });
  });

  Future<CollectionRequest> reload(String id) async =>
      CollectionRequest.fromDoc(await db.collection('collectionRequests').doc(id).get());

  group('createRequest', () {
    test('creates a pending request and notifies the supplier', () async {
      final r = await post();
      expect(r.status, RequestStatus.pending);
      expect(r.imageUrl, 'https://img.test/a.jpg');
      final notifs = await notificationsOf('house');
      expect(notifs.single['type'], 'requestSubmitted');
      expect(notifs.single['relatedRequestId'], r.id);
    });

    test('only notifies collectors within range', () async {
      await service.setCollectorLocation('proche', 4.06, 9.77); // ~1 km
      await service.setCollectorLocation('loin', 3.848, 11.502); // Yaoundé
      await post();
      expect((await notificationsOf('proche')).single['type'], 'newNearbyPost');
      expect(await notificationsOf('loin'), isEmpty);
    });
  });

  test('setCollectorLocation / getCollectorLocation', () async {
    expect(await service.getCollectorLocation('c1'), isNull);
    await service.setCollectorLocation('c1', 4.0, 9.7);
    final p = await service.getCollectorLocation('c1');
    expect(p!.latitude, 4.0);
    expect(p.longitude, 9.7);
  });

  group('acceptRequest', () {
    test('assigns the collector and notifies the supplier', () async {
      final r = await post();
      await service.acceptRequest(r.id, collectorUid: 'c1', collectorName: 'Paul');
      final updated = await reload(r.id);
      expect(updated.status, RequestStatus.accepted);
      expect(updated.collectorUid, 'c1');
      expect((await notificationsOf('house')).map((n) => n['type']), contains('requestAccepted'));
    });

    test('a request can only be accepted by one collector', () async {
      final r = await post();
      await service.acceptRequest(r.id, collectorUid: 'c1', collectorName: 'Paul');
      await expectLater(service.acceptRequest(r.id, collectorUid: 'c2', collectorName: 'Marie'),
          throwsStateError);
      expect((await reload(r.id)).collectorUid, 'c1');
    });

    test('a cancelled request cannot be accepted', () async {
      final r = await post();
      await service.cancelRequest(r.id);
      await expectLater(
          service.acceptRequest(r.id, collectorUid: 'c1', collectorName: 'Paul'), throwsStateError);
    });
  });

  group('collection result', () {
    late String id;

    setUp(() async {
      id = (await post(quantity: '15 kg')).id; // écart toléré : 5 kg au plus
      await service.acceptRequest(id, collectorUid: 'c1', collectorName: 'Paul');
    });

    test('weight outside the declared range → rejected', () async {
      await expectLater(
          service.submitCollectionResult(id, weightKg: 20.5, priceFcfa: 500), throwsFormatException);
      await expectLater(
          service.submitCollectionResult(id, weightKg: 9, priceFcfa: 500), throwsFormatException);
      expect((await reload(id)).status, RequestStatus.accepted);
    });

    test('submission → inProgress, then confirmation → completed with points', () async {
      await service.submitCollectionResult(id, weightKg: 14, priceFcfa: 300);
      var r = await reload(id);
      expect(r.status, RequestStatus.inProgress);
      expect(r.pendingWeightKg, 14);
      expect(r.pendingPriceFcfa, 300);
      expect(r.scanCode, hasLength(10));
      expect(r.qrPayload, 'ecolindk:collection:$id:${r.scanCode}');

      await service.confirmCollectionResult(id, scanCode: r.scanCode!);
      r = await reload(id);
      expect(r.status, RequestStatus.completed);
      expect(r.weightKg, 14);
      expect(r.valueFcfa, 300);
      expect(r.pointsEarned, 42); // plastique : 3 pts/kg (taux affiché) × 14 kg
      expect(r.commissionFcfa, 140); // plastique : 10 FCFA/kg × 14 kg
      expect(r.pendingWeightKg, isNull);
      expect(r.scanCode, isNull);
      // Points crédités automatiquement à la double confirmation.
      final wallet = await db.collection('wallets').doc('house').get();
      expect(wallet.data()!['pointsBalance'], 42);
      expect((await notificationsOf('c1')).map((n) => n['type']), contains('requestCompleted'));
    });

    test('a confirmed pickup is charged to the collector until paid', () async {
      final commissions = CommissionService(
          firestore: db, gateway: SimulatedPaymentGateway(delay: Duration.zero));
      Future<int> owed() async => CommissionService.outstanding(
          await service.watchCollectorHistory('c1').first,
          await commissions.watchPayments('c1').first);

      expect(await owed(), 0);
      await service.submitCollectionResult(id, weightKg: 14, priceFcfa: 300);
      await service.confirmCollectionResult(id, scanCode: (await reload(id)).scanCode!);
      expect(await owed(), 140); // plastique : 10 FCFA/kg × 14 kg

      // Un paiement refusé (numéro de test "fonds insuffisants") ne règle rien.
      await commissions.payCommission(
          collectorUid: 'c1', amountFcfa: 140, phone: '+237670000001', operator: MobileMoneyOperator.mtn);
      expect(await owed(), 140);

      await commissions.payCommission(
          collectorUid: 'c1', amountFcfa: 140, phone: '+237670000000', operator: MobileMoneyOperator.mtn);
      expect(await owed(), 0);
    });

    test('rejection → back to accepted and the collector is notified', () async {
      await service.submitCollectionResult(id, weightKg: 14, priceFcfa: 300);
      final code = (await reload(id)).scanCode!;
      await service.rejectCollectionResult(id, scanCode: code);
      final r = await reload(id);
      expect(r.status, RequestStatus.accepted);
      expect(r.pendingWeightKg, isNull);
      expect(r.resultRejected, isTrue);
      expect((await notificationsOf('c1')).map((n) => n['type']), contains('collectionRejected'));

      // Nouvelle soumission : l'erreur de refus disparaît, et l'ancien QR
      // ne permet pas de confirmer le nouveau formulaire.
      await service.submitCollectionResult(id, weightKg: 14, priceFcfa: 300);
      final again = await reload(id);
      expect(again.resultRejected, isFalse);
      expect(again.scanCode, isNot(code));
      await expectLater(service.confirmCollectionResult(id, scanCode: code), throwsStateError);
    });

    test('without scanning the right QR code, cannot confirm or reject', () async {
      await service.submitCollectionResult(id, weightKg: 14, priceFcfa: 300);
      await expectLater(service.confirmCollectionResult(id, scanCode: 'WRONGCODE'), throwsStateError);
      await expectLater(service.rejectCollectionResult(id, scanCode: ''), throwsStateError);
      expect((await reload(id)).status, RequestStatus.inProgress);
    });

    test('starting the collection timestamps it and notifies the supplier', () async {
      await service.startCollection(id);
      expect((await reload(id)).collectionStartedAt, isNotNull);
      expect((await notificationsOf('house')).map((n) => n['title']), contains('Collecte démarrée 🚚'));
    });

    test('confirming without a prior submission is rejected', () async {
      await expectLater(service.confirmCollectionResult(id, scanCode: 'X'), throwsStateError);
      expect((await reload(id)).status, RequestStatus.accepted);
    });
  });

  test('settleCompletedRequest credits points only once', () async {
    final id = (await post()).id;
    await service.acceptRequest(id, collectorUid: 'c1', collectorName: 'Paul');
    await service.submitCollectionResult(id, weightKg: 5, priceFcfa: 375);
    await service.confirmCollectionResult(id, scanCode: (await reload(id)).scanCode!);
    final done = await reload(id);

    await settleCompletedRequest(done, firestore: db);
    await settleCompletedRequest(done, firestore: db);

    final wallet = await db.collection('wallets').doc('house').get();
    expect(wallet.data()!['pointsBalance'], 15); // 3 pts/kg × 5 kg
  });
}
