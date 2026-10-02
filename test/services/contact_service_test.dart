import 'package:ecolindk/core/phone_country.dart';
import 'package:ecolindk/services/contact_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhoneE164', () {
    test('keeps E.164 numbers', () {
      expect(normalizePhoneE164('+237690000000'), '+237690000000');
      expect(normalizePhoneE164('+33 6 12 34 56 78'), '+33612345678');
    });

    test('adds +237 to Cameroonian numbers missing it', () {
      expect(normalizePhoneE164('690000000'), '+237690000000');
      expect(normalizePhoneE164('6 90 00 00 00'), '+237690000000');
      expect(normalizePhoneE164('237690000000'), '+237690000000');
      expect(normalizePhoneE164('00237690000000'), '+237690000000');
    });

    test('rejects empty or unusable values', () {
      expect(normalizePhoneE164(null), isNull);
      expect(normalizePhoneE164(''), isNull);
      expect(normalizePhoneE164('12345'), isNull);
      expect(normalizePhoneE164('+12'), isNull);
    });
  });

  group('ContactService', () {
    late FakeFirebaseFirestore db;
    late ContactService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ContactService(firestore: db);
    });

    test('publishes only the normalized phone', () async {
      await service.publishOwnPhone('u1', '690000000');
      final Map<String, dynamic>? data = (await db.doc('userContacts/u1').get()).data();
      expect(data, <String, dynamic>{'phone': '+237690000000'});
      expect(await service.fetchPhone('u1'), '+237690000000');
    });

    test('publishes nothing for an unusable phone', () async {
      await service.publishOwnPhone('u1', '');
      expect((await db.doc('userContacts/u1').get()).exists, isFalse);
      expect(await service.fetchPhone('u1'), isNull);
    });

    test('deleteOwnPhone removes the number', () async {
      await service.publishOwnPhone('u1', '+237670000000');
      await service.deleteOwnPhone('u1');
      expect(await service.fetchPhone('u1'), isNull);
    });
  });
}
