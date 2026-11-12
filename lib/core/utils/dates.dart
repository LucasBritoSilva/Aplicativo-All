/// Funções de data usadas em todo o app.
///
/// A semana começa na segunda-feira (ver DECISOES.md).
library;

const _weekdaysShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _weekdaysLong = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const _weekdayLetters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
const _monthsShort = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

/// Remove a hora, mantendo apenas o dia (meia-noite local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Soma [days] dias de calendário, sem sofrer com horário de verão.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Segunda-feira da semana de [d], à meia-noite.
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// Os 7 dias (segunda a domingo) da semana de [d].
List<DateTime> daysOfWeek(DateTime d) {
  final start = startOfWeek(d);
  return List.generate(
    7,
    (i) => DateTime(start.year, start.month, start.day + i),
  );
}

/// Diferença em dias de calendário entre [from] e [to].
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 14:05
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// 11/11/2026
String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// 11 nov
String formatDayMonth(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

/// qua
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// quarta-feira
String weekdayLong(DateTime d) => _weekdaysLong[d.weekday - 1];

/// Q (inicial do dia da semana)
String weekdayLetter(DateTime d) => _weekdayLetters[d.weekday - 1];

/// "Hoje", "Amanhã", "Ontem" ou "qua, 11 nov".
String friendlyDay(DateTime d, DateTime today) {
  final diff = daysBetween(today, d);
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Amanhã';
  if (diff == -1) return 'Ontem';
  final sameYear = d.year == today.year;
  return '${weekdayShort(d)}, ${formatDayMonth(d)}${sameYear ? '' : ' ${d.year}'}';
}

/// "11 – 17 nov" ou "28 out – 3 nov".
String formatWeekRange(DateTime anyDayOfWeek) {
  final start = startOfWeek(anyDayOfWeek);
  final end = DateTime(start.year, start.month, start.day + 6);
  if (start.month == end.month) {
    return '${start.day} – ${end.day} ${_monthsShort[end.month - 1]}';
  }
  return '${formatDayMonth(start)} – ${formatDayMonth(end)}';
}

/// Converte texto digitado ("12,5" ou "12.5") em número.
double? parseNumber(String text) {
  final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Mostra números sem ".0" desnecessário e com vírgula decimal.
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  var s = value.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}
