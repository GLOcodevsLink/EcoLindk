/// Mise en forme des valeurs du tableau de bord (pas de dépendance `intl`
/// dans le projet : même format jj/mm/aaaa que les écrans mobiles).
class AdminFormat {
  const AdminFormat._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime? d) => d == null ? '—' : "${_two(d.day)}/${_two(d.month)}/${d.year}";

  static String dateTime(DateTime? d) => d == null ? '—' : "${date(d)} ${_two(d.hour)}:${_two(d.minute)}";

  /// "12/09" — axe des graphiques.
  static String dayMonth(DateTime d) => "${_two(d.day)}/${_two(d.month)}";

  /// Séparateur de milliers par une espace fine : 1 250 000.
  static String integer(num value) {
    final digits = value.round().abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    return out.toString();
  }

  static String fcfa(num? value) => value == null ? '—' : "${integer(value)} FCFA";

  static String kg(num? value) {
    if (value == null) return '—';
    final rounded = value >= 100 ? value.round().toString() : value.toStringAsFixed(1);
    return "${rounded.replaceAll('.0', '')} kg";
  }
}
