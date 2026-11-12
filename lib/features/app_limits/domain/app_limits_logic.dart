/// Cálculos do limite de uso de aplicativos (a contagem vem do Android).
library;

class LimitStatus {
  const LimitStatus({required this.usedMs, required this.limitMinutes});

  final int usedMs;
  final int limitMinutes;

  int get limitMs => limitMinutes * 60000;

  /// Tempo restante (zero quando o limite foi atingido).
  int get remainingMs => usedMs >= limitMs ? 0 : limitMs - usedMs;

  /// Quanto passou do limite (zero se não passou).
  int get overMs => usedMs > limitMs ? usedMs - limitMs : 0;

  bool get exceeded => usedMs >= limitMs;

  double get fraction => limitMs == 0 ? 1 : (usedMs / limitMs).clamp(0.0, 1.0);
}

/// "1h 05min", "12min" ou "menos de 1min".
String formatUsage(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 1) return ms <= 0 ? '0min' : 'menos de 1min';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}min';
  return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}min';
}

/// Limites que o serviço nativo deve vigiar (só os ativos).
Map<String, int> activeLimits(
  Iterable<({String packageName, int limitMinutes, bool enabled})> limits,
) => {
  for (final l in limits)
    if (l.enabled && l.limitMinutes > 0) l.packageName: l.limitMinutes,
};
