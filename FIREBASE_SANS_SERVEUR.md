# EcoLindk, 100 % Firebase (sans serveur)

L'app ne dépend plus que de Firebase, sur le plan gratuit (Spark) :

| Fonction | Service Firebase |
|---|---|
| Comptes, connexion | Firebase Auth |
| Données (posts, collectes, chat, suivi, portefeuille) | Firestore |
| Photos des déchets | Firestore (collection `wastePhotos`, photo compressée < 900 Ko) |
| Assistant IA et analyse des photos | Firebase AI Logic (Gemini), sans clé dans l'app |
| Choix du modèle d'IA à distance | Remote Config |
| Protection contre les appels hors de l'app | App Check (optionnel) |

Firebase Storage n'est pas utilisé : il exige désormais le plan payant Blaze.

---

## 1. Activer Firebase AI Logic (obligatoire)

1. Ouvrez https://console.firebase.google.com et choisissez le projet **ecolindk**.
2. Menu de gauche : **Créer** (Build) > **AI Logic**.
3. Cliquez sur **Commencer** (Get started).
4. Choisissez **Gemini Developer API** (gratuit, sans plan Blaze), puis
   **Activer les API**.
5. Firebase crée une clé gérée par lui : ne la copiez nulle part, l'app n'en a
   pas besoin.

Sans cette étape, l'assistant affiche « Firebase AI Logic n'est pas encore
activé pour ce projet ».

## 2. Choisir le modèle d'IA avec Remote Config (facultatif)

Sans rien faire, l'app utilise `gemini-3.8-flash`, puis `gemini-3.6-flash` si le
premier est surchargé. Pour les changer sans mettre à jour l'app :

1. Console Firebase > **Exécuter** (Run) > **Remote Config** > **Créer une configuration**.
2. Ajoutez deux paramètres (type chaîne) :
   - `gemini_model` = `gemini-3.8-flash`
   - `gemini_fallback_model` = `gemini-3.6-flash`
3. **Publier les modifications**. Les téléphones appliquent la nouvelle valeur
   au lancement suivant de l'app.

## 3. Lancer l'app

```bash
flutter run -d <identifiant>
```

Plus besoin de serveur, de `npm start`, d'`adb reverse` ni d'`API_BASE_URL` :
téléphone et émulateur passent directement par internet.

## 4. App Check (recommandé avant une vraie mise en ligne)

App Check garantit que seule votre app authentique peut appeler Gemini.
**Tant qu'il n'est pas configuré, n'ajoutez pas l'option ci-dessous**, sinon
l'IA échoue.

1. Empreinte SHA-256 de la clé de signature :
   ```bash
   cd android && ./gradlew signingReport
   ```
2. Console > **Créer** > **App Check** > onglet **Applications** > votre app
   Android > **Play Integrity** : collez l'empreinte SHA-256 et enregistrez.
3. Jetons de débogage (émulateur et téléphone de test) :
   - lancez `flutter run --dart-define=ENABLE_APP_CHECK=true` ;
   - dans les journaux, repérez la ligne
     `Enter this debug secret into the allow list in the Firebase Console…`
     suivie d'un jeton ;
   - Console > App Check > Applications > **⋮** > **Gérer les jetons de débogage** >
     ajoutez ce jeton. À faire pour **chaque** appareil.
4. Vérifiez que l'assistant IA répond, puis Console > App Check > onglet **API** >
   **Firebase AI Logic** > **Appliquer** (Enforce).
5. À partir de là, lancez et construisez toujours l'app avec
   `--dart-define=ENABLE_APP_CHECK=true`.

## Si Google bloque Gemini pour votre compte

Message « Your project has been denied access » : Google refuse Gemini au
compte qui possède `ecolindk`. L'IA peut alors passer par un projet Firebase
d'un **autre compte Google**, sans rien changer d'autre (comptes, données et
règles restent dans `ecolindk`) :

1. Avec l'autre compte : créez un projet Firebase, ajoutez-y une app Android
   `com.example.ecolindk`, puis activez **AI Logic** (Gemini Developer API).
2. Paramètres du projet > Vos applications > l'app Android : relevez
   `apiKey`, `appId`, `messagingSenderId`, `projectId`.
3. Renseignez-les dans `lib/ai_firebase_options.dart`, puis relancez l'app.

## 5. Révoquer les anciennes clés

Ces clés ne servent plus et figuraient dans d'anciens APK :

- **Clé Gemini** : https://aistudio.google.com/apikey > supprimez l'ancienne clé.
- **Clé StockImg** : tableau de bord StockImg > supprimez la clé.
  (Les photos des anciens posts restent affichées tant que StockImg les héberge.)

## 6. Tableau de bord administrateur (web)

Application séparée dans `lib/admin/`, même projet Firebase ; l'app mobile
n'en importe rien.

1. Déployez les règles (elles ajoutent l'accès admin) :
   `firebase deploy --only firestore:rules`
2. Créez le compte admin comme un compte normal (inscription dans l'app ou
   console > Authentication > Ajouter un utilisateur), copiez son **UID**.
3. Console > Firestore > collection `admins` > document dont l'id est cet
   UID (un champ quelconque, ex. `email`). Aucun client ne peut écrire
   dans `admins` : c'est la seule façon d'ajouter ou retirer un admin.
4. Lancez : `flutter run -d chrome -t lib/admin/main_admin.dart`
   Compilez : `flutter build web -t lib/admin/main_admin.dart -o build/admin_web`

Pages : vue d'ensemble, fournisseurs, collecteurs, posts (retrait d'un post
encore libre), collectes, paiements. Le tableau de bord lit les
collections entières en temps réel : à chaque ouverture, environ une
lecture par document (à surveiller face aux 50 000 lectures/jour).

## Limites du plan gratuit à connaître

- Firestore : 1 Go de stockage, 50 000 lectures par jour. Une photo pèse
  environ 150 à 400 Ko, soit plusieurs milliers de posts.
- Gemini Developer API : quota gratuit par minute et par jour. Au-delà,
  l'assistant affiche « trop de questions d'affilée ».
