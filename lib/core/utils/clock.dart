import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio que avança a cada segundo enquanto alguma tela o observa.
///
/// Usado pelos cronômetros (rotina, pausas, limite de apps). As durações
/// são sempre recalculadas a partir dos horários gravados no banco; este
/// relógio só serve para redesenhar a tela.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});
