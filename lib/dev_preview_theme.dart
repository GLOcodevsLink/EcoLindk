import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/waste_provider/wallet_screen.dart';
import 'widgets/points_card.dart';

/// TEMPORAIRE — aperçu isolé (pas d'authentification requise) pour vérifier
/// visuellement le mode sombre + la carte "Mes points" + le badge d'échange
/// du Portefeuille. À supprimer après usage.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();
  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  @override
  void initState() {
    super.initState();
    appThemeMode.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.surface,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            appThemeMode.value =
                appThemeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          },
          child: const Icon(Icons.brightness_6),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isDarkMode ? "DARK MODE" : "LIGHT MODE",
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.heading)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PointsCard(
                  uid: '',
                  pointsLabel: 'Mes points',
                  buttonLabel: 'Voir mon profil',
                  onButtonTap: () {},
                ),
              ),
              const Expanded(child: WalletScreen(embedded: true)),
            ],
          ),
        ),
      ),
    );
  }
}
