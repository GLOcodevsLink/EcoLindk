import 'package:firebase_core/firebase_core.dart';

/// Projet Firebase utilisé UNIQUEMENT pour l'IA (Firebase AI Logic), quand il
/// doit être différent du projet principal `ecolindk` — par exemple si
/// Google bloque Gemini pour le compte qui possède `ecolindk`.
///
/// `null` : l'IA passe par le projet principal (comportement par défaut).
/// Sinon, renseigner ici la configuration de l'app Android
/// `com.example.ecolindk` enregistrée dans l'autre projet (console Firebase
/// > Paramètres du projet > Vos applications). Ce ne sont pas des secrets :
/// ce sont les mêmes valeurs que `google-services.json`.
///
/// Comptes, Firestore et règles restent dans le projet principal.
const FirebaseOptions? aiFirebaseOptions = null;

// Exemple (à décommenter et compléter) :
// const FirebaseOptions? aiFirebaseOptions = FirebaseOptions(
//   apiKey: 'AIza...',
//   appId: '1:123456789:android:abc123',
//   messagingSenderId: '123456789',
//   projectId: 'mon-projet-ia',
// );
