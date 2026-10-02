import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecolindk/admin/screens/admin_shell.dart';
import 'package:ecolindk/admin/services/admin_auth.dart';
import 'package:ecolindk/admin/services/admin_repository.dart';
import 'package:ecolindk/core/l10n/app_language.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendu de chaque page du tableau de bord, sur bureau, tablette et
/// téléphone, avec des données Firestore réalistes.
Future<FakeFirebaseFirestore> seed() async {
  final db = FakeFirebaseFirestore();
  final now = DateTime.now();
  await db.collection('users').doc('h1').set({
    'fullName': 'Awa Ndi',
    'email': 'awa@example.cm',
    'phone': '+237670000000',
    'role': 'household',
    'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
  });
  await db.collection('users').doc('c1').set({
    'fullName': 'Paul Mbarga',
    'email': 'paul@example.cm',
    'role': 'collector',
    'workStatus': 'independent',
    'collectionZones': [
      {'country': 'Cameroun', 'countryCode': 'CM', 'city': 'Yaoundé', 'neighborhood': 'Bastos'},
    ],
    'createdAt': Timestamp.fromDate(DateTime(2026, 8, 2)),
  });
  Map<String, dynamic> request(String status, {Map<String, dynamic> extra = const {}}) => {
        'householdUid': 'h1',
        'householdName': 'Awa Ndi',
        'imageUrl': '',
        'description': 'Bouteilles',
        'category': 'plastic',
        'quantityRange': '6 kg',
        'aiRequested': true,
        'aiSuggestedCategory': 'plastic',
        'aiConfidence': 0.92,
        'address': 'Bastos, Yaoundé',
        'neighborhood': 'Bastos',
        'city': 'Yaoundé',
        'latitude': 3.89,
        'longitude': 11.51,
        'locationIsApproximate': false,
        'status': status,
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        ...extra,
      };
  await db.collection('collectionRequests').doc('pendingPost').set(request('pending'));
  await db.collection('collectionRequests').doc('donePost').set(request('completed', extra: {
    'collectorUid': 'c1',
    'collectorName': 'Paul Mbarga',
    'weightKg': 6.0,
    'valueFcfa': 450.0,
    'pointsEarned': 18,
    'commissionFcfa': 60.0,
    'acceptedAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
    'completedAt': Timestamp.fromDate(now),
  }));
  await db.collection('collectionRequests').doc('inProgressPost').set(request('inProgress', extra: {
    'collectorUid': 'c1',
    'collectorName': 'Paul Mbarga',
    'pendingWeightKg': 5.5,
    'pendingPriceFcfa': 400.0,
  }));
  await db.collection('commissionPayments').doc('p1').set({
    'collectorUid': 'c1',
    'amountFcfa': 40,
    'phone': '+237670000000',
    'channel': 'cm.mtn',
    'mode': 'Notch Pay test',
    'status': 'success',
    'createdAt': Timestamp.fromDate(now),
  });
  await db.collection('wallets').doc('h1').set({'pointsBalance': 18, 'lifetimeEarned': 18});
  await db.collection('wallets').doc('h1').collection('redemptions').add({
    'method': 'airtime',
    'pointsSpent': 15,
    'amountFcfa': 500,
    'recipientPhone': '+237670000000',
    'status': 'completed',
    'createdAt': Timestamp.fromDate(now),
  });
  await db.collection('ratings').doc('donePost').set({'householdUid': 'h1', 'collectorUid': 'c1', 'stars': 5});
  return db;
}

void main() {
  setUp(() => appLanguage.value = AppLanguage.en);
  tearDown(() => appLanguage.value = AppLanguage.fr);

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = await seed();
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'admin', email: 'admin@ecolindk.cm'));
    await tester.pumpWidget(MaterialApp(
      home: AdminShell(
        auth: AdminAuth(auth: auth),
        repository: AdminRepository(firestore: db),
        user: auth.currentUser!,
      ),
    ));
    await tester.pumpAndSettle();
  }

  const labels = ['Overview', 'Waste providers', 'Collectors', 'Waste posts', 'Collections', 'Payments'];

  for (final (name, size) in const [('desktop', Size(1440, 1000)), ('tablet', Size(900, 1000))]) {
    testWidgets('every page renders with real data on $name', (tester) async {
      await pumpShell(tester, size);
      for (final label in labels) {
        // Barre réduite (tablette) : les libellés sont des info-bulles.
        await tester.tap(name == 'desktop' ? find.text(label).first : find.byTooltip(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets('phone width uses a drawer and still renders every page', (tester) async {
    await pumpShell(tester, const Size(400, 900));
    for (final label in labels) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text(label)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('overview shows live figures computed from Firestore', (tester) async {
    await pumpShell(tester, const Size(1440, 1400));
    expect(find.text('Waste collected'), findsOneWidget);
    expect(find.text('6 kg'), findsWidgets);
    expect(find.text('450 FCFA'), findsOneWidget);
    // Commission : 60 due − 40 payés.
    expect(find.text('20 FCFA'), findsOneWidget);
  });

  testWidgets('waste posts page lets the admin remove a pending post', (tester) async {
    await pumpShell(tester, const Size(1440, 1400));
    await tester.tap(find.text('Waste posts').first);
    await tester.pumpAndSettle();
    // Seul le post encore libre propose le retrait.
    expect(find.text('Remove post'), findsOneWidget);
    await tester.tap(find.text('Remove post'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove post'));
    await tester.pumpAndSettle();
    expect(find.text('Post removed.'), findsOneWidget);
    expect(find.text('Remove post'), findsNothing);
  });

  testWidgets('collectors page opens a detail with zones and payments', (tester) async {
    await pumpShell(tester, const Size(1440, 1400));
    await tester.tap(find.text('Collectors').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paul Mbarga'));
    await tester.pumpAndSettle();
    expect(find.text('• Cameroun → Yaoundé → Bastos'), findsOneWidget);
    expect(find.text('Commission payments'), findsOneWidget);
    expect(find.text('5.0/5 (1 reviews)'), findsOneWidget);
  });
}
