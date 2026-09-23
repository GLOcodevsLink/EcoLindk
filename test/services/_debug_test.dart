import 'package:ecolindk/services/wallet_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug', () async {
    final db = FakeFirebaseFirestore();
    final w = WalletService(firestore: db);
    await w.creditPoints(uid: 'u', points: 30, label: 'a');
    await w.creditPoints(uid: 'u', points: 20, label: 'b');
    print('stream: ${await w.watchBalance("u").first} life: ${await w.watchLifetimeEarned("u").first}');
    print('get: ${(await db.doc('wallets/u').get()).data()}');
    print('txs: ${(await db.collection('wallets/u/transactions').get()).docs.map((d) => d.data()['points'])}');
  });
}
