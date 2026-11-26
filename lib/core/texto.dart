/// Normaliza texto para comparação: minúsculas, sem acentos e sem espaços
/// extras ("  JOÃO   Pedro " -> "joao pedro"). Usado no login (RN-25).
String normalizarTexto(String s) {
  const de = 'àáâãäåèéêëìíîïòóôõöùúûüçñýÿ';
  const para = 'aaaaaaeeeeiiiiooooouuuucnyy';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}
