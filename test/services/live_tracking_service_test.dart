import 'package:ecolindk/services/live_tracking_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late LiveTrackingService tracking;

  setUp(() {
    db = FakeFirebaseFirestore();
    tracking = LiveTrackingService(firestore: db);
  });

  test('each party sees the other one move live', () async {
    final seen = <LiveTrackingSnapshot>[];
    final sub = tracking.watch('req1').listen(seen.add);

    // Douala : le fournisseur chez lui, le collecteur qui s'approche.
    await tracking.updatePosition('req1', TrackingRole.household, 4.0511, 9.7679);
    await tracking.updatePosition('req1', TrackingRole.collector, 4.0600, 9.7500);
    await tracking.updatePosition('req1', TrackingRole.collector, 4.0550, 9.7600);
    await pumpEventQueue();

    final last = seen.last;
    expect(last.household!.latitude, 4.0511);
    expect(last.collector!.latitude, 4.0550);
    expect(last.collector!.longitude, 9.7600);
    // Le déplacement du collecteur a bien été diffusé à chaque étape.
    expect(seen.where((s) => s.collector != null).map((s) => s.collector!.latitude),
        containsAllInOrder([4.0600, 4.0550]));
    // Écrire sa position n'efface jamais celle de l'autre.
    expect(seen.where((s) => s.collector != null).every((s) => s.household != null), isTrue);
    await sub.cancel();
  });

  test('positions are cleared at the end of the collection', () async {
    await tracking.updatePosition('req1', TrackingRole.collector, 4.05, 9.76);
    await tracking.clear('req1');
    final snap = await tracking.watch('req1').first;
    expect(snap.collector, isNull);
    expect(snap.household, isNull);
  });
}
