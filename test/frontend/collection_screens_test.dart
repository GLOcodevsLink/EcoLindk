import 'package:ecolindk/core/l10n/app_language.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/models/collection_zone.dart';
import 'package:ecolindk/screens/collector/collection_confirmation_screen.dart';
import 'package:ecolindk/widgets/collection_zones_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests d'interface côté collecte : formulaire de confirmation du
/// collecteur (poids pesé, prix payé) et gestion de ses zones de collecte.

CollectionRequest post({String quantity = '6 kg'}) => CollectionRequest(
      id: 'req123456',
      householdUid: 'supplier',
      householdName: 'Awa',
      imageUrl: '',
      description: 'Plastic bottles',
      category: WasteCategory.plastic,
      quantityRange: quantity,
      aiRequested: false,
      address: 'Bastos, Yaoundé',
      latitude: 3.895,
      longitude: 11.51,
      locationIsApproximate: false,
      status: RequestStatus.accepted,
      collectorUid: 'collector',
      collectorName: 'Paul',
      createdAt: DateTime(2026),
    );

CollectionZone zone(String name) => CollectionZone(
    country: 'Cameroon', countryCode: 'CM', city: 'Yaoundé', neighborhood: name, latitude: 3.87, longitude: 11.52);

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() => appLanguage.value = AppLanguage.en);
  tearDown(() => appLanguage.value = AppLanguage.fr);

  group('Collection confirmation form (collector)', () {
    Future<void> openForm(WidgetTester tester) async {
      // Écran large : la police des tests (lettres carrées) prend plus de
      // place que la vraie police de l'app.
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: CollectionConfirmationScreen(request: post())));
      await tester.pumpAndSettle();
    }

    Finder weightField() => find.byType(TextField).at(0);
    Finder priceField() => find.byType(TextField).at(1);

    testWidgets('shows the declared weight and the accepted weight range', (tester) async {
      await openForm(tester);
      expect(find.text('Confirm the collection'), findsOneWidget);
      expect(find.text('Declared in the post: 6 kg'), findsOneWidget);
      expect(find.text('Accepted weight: 1 kg to 11 kg'), findsOneWidget);
    });

    testWidgets('a weight within 5 kg of the declared weight shows no error', (tester) async {
      await openForm(tester);
      await tester.enterText(weightField(), '9');
      await tester.pump();
      expect(find.textContaining('Incorrect weight'), findsNothing);
    });

    testWidgets('a weight more than 5 kg away shows an error asking for the correct weight', (tester) async {
      await openForm(tester);
      await tester.enterText(weightField(), '12');
      await tester.pump();
      expect(find.textContaining('Incorrect weight'), findsOneWidget);
      expect(find.textContaining('Enter the correct weight, between 1 kg and 11 kg'), findsOneWidget);
    });

    testWidgets('submitting without a price is refused', (tester) async {
      await openForm(tester);
      await tester.enterText(weightField(), '7');
      await tester.tap(find.text('Submit and generate the QR'));
      await tester.pump();
      expect(find.text('Enter a valid price, in FCFA.'), findsOneWidget);
    });

    testWidgets('submitting an empty form shows both errors', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Submit and generate the QR'));
      await tester.pump();
      expect(find.text('Enter the weighed weight, in kg.'), findsOneWidget);
      expect(find.text('Enter a valid price, in FCFA.'), findsOneWidget);
    });

    testWidgets('the price field accepts an amount', (tester) async {
      await openForm(tester);
      await tester.enterText(priceField(), '1500');
      expect(find.text('1500'), findsOneWidget);
    });
  });

  group('Collector collection zones', () {
    testWidgets('shows the zones and the 3 / 5 counter', (tester) async {
      await tester.pumpWidget(host(CollectionZonesEditor(
          zones: [zone('Bastos'), zone('Mvan'), zone('Essos')], fr: false, onChanged: (_) async => true)));

      expect(find.text('3 / 5 zones'), findsOneWidget);
      expect(find.text('Bastos'), findsOneWidget);
      expect(find.text('Mvan'), findsOneWidget);
      expect(find.text('Essos'), findsOneWidget);
      expect(find.text('Add a collection zone'), findsOneWidget);
    });

    testWidgets('with 5 zones, adding a 6th is refused', (tester) async {
      await tester.pumpWidget(host(CollectionZonesEditor(
          zones: [for (final n in ['A', 'B', 'C', 'D', 'E']) zone(n)], fr: false, onChanged: (_) async => true)));

      expect(find.text('5 / 5 zones'), findsOneWidget);
      await tester.tap(find.text('Maximum reached'));
      await tester.pump();
      expect(find.textContaining('Maximum 5 zones'), findsOneWidget);
    });

    testWidgets('removing a zone asks for confirmation then removes it', (tester) async {
      List<CollectionZone>? saved;
      await tester.pumpWidget(host(CollectionZonesEditor(
          zones: [zone('Bastos'), zone('Mvan')],
          fr: false,
          onChanged: (zones) async {
            saved = zones;
            return true;
          })));

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Remove this zone?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(saved!.map((z) => z.neighborhood), ['Mvan']);
    });
  });
}
