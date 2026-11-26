import 'package:intl/intl.dart';

/// Formatação pt-BR usada pelas telas.
abstract final class Fmt {
  static final _hora = DateFormat('HH:mm', 'pt_BR');
  static final _diaSemana = DateFormat('EEE', 'pt_BR');
  static final _diaMes = DateFormat('dd/MM', 'pt_BR');
  static final _longa = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

  static String hora(DateTime d) => _hora.format(d);

  /// "qua, 26/11"
  static String dataCurta(DateTime d) => '${_semPonto(_diaSemana.format(d))}, ${_diaMes.format(d)}';

  /// "quarta-feira, 26 de novembro"
  static String dataLonga(DateTime d) => _longa.format(d);

  /// "Hoje", "Amanhã", "Ontem" ou "qua, 26/11"
  static String dia(DateTime d, DateTime agora) {
    final a = DateTime(agora.year, agora.month, agora.day);
    final b = DateTime(d.year, d.month, d.day);
    final dif = b.difference(a).inDays;
    if (dif == 0) return 'Hoje';
    if (dif == 1) return 'Amanhã';
    if (dif == -1) return 'Ontem';
    return dataCurta(d);
  }

  /// "Hoje, 19:00–20:00"
  static String intervalo(DateTime ini, DateTime fim, DateTime agora) => '${dia(ini, agora)}, ${hora(ini)}–${hora(fim)}';

  /// "32:15" ou "1:05:20"
  static String cronometro(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String dois(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${dois(m)}:${dois(s)}' : '${dois(m)}:${dois(s)}';
  }

  /// "em 12 min", "há 6 min", "agora"
  static String relativo(DateTime alvo, DateTime agora) {
    final dif = alvo.difference(agora);
    // Futuro arredonda para cima (contagem regressiva), passado para baixo.
    final min = dif.isNegative ? dif.inMinutes.abs() : (dif.inSeconds / 60).ceil();
    String txt;
    if (min < 1) return 'agora';
    if (min < 60) {
      txt = '$min min';
    } else if (min < 60 * 24) {
      final h = min ~/ 60, r = min % 60;
      txt = r == 0 ? '$h h' : '$h h $r min';
    } else {
      final d = min ~/ (60 * 24);
      txt = d == 1 ? '1 dia' : '$d dias';
    }
    return dif.isNegative ? 'há $txt' : 'em $txt';
  }

  static String minutos(int m) => m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min');

  static String _semPonto(String s) => s.replaceAll('.', '');
}
