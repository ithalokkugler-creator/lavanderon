import 'ocorrencia.dart';

class Estatisticas {
  const Estatisticas({
    required this.reservas30d,
    required this.ocupacaoHoje,
    required this.reservasHoje,
    required this.checkinsHoje,
    required this.naoCompareceuHoje,
    required this.usoPorMaquina30d,
    required this.topAptos,
    required this.mapaCalor,
    required this.ocorrenciasAbertas,
    required this.taxaComparecimento30d,
  });

  /// Uma entrada por dia, do mais antigo ao mais recente.
  final List<(DateTime dia, int reservas)> reservas30d;

  /// 0.0 a 1.0: horas-máquina reservadas hoje / horas-máquina disponíveis.
  final double ocupacaoHoje;
  final int reservasHoje;
  final int checkinsHoje;
  final int naoCompareceuHoje;
  final Map<String, int> usoPorMaquina30d;
  final List<(String apto, int reservas, int noShows)> topAptos;

  /// 7 dias da semana (segunda primeiro) x 24 horas.
  final List<List<int>> mapaCalor;
  final Map<TipoOcorrencia, int> ocorrenciasAbertas;

  /// 0.0 a 1.0
  final double taxaComparecimento30d;
}
