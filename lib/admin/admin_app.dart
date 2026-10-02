import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/l10n/app_language.dart';
import '../core/theme.dart';
import 'admin_strings.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_shell.dart';
import 'services/admin_auth.dart';
import 'services/admin_repository.dart';

class EcoLindkAdminApp extends StatelessWidget {
  const EcoLindkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Thème et langue partagés avec l'app (appThemeMode, appLanguage) : un
    // changement reconstruit tout le tableau de bord.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => ValueListenableBuilder<AppLanguage>(
        valueListenable: appLanguage,
        builder: (context, lang, _) => MaterialApp(
          title: AdminStrings.of(lang).appTitle,
          debugShowCheckedModeBanner: false,
          theme: ecoLindkTheme,
          darkTheme: ecoLindkDarkTheme,
          themeMode: mode,
          home: AdminGate(auth: AdminAuth(), repository: AdminRepository()),
        ),
      ),
    );
  }
}

/// Non connecté → AdminLoginScreen ; connecté mais absent de `admins/` →
/// accès refusé ; administrateur → AdminShell.
class AdminGate extends StatelessWidget {
  final AdminAuth auth;
  final AdminRepository repository;

  const AdminGate({super.key, required this.auth, required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = snap.data;
        if (user == null) return AdminLoginScreen(auth: auth);
        return _AdminCheck(key: ValueKey(user.uid), user: user, auth: auth, repository: repository);
      },
    );
  }
}

class _AdminCheck extends StatefulWidget {
  final User user;
  final AdminAuth auth;
  final AdminRepository repository;

  const _AdminCheck({super.key, required this.user, required this.auth, required this.repository});

  @override
  State<_AdminCheck> createState() => _AdminCheckState();
}

class _AdminCheckState extends State<_AdminCheck> {
  late Future<bool> _isAdmin = widget.repository.isAdmin(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return FutureBuilder<bool>(
      future: _isAdmin,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const _Loading();
        if (snap.data == true) return AdminShell(auth: widget.auth, repository: widget.repository, user: widget.user);
        final failed = snap.hasError;
        return _Blocked(
          title: failed ? s.accessCheckTitle : s.notAdminTitle,
          body: failed ? s.accessCheckFailed : s.notAdminBody(widget.user.email ?? widget.user.uid),
          onRetry: failed ? () => setState(() => _isAdmin = widget.repository.isAdmin(widget.user.uid)) : null,
          onSignOut: widget.auth.signOut,
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Blocked extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback? onRetry;
  final VoidCallback onSignOut;

  const _Blocked({required this.title, required this.body, this.onRetry, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings.of(appLanguage.value);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.heading),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.mainText)),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGray)),
                const SizedBox(height: 24),
                Wrap(spacing: 12, children: [
                  if (onRetry != null) FilledButton(onPressed: onRetry, child: Text(s.retry)),
                  OutlinedButton(onPressed: onSignOut, child: Text(s.signOut)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
