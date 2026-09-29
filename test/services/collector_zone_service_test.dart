import 'package:ecolindk/models/collection_zone.dart';
import 'package:ecolindk/services/collector_zone_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionZone zone(String neighborhood, {double lat = 3.87, double lng = 11.52, String city = 'Yaoundé'}) =>
    CollectionZone(
        country: 'Cameroon', countryCode: 'CM', city: city, neighborhood: neighborhood, latitude: lat, longitude: lng);

Matcher throwsZoneError(String code) =>
    throwsA(isA<CollectionZoneException>().having((e) => e.code, 'code', code));

void main() {
  late FakeFirebaseFirestore db;
  late CollectorZoneService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = CollectorZoneService(firestore: db);
    await db.collection('users').doc('c1').set({'role': 'collector', 'phone': '+237650000000'});
  });

  Future<Map<String, dynamic>> userDoc() async => (await db.collection('users').doc('c1').get()).data()!;
  Future<Map<String, dynamic>> locationDoc() async =>
      (await db.collection('collectorLocations').doc('c1').get()).data()!;

  test('ajouter une zone : enregistrée dans le profil ET dans l\'index de ciblage', () async {
    await service.add('c1', zone('Bastos', lat: 3.895, lng: 11.51));

    final saved = (await userDoc())['collectionZones'] as List;
    expect(saved.single['neighborhood'], 'Bastos');
    expect(saved.single['latitude'], 3.895);
    final index = await locationDoc();
    expect((index['zones'] as List).single['neighborhood'], 'Bastos');
    // Ancien format conservé pour les versions précédentes de l'app.
    expect(index['latitude'], 3.895);
  });

  test('plusieurs zones, relues après "réouverture" (nouveau service)', () async {
    await service.add('c1', zone('Bastos'));
    await service.add('c1', zone('Mvan'));
    await service.add('c1', zone('Essos'));

    final reloaded = await CollectorZoneService(firestore: db).load('c1');
    expect(reloaded.map((z) => z.neighborhood), ['Bastos', 'Mvan', 'Essos']);
  });

  test('6e zone refusée, rien n\'est écrit', () async {
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      await service.add('c1', zone(n));
    }
    await expectLater(service.add('c1', zone('F')), throwsZoneError('max-reached'));
    expect(((await userDoc())['collectionZones'] as List), hasLength(5));
  });

  test('doublon refusé (même avec accents/casse différents)', () async {
    await service.add('c1', zone('Éssos'));
    await expectLater(service.add('c1', zone('essos')), throwsZoneError('duplicate'));
    expect(((await userDoc())['collectionZones'] as List), hasLength(1));
  });

  test('supprimer et modifier une zone', () async {
    await service.add('c1', zone('Bastos'));
    await service.add('c1', zone('Mvan'));

    await service.remove('c1', 0);
    expect((await service.load('c1')).map((z) => z.neighborhood), ['Mvan']);

    await service.replace('c1', 0, zone('Essos'));
    expect((await service.load('c1')).map((z) => z.neighborhood), ['Essos']);
    expect(((await locationDoc())['zones'] as List).single['neighborhood'], 'Essos');
  });

  test('ancien compte : l\'ancienne zone texte est relue, sans être supprimée', () async {
    await db.collection('users').doc('old').set({'role': 'collector', 'collectionZone': 'Mendong Yaoundé'});
    await db.collection('collectorLocations').doc('old').set({'latitude': 3.835, 'longitude': 11.473});

    final zones = await service.load('old');
    expect(zones.single.neighborhood, 'Mendong Yaoundé');
    expect(zones.single.latitude, 3.835);

    // Le collecteur ajoute une vraie zone : l'ancienne reste dans la liste
    // et l'ancien champ n'est pas effacé.
    await service.add('old', zone('Bastos'));
    final data = (await db.collection('users').doc('old').get()).data()!;
    expect(data['collectionZone'], 'Mendong Yaoundé');
    expect((data['collectionZones'] as List).map((z) => z['neighborhood']), ['Mendong Yaoundé', 'Bastos']);
  });
}
