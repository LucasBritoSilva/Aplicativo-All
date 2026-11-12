/// Funções de texto usadas nas buscas.
library;

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas e sem acentos, para comparar textos digitados.
String normalizeText(String text) {
  final lower = text.toLowerCase().trim();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_accents[ch] ?? ch);
  }
  return out.toString();
}

/// Verdadeiro se algum dos [fields] contém a [query] (sem diferenciar
/// maiúsculas nem acentos). Busca vazia casa com tudo.
bool matchesQuery(String query, Iterable<String?> fields) {
  final q = normalizeText(query);
  if (q.isEmpty) return true;
  for (final f in fields) {
    if (f != null && normalizeText(f).contains(q)) return true;
  }
  return false;
}

/// Primeira letra minúscula ("Estudar" vira "estudar").
String lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

/// Só os dígitos de um telefone.
String onlyDigits(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

/// Número no formato internacional esperado pelo WhatsApp (só dígitos).
///
/// Números com 10 ou 11 dígitos são tratados como brasileiros e recebem o
/// código 55. Quem digitar "+" ou já começar com o código do país fica como
/// está. Devolve nulo se não houver dígitos suficientes.
String? whatsAppNumber(String phone) {
  final digits = onlyDigits(phone);
  if (digits.length < 8) return null;
  if (phone.trim().startsWith('+')) return digits;
  if (digits.length == 10 || digits.length == 11) return '55$digits';
  return digits;
}
