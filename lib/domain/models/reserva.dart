import 'maquina.dart';
import 'unset.dart';

enum StatusReserva {
  agendada,
  emUso,
  concluida,
  cancelada,
  naoCompareceu,
  precisaAcao,
  interrompida,
}

enum OrigemAcao { app, tablet, sindico }

class Programa {
  const Programa(this.nome, this.minutos);
  final String nome;
  final int minutos;
}

class Cronometro {
  const Cronometro({
    this.programa,
    required this.duracaoMin,
    required this.iniciadoEm,
    required this.terminaEm,
  });

  final String? programa;
  final int duracaoMin;
  final DateTime iniciadoEm;
  final DateTime terminaEm;

  Duration restante(DateTime agora) {
    final r = terminaEm.difference(agora);
    return r.isNegative ? Duration.zero : r;
  }

  /// 0.0 a 1.0
  double progresso(DateTime agora) {
    final total = terminaEm.difference(iniciadoEm).inSeconds;
    if (total <= 0) return 1;
    return (agora.difference(iniciadoEm).inSeconds / total).clamp(0.0, 1.0);
  }

  bool terminou(DateTime agora) => !agora.isBefore(terminaEm);

  Cronometro copyWith({
    Object? programa = kUnset,
    int? duracaoMin,
    DateTime? iniciadoEm,
    DateTime? terminaEm,
  }) =>
      Cronometro(
        programa: escolher<String>(programa, this.programa),
        duracaoMin: duracaoMin ?? this.duracaoMin,
        iniciadoEm: iniciadoEm ?? this.iniciadoEm,
        terminaEm: terminaEm ?? this.terminaEm,
      );
}

class Reserva {
  const Reserva({
    required this.id,
    required this.maquinaId,
    required this.maquinaNome,
    required this.tipo,
    required this.aptoId,
    required this.criadaPorNome,
    required this.inicio,
    required this.fim,
    required this.status,
    this.origem = OrigemAcao.app,
    this.usoImediato = false,
    this.checkinEm,
    this.cronometro,
    this.finalizadaEm,
    this.motivoCancelamento,
    this.mensagemAcao,
    this.historico = const [],
  });

  final String id;
  final String maquinaId;
  final String maquinaNome;
  final TipoMaquina tipo;
  final String aptoId;
  final String criadaPorNome;
  final DateTime inicio;
  final DateTime fim;
  final StatusReserva status;
  final OrigemAcao origem;
  final bool usoImediato;
  final DateTime? checkinEm;
  final Cronometro? cronometro;
  final DateTime? finalizadaEm;
  final String? motivoCancelamento;

  /// Texto mostrado quando `status == precisaAcao`.
  final String? mensagemAcao;

  /// Linhas da linha do tempo, já legíveis ("18:07 · Uso confirmado no app").
  final List<String> historico;

  /// Reserva ainda "viva" (conta para limites e ocupa o horário).
  bool get ativa =>
      status == StatusReserva.agendada ||
      status == StatusReserva.emUso ||
      status == StatusReserva.precisaAcao;

  /// RN-06: janela de check-in (10 min antes até 15 min depois do início).
  bool podeConfirmar(DateTime agora,
      {int antesMin = 10, int toleranciaMin = 15}) {
    if (status != StatusReserva.agendada) return false;
    final de = inicio.subtract(Duration(minutes: antesMin));
    final ate = inicio.add(Duration(minutes: toleranciaMin));
    return !agora.isBefore(de) && !agora.isAfter(ate);
  }

  /// Cancelável enquanto ainda não foi confirmada nem encerrada.
  bool podeCancelar(DateTime agora) =>
      (status == StatusReserva.agendada ||
          status == StatusReserva.precisaAcao) &&
      agora.isBefore(fim);

  /// RN-08: cancelar a menos de 30 min do início conta como cancelamento tardio.
  bool cancelamentoTardio(DateTime agora) =>
      inicio.difference(agora) < const Duration(minutes: 30);

  Reserva copyWith({
    String? maquinaId,
    String? maquinaNome,
    TipoMaquina? tipo,
    String? criadaPorNome,
    DateTime? inicio,
    DateTime? fim,
    StatusReserva? status,
    OrigemAcao? origem,
    bool? usoImediato,
    Object? checkinEm = kUnset,
    Object? cronometro = kUnset,
    Object? finalizadaEm = kUnset,
    Object? motivoCancelamento = kUnset,
    Object? mensagemAcao = kUnset,
    List<String>? historico,
  }) =>
      Reserva(
        id: id,
        maquinaId: maquinaId ?? this.maquinaId,
        maquinaNome: maquinaNome ?? this.maquinaNome,
        tipo: tipo ?? this.tipo,
        aptoId: aptoId,
        criadaPorNome: criadaPorNome ?? this.criadaPorNome,
        inicio: inicio ?? this.inicio,
        fim: fim ?? this.fim,
        status: status ?? this.status,
        origem: origem ?? this.origem,
        usoImediato: usoImediato ?? this.usoImediato,
        checkinEm: escolher<DateTime>(checkinEm, this.checkinEm),
        cronometro: escolher<Cronometro>(cronometro, this.cronometro),
        finalizadaEm: escolher<DateTime>(finalizadaEm, this.finalizadaEm),
        motivoCancelamento:
            escolher<String>(motivoCancelamento, this.motivoCancelamento),
        mensagemAcao: escolher<String>(mensagemAcao, this.mensagemAcao),
        historico: historico ?? this.historico,
      );
}
