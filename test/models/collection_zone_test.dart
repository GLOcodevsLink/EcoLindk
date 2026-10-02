import 'package:ecolindk/core/phone_country.dart';
import 'package:ecolindk/models/collection_zone.dart';
import 'package:flutter_test/flutter_test.dart';

const bastos = CollectionZone(
    country: 'Cameroon', countryCode: 'CM', city: 'Yaoundé', neighborhood: 'Bastos', latitude: 3.895, longitude: 11.51);

void main() {
  group('CollectionZone', () {
    test('label country → city → neighborhood', () {
      expect(bastos.label, 'Cameroon → Yaoundé → Bastos');
    });

    test('duplicate detected regardless of accents and case', () {
      const a = CollectionZone(country: 'Cameroon', countryCode: 'CM', city: 'Yaoundé', neighborhood: 'Éssos');
      const b = CollectionZone(country: 'Cameroun', countryCode: 'cm', city: 'yaounde', neighborhood: 'essos ');
      expect(a.key, b.key);
      expect(a == b, isTrue);
      expect(a.key == bastos.key, isFalse);
    });

    test('Firestore round trip keeps the coordinates', () {
      final back = CollectionZone.fromMap(bastos.toMap());
      expect(back.latitude, 3.895);
      expect(back.longitude, 11.51);
      expect(back.key, bastos.key);
    });

    test('same neighborhood in the same city', () {
      expect(bastos.sameNeighborhoodAs('Yaoundé', 'bastos'), isTrue);
      expect(bastos.sameNeighborhoodAs('Douala', 'Bastos'), isFalse);
      expect(bastos.sameNeighborhoodAs('Yaoundé', 'Mvan'), isFalse);
      expect(bastos.sameNeighborhoodAs('Yaoundé', null), isFalse);
    });
  });

  group('backward compatibility with the legacy collectionZone field', () {
    test('new list takes precedence', () {
      final zones = CollectionZone.fromUserData({
        'collectionZone': 'Mendong Yaoundé',
        'collectionZones': [bastos.toMap()],
      });
      expect(zones.single.neighborhood, 'Bastos');
    });

    test('legacy field only → one zone, with the existing geocoded point', () {
      final zones = CollectionZone.fromUserData({'collectionZone': 'Mvan'},
          legacyLatitude: 3.82, legacyLongitude: 11.525);
      expect(zones, hasLength(1));
      expect(zones.single.neighborhood, 'Mvan');
      expect(zones.single.city, '');
      expect(zones.single.latitude, 3.82);
    });

    test('no zone', () {
      expect(CollectionZone.fromUserData({}), isEmpty);
      expect(CollectionZone.fromUserData(null), isEmpty);
    });
  });

  group('country from dialing code (country_picker)', () {
    test('+237 → Cameroon', () {
      expect(countryFromPhone('+237650123456')!.countryCode, 'CM');
    });

    test('dialing codes of different lengths', () {
      expect(countryFromPhone('+33612345678')!.countryCode, 'FR');
      expect(countryFromPhone('+2250102030405')!.countryCode, 'CI');
    });

    test('empty number or no dialing code → nothing', () {
      expect(countryFromPhone(''), isNull);
      expect(countryFromPhone(null), isNull);
      expect(countryFromPhone('650123456'), isNull);
    });
  });
}
