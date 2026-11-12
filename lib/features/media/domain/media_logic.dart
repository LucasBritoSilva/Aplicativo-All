import 'dart:math';

import '../data/media_tables.dart';

/// Dados mínimos de um título para ranking e sorteio.
typedef MediaEntry = ({
  int id,
  MediaKind kind,
  String title,
  bool watched,
  double? rating,
});

/// Ranking: só os assistidos com nota, da maior para a menor. Empate é
/// decidido pelo título, para a ordem ser estável.
List<T> rankWatched<T>(Iterable<T> items, MediaEntry Function(T) entry) {
  final list = [
    for (final i in items)
      if (entry(i).watched && entry(i).rating != null) i,
  ];
  list.sort((a, b) {
    final ea = entry(a), eb = entry(b);
    final byRating = eb.rating!.compareTo(ea.rating!);
    return byRating != 0
        ? byRating
        : ea.title.toLowerCase().compareTo(eb.title.toLowerCase());
  });
  return list;
}

/// Sorteia um título ainda não assistido do tipo pedido (nulo = todos).
/// Evita repetir [avoidId] quando houver outra opção.
T? drawUnwatched<T>(
  Iterable<T> items,
  MediaEntry Function(T) entry, {
  MediaKind? kind,
  int? avoidId,
  Random? random,
}) {
  final pool = [
    for (final i in items)
      if (!entry(i).watched && (kind == null || entry(i).kind == kind)) i,
  ];
  if (pool.isEmpty) return null;
  final options = pool.length > 1 && avoidId != null
      ? pool.where((i) => entry(i).id != avoidId).toList()
      : pool;
  return options[(random ?? Random()).nextInt(options.length)];
}

/// Fração de episódios assistidos (nulo se o total não foi informado).
double? episodeProgress(int? episode, int? total) {
  if (total == null || total <= 0 || episode == null) return null;
  return (episode / total).clamp(0.0, 1.0);
}
