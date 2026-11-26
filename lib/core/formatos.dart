// Helpers de formatação pt_BR. Escritos à mão (sem depender de
// initializeDateFormatting) para funcionar igual em testes, web e apps.

const _diasCurtos = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _diasLongos = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const _meses = [
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

String _dois(int n) => n.toString().padLeft(2, '0');

/// "18:40"
String hora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

/// "qua, 26/11"
String dataCurta(DateTime d) =>
    '${_diasCurtos[d.weekday - 1]}, ${_dois(d.day)}/${_dois(d.month)}';

/// "quarta-feira, 26 de novembro"
String dataLonga(DateTime d) =>
    '${_diasLongos[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

/// "qua"
String diaSemanaCurto(DateTime d) => _diasCurtos[d.weekday - 1];

/// "hoje", "amanhã", "ontem" ou "qua, 26/11".
String diaRelativo(DateTime d, DateTime agora) {
  final dif = inicioDoDia(d).difference(inicioDoDia(agora)).inDays;
  if (dif == 0) return 'hoje';
  if (dif == 1) return 'amanhã';
  if (dif == -1) return 'ontem';
  return dataCurta(d);
}

/// "hoje, 19:00" / "amanhã, 08:00" / "qui, 27/11, 08:00"
String dataHoraRelativa(DateTime d, DateTime agora) =>
    '${diaRelativo(d, agora)}, ${hora(d)}';

/// Meia-noite local do dia de [d].
DateTime inicioDoDia(DateTime d) => DateTime(d.year, d.month, d.day);

bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "há 6 min", "em 12 min", "agora", "há 2 h", "em 1 h 20 min".
String relativo(DateTime alvo, DateTime agora) {
  final dif = alvo.difference(agora);
  final futuro = !dif.isNegative;
  final seg = dif.abs().inSeconds;
  if (seg < 45) return 'agora';
  final min = (seg / 60).round();
  String corpo;
  if (min < 60) {
    corpo = '$min min';
  } else if (min < 24 * 60) {
    final h = min ~/ 60;
    final m = min % 60;
    corpo = m == 0 ? '$h h' : '$h h $m min';
  } else {
    final dias = min ~/ (24 * 60);
    corpo = dias == 1 ? '1 dia' : '$dias dias';
  }
  return futuro ? 'em $corpo' : 'há $corpo';
}

/// "32:15" (mm:ss) ou "1:02:15" quando passa de uma hora.
String duracao(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h:${_dois(m)}:${_dois(s)}';
  return '${_dois(m)}:${_dois(s)}';
}

/// "45 min", "1 h", "1 h 10 min"
String minutosLegivel(int min) {
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}
