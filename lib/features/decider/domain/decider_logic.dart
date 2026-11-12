import 'dart:math';

/// Confere o intervalo digitado. Devolve a mensagem de erro, ou nulo.
String? validateRange(int? min, int? max) {
  if (min == null || max == null) return 'Preencha o mínimo e o máximo.';
  if (min > max) return 'O mínimo não pode ser maior que o máximo.';
  if (max - min > 1000000000) return 'Intervalo grande demais.';
  return null;
}

/// Número sorteado entre [min] e [max], inclusive.
int drawNumber(int min, int max, [Random? random]) =>
    min + (random ?? Random.secure()).nextInt(max - min + 1);

/// Opções digitadas, uma por linha (ou separadas por vírgula), sem vazias.
List<String> parseOptions(String text) => [
  for (final part in text.split(RegExp(r'[\n,;]')))
    if (part.trim().isNotEmpty) part.trim(),
];

String drawOption(List<String> options, [Random? random]) =>
    options[(random ?? Random.secure()).nextInt(options.length)];
