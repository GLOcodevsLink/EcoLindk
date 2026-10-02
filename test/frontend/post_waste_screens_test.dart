import 'package:ecolindk/core/l10n/app_language.dart';
import 'package:ecolindk/models/collection_request.dart';
import 'package:ecolindk/widgets/waste_category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests d'interface du formulaire "Post waste" : choix de la catégorie et
/// saisie du poids, affichés et manipulés comme par un utilisateur.

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() => appLanguage.value = AppLanguage.en);
  tearDown(() => appLanguage.value = AppLanguage.fr);

  group('Waste category', () {
    testWidgets('shows the 5 waste categories, beverage cans separate from metal', (tester) async {
      await tester.pumpWidget(host(WasteCategoryPicker(selected: null, fr: false, onChanged: (_) {})));
      for (final c in WasteCategory.values) {
        expect(find.text(c.label(false)), findsOneWidget);
      }
      expect(find.text('Beverage cans'), findsOneWidget);
      expect(find.text('Metal'), findsOneWidget);
    });

    testWidgets('the category tiles do not show any points rate', (tester) async {
      await tester.pumpWidget(host(WasteCategoryPicker(selected: null, fr: false, onChanged: (_) {})));
      expect(find.textContaining('P/kg'), findsNothing);
    });

    testWidgets('category tiles are compact (one short line each)', (tester) async {
      await tester.pumpWidget(host(WasteCategoryPicker(selected: null, fr: false, onChanged: (_) {})));
      for (final c in WasteCategory.values) {
        final tile = find.ancestor(of: find.text(c.label(false)), matching: find.byType(AnimatedContainer));
        expect(tester.getSize(tile).height, lessThan(64));
      }
    });

    testWidgets('a long press shows examples of the category', (tester) async {
      await tester.pumpWidget(host(WasteCategoryPicker(selected: null, fr: false, onChanged: (_) {})));
      await tester.longPress(find.text('Glass'));
      await tester.pumpAndSettle();
      expect(find.text(WasteCategory.glass.examples(false)), findsOneWidget);
    });

    testWidgets('tapping a category selects it', (tester) async {
      WasteCategory? picked;
      await tester.pumpWidget(host(WasteCategoryPicker(selected: null, fr: false, onChanged: (c) => picked = c)));
      await tester.tap(find.text('Glass'));
      expect(picked, WasteCategory.glass);
    });

    testWidgets('the selected category shows a check mark', (tester) async {
      await tester.pumpWidget(host(WasteCategoryPicker(selected: WasteCategory.plastic, fr: false, onChanged: (_) {})));
      await tester.pumpAndSettle();
      final scales = tester
          .widgetList<AnimatedScale>(find.ancestor(
            of: find.byIcon(Icons.check_rounded),
            matching: find.byType(AnimatedScale),
          ))
          .map((s) => s.scale)
          .toList();
      expect(scales.where((s) => s == 1), hasLength(1)); // seule la catégorie choisie
    });

    testWidgets('the optional category can be unselected by tapping it again', (tester) async {
      WasteCategory? picked = WasteCategory.metal;
      await tester.pumpWidget(host(WasteCategoryPicker(
          selected: WasteCategory.metal, fr: false, allowDeselect: true, onChanged: (c) => picked = c)));
      await tester.tap(find.text(WasteCategory.metal.label(false)));
      expect(picked, isNull);
    });
  });

  group('Estimated weight', () {
    testWidgets('the + and - buttons change the weight by 0.5 kg', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(WeightInput(controller: controller, fr: false)));

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(controller.text, '1');

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(controller.text, '0.5');
    });

    testWidgets('the weight can be typed freely, in kg', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(WeightInput(controller: controller, fr: false)));
      await tester.enterText(find.byType(TextField), '3.5');
      expect(controller.text, '3.5');
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('the weight never goes below zero', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(WeightInput(controller: controller, fr: false)));
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(controller.text, '0');
    });
  });
}
