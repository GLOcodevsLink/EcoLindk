import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../models/collection_rating.dart';
import '../../models/collection_request.dart';
import '../../services/commission_service.dart';
import '../models/admin_models.dart';
import 'admin_repository.dart';
import 'admin_stats.dart';

/// Dernier état connu de toutes les données du tableau de bord : UNE seule
/// écoute par collection, partagée par toutes les pages (changer de page ne
/// relit rien). Créé par AdminShell, exposé via [AdminDataScope].
class AdminData extends ChangeNotifier {
  AdminData(this.repository) {
    _listen(repository.watchUsers(), (v) => users = v);
    _listen(repository.watchRequests(), (v) => requests = v);
    _listen(repository.watchCommissionPayments(), (v) => commissionPayments = v);
    _listen(repository.watchRedemptions(), (v) => redemptions = v);
    _listen(repository.watchWallets(), (v) => wallets = v);
    _listen(repository.watchRatings(), (v) => ratings = v);
  }

  final AdminRepository repository;
  final List<StreamSubscription<Object?>> _subs = [];
  static const _sourceCount = 6;
  int _received = 0;
  final Set<int> _ready = {};

  List<AdminUser> users = const [];
  List<CollectionRequest> requests = const [];
  List<CommissionPayment> commissionPayments = const [];
  List<AdminRedemption> redemptions = const [];
  Map<String, WalletSummary> wallets = const {};
  List<CollectionRating> ratings = const [];

  /// Première erreur de lecture (règles non déployées, réseau…).
  Object? error;

  bool get loading => _ready.length < _sourceCount && error == null;

  AdminStats? _stats;
  AdminStats get stats => _stats ??= AdminStats.compute(
        users: users,
        requests: requests,
        commissionPayments: commissionPayments,
        redemptions: redemptions,
        wallets: wallets,
        now: DateTime.now(),
      );

  Map<String, AdminUser>? _byUid;
  AdminUser? user(String uid) => (_byUid ??= {for (final u in users) u.uid: u})[uid];

  /// Nom affiché d'un utilisateur, avec repli sur le nom copié dans la
  /// demande (comptes supprimés) puis sur l'uid.
  String nameOf(String? uid, {String? fallback}) {
    if (uid == null || uid.isEmpty) return fallback ?? '—';
    return user(uid)?.displayName ?? ((fallback ?? '').isNotEmpty ? fallback! : uid);
  }

  void _listen<T>(Stream<T> stream, void Function(T) assign) {
    final index = _received++;
    _subs.add(stream.listen((value) {
      assign(value);
      _ready.add(index);
      _stats = null;
      _byUid = null;
      notifyListeners();
    }, onError: (Object e) {
      error ??= e;
      notifyListeners();
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

class AdminDataScope extends InheritedNotifier<AdminData> {
  const AdminDataScope({super.key, required AdminData data, required super.child}) : super(notifier: data);

  static AdminData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminDataScope>()!.notifier!;
}
