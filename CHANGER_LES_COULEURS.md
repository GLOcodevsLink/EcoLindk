# Comment changer les couleurs d'EcoLindk

Toutes les couleurs de l'application sont dans **un seul fichier** : `lib/core/theme.dart`.

---

## 0. Comment une couleur est écrite

```dart
Color(0xFF8FC1A4)
```

- `0xFF` → à ne jamais modifier.
- `8FC1A4` → les 6 caractères qui forment la couleur.

**Pour choisir une nouvelle couleur :** cherchez **« color picker »** sur Google,
cliquez sur une couleur, puis copiez les 6 caractères après le `#`
(par exemple `#1E88E5` → `1E88E5`).

---

## 1. Changer la couleur de FOND de l'application

1. Dans Android Studio, appuyez sur **Ctrl + Shift + N**, tapez `theme.dart`, puis **Entrée**.
2. Appuyez sur **Ctrl + F** et tapez `_surfaceLight`.
3. Vous trouvez cette ligne :
   ```dart
   static const Color _surfaceLight = Color(0xFFF3FAF6);
   ```
4. Remplacez **uniquement** les 6 caractères `F3FAF6` par votre couleur. Exemple, bleu clair :
   ```dart
   static const Color _surfaceLight = Color(0xFFE3F2FD);
   ```
5. Appuyez sur **Ctrl + S** (enregistrer).
6. Dans le terminal où l'application tourne, appuyez sur **R** (R majuscule).
   → Le fond de tous les écrans change.

> Fond du mode sombre : faites la même chose avec `darkSurface` et
> `darkBackground`, dans le même fichier.

---

## 2. Changer la couleur de TOUS les boutons

Les boutons verts sont un **dégradé** de 2 couleurs : `greenDeep` (côté gauche)
et `greenMid` (côté droit).

1. Ouvrez de nouveau `theme.dart` (**Ctrl + Shift + N** → `theme.dart`).
2. **Ctrl + F** → tapez `greenDeep`. Changez ses 6 caractères :
   ```dart
   static const Color greenDeep = Color(0xFF1565C0);   // côté gauche du bouton
   ```
3. **Ctrl + F** → tapez `greenMid`. Changez ses 6 caractères :
   ```dart
   static const Color greenMid = Color(0xFF42A5F5);    // côté droit du bouton
   ```
   (Mettez deux fois la même couleur pour un bouton uni, sans dégradé.)
4. **Ctrl + S**, puis **R** dans le terminal.

> ⚠️ `greenDeep` et `greenMid` servent aussi pour certaines icônes et petits
> détails : eux aussi changeront. Pour changer **un seul** bouton, voir la
> partie 3.

---

## 3. Changer la couleur d'UN SEUL bouton

1. Sur le téléphone, lisez le texte écrit sur le bouton, par exemple
   **Démarrer la collecte**.
2. Dans Android Studio, appuyez sur **Ctrl + Shift + F** et tapez ce texte.
3. Double-cliquez sur le résultat. Vous verrez quelque chose comme :
   ```dart
   GradientPillButton(
     label: fr ? "Démarrer la collecte" : "Start collection",
     onPressed: () => _start(r, fr),
   ),
   ```
4. Ajoutez **une ligne** `gradient:` à l'intérieur des parenthèses :
   ```dart
   GradientPillButton(
     label: fr ? "Démarrer la collecte" : "Start collection",
     onPressed: () => _start(r, fr),
     gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF5350)]),
   ),
   ```
   Mettez vos 2 couleurs entre les `[ ... ]`, séparées par une virgule.
   Mettez deux fois la même couleur pour un bouton uni.
5. **Ctrl + S**, puis **R** dans le terminal.
   → Seul ce bouton change de couleur.

> Si le bouton n'est pas un `GradientPillButton` mais un `ElevatedButton`,
> cherchez `backgroundColor:` juste à côté et mettez-y votre couleur :
> `backgroundColor: const Color(0xFFE53935),`

---

## En cas de problème

- Erreur en rouge après l'enregistrement ? Appuyez sur **Ctrl + Z** pour
  annuler. La cause est presque toujours une `,` ou une `)` oubliée.
- La couleur ne change pas ? Appuyez sur **R** (R majuscule), pas `r`, ou
  arrêtez l'application et relancez-la.
