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

/// Dia do calendário como número inteiro (dias desde 01/01/1970).
///
/// Não depende do fuso horário: 12/11/2026 é sempre o mesmo número, mesmo
/// que o relógio do aparelho mude de fuso depois.
int epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Meia-noite local do dia inteiro [day].
DateTime dateFromEpochDay(int day) {
  final u = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(u.year, u.month, u.day);
}

/// Dia da semana de um dia inteiro (1 = segunda ... 7 = domingo).
int weekdayOfEpochDay(int day) => ((day + 3) % 7 + 7) % 7 + 1;

/// Minutos desde a meia-noite.
int minuteOfDay(DateTime d) => d.hour * 60 + d.minute;

/// Instante local: dia inteiro [day] às [minute] minutos após a meia-noite.
DateTime dateTimeAt(int day, int minute) {
  final d = dateFromEpochDay(day);
  return DateTime(d.year, d.month, d.day, minute ~/ 60, minute % 60);
}

/// 14:05, a partir de minutos desde a meia-noite. Valores de 1440 em
/// diante (dia seguinte) mostram só o horário: 1620 vira 03:00.
String formatMinute(int minute) {
  final m = minute % 1440;
  return '${_two(m ~/ 60)}:${_two(m % 60)}';
}

/// 11/11, sem o ano.
String formatDayMonthNumeric(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// Duração por extenso: "1h 05min", "25min" ou "40s".
String formatDuration(int seconds) {
  if (seconds < 60) return '${seconds < 0 ? 0 : seconds}s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '${m}min';
  return m == 0 ? '${h}h' : '${h}h ${_two(m)}min';
}

/// Mostrador de cronômetro: "05:09" ou "1:05:09".
String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(sec)}' : '${_two(m)}:${_two(sec)}';
}

/// "12 de novembro de 2026".
String formatLongDate(DateTime d) =>
    '${d.day} de ${_monthsLong[d.month - 1]} de ${d.year}';

const _monthsLong = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
