import 'package:ecolindk/services/contact_service.dart';
import 'package:ecolindk/widgets/call_button.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late List<Uri> launched;

  setUp(() {
    db = FakeFirebaseFirestore();
    launched = <Uri>[];
  });

  Widget app({bool dialerAvailable = true}) => MaterialApp(
        home: Scaffold(
          body: CallButton(
            otherUid: 'other',
            contactService: ContactService(firestore: db),
            launcher: (Uri uri) async {
              launched.add(uri);
              return dialerAvailable;
            },
          ),
        ),
      );

  testWidgets('opens the dialer with the other user\'s number', (WidgetTester tester) async {
    await db.doc('userContacts/other').set(<String, dynamic>{'phone': '+237690000000'});
    await tester.pumpWidget(app());
    await tester.tap(find.byIcon(Icons.phone));
    await tester.pumpAndSettle();
    expect(launched, <Uri>[Uri(scheme: 'tel', path: '+237690000000')]);
    expect(launched.single.toString(), 'tel:+237690000000');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows a SnackBar when the number is missing', (WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byIcon(Icons.phone));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    expect(find.textContaining('numéro'), findsOneWidget);
  });

  testWidgets('shows a SnackBar when no dialer is available', (WidgetTester tester) async {
    await db.doc('userContacts/other').set(<String, dynamic>{'phone': '+237690000000'});
    await tester.pumpWidget(app(dialerAvailable: false));
    await tester.tap(find.byIcon(Icons.phone));
    await tester.pumpAndSettle();
    expect(find.textContaining('composeur'), findsOneWidget);
  });
}
