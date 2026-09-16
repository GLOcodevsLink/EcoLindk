import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/strings.dart';
import '../../services/settings_service.dart';
import '../../widgets/decorative_leaves.dart';

/// Réglages de notifications : autorisation système, identique à la bascule
/// de l'onboarding (même préférence partagée via SettingsService).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _settings = SettingsService();
  bool _enabled = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await _settings.loadNotifications();
    final granted = await Permission.notification.isGranted;
    if (!mounted) return;
    setState(() => _enabled = saved && granted);
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _busy = true);
    var granted = false;
    if (value) {
      final status = await Permission.notification.request();
      granted = status.isGranted;
      if (!granted && mounted) {
        _showSnack(status.isPermanentlyDenied
            ? (appLanguage.value == AppLanguage.fr
                ? "Autorisez les notifications dans les réglages du système."
                : "Enable notifications from your system settings.")
            : (appLanguage.value == AppLanguage.fr
                ? "Autorisation refusée."
                : "Permission denied."));
      }
    }
    await _settings.saveNotifications(granted);
    if (!mounted) return;
    setState(() {
      _enabled = granted;
      _busy = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, _, __) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: appLanguage,
          builder: (context, lang, _) {
            final s = AppStrings.of(lang);
            return Scaffold(
              backgroundColor: AppColors.surface,
              body: Stack(
                children: [
                  const DecorativeLeaves(subtle: true),
                  SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.arrow_back, color: AppColors.heading),
                            ),
                            Expanded(
                              child: Text(s.notificationsTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.heading)),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(s.notificationsDesc,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                  height: 1.5)),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_outlined,
                                  color: AppColors.greenDeep, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(s.settingNotifications,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mainText)),
                              ),
                              Switch(
                                  value: _enabled,
                                  activeColor: AppColors.greenMid,
                                  onChanged: _busy ? null : _onChanged),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
