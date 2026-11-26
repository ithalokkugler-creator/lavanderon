import 'unset.dart';

enum TipoMaquina {
  lavadora('Lavadora', 'Lavadoras'),
  secadora('Secadora', 'Secadoras');

  const TipoMaquina(this.rotulo, this.plural);
  final String rotulo;
  final String plural;
}

enum StatusMaquina { disponivel, bloqueadaHoje, manutencao, desativada }

enum SituacaoMaquina {
  livre,
  reservada,
  emUso,
  aguardandoRetirada,
  ocupadaSemRegistro,
}

/// Máquina com o estado já DERIVADO (reservas + relógio simulado).
/// Quem calcula `situacao`, `livreAte` etc. é o repositório.
class Maquina {
  const Maquina({
    required this.id,
    required this.nome,
    required this.nomeCurto,
    required this.tipo,
    required this.ordem,
    required this.cicloMin,
    this.status = StatusMaquina.disponivel,
    this.motivoIndisponivel,
    this.indisponivelAte,
    this.situacao = SituacaoMaquina.livre,
    this.aptoAtual,
    this.reservaAtualId,
    this.previsaoFim,
    this.livreAte,
    this.proximaReservaInicio,
    this.proximaReservaApto,
    this.alerta,
    this.roupaDeOutroMorador = false,
  });

  final String id;
  final String nome;
  final String nomeCurto;
  final TipoMaquina tipo;
  final int ordem;
  final int cicloMin;
  final StatusMaquina status;
  final String? motivoIndisponivel;
  final DateTime? indisponivelAte;
  final SituacaoMaquina situacao;
  final String? aptoAtual;
  final String? reservaAtualId;
  final DateTime? previsaoFim;

  /// Início da próxima reserva HOJE. `null` = livre pelo resto do dia.
  final DateTime? livreAte;
  final DateTime? proximaReservaInicio;
  final String? proximaReservaApto;

  /// Problema leve (não bloqueia a máquina).
  final String? alerta;
  final bool roupaDeOutroMorador;

  bool get indisponivel => status != StatusMaquina.disponivel;

  Maquina copyWith({
    String? nome,
    String? nomeCurto,
    int? ordem,
    int? cicloMin,
    StatusMaquina? status,
    Object? motivoIndisponivel = kUnset,
    Object? indisponivelAte = kUnset,
    SituacaoMaquina? situacao,
    Object? aptoAtual = kUnset,
    Object? reservaAtualId = kUnset,
    Object? previsaoFim = kUnset,
    Object? livreAte = kUnset,
    Object? proximaReservaInicio = kUnset,
    Object? proximaReservaApto = kUnset,
    Object? alerta = kUnset,
    bool? roupaDeOutroMorador,
  }) =>
      Maquina(
        id: id,
        nome: nome ?? this.nome,
        nomeCurto: nomeCurto ?? this.nomeCurto,
        tipo: tipo,
        ordem: ordem ?? this.ordem,
        cicloMin: cicloMin ?? this.cicloMin,
        status: status ?? this.status,
        motivoIndisponivel:
            escolher<String>(motivoIndisponivel, this.motivoIndisponivel),
        indisponivelAte:
            escolher<DateTime>(indisponivelAte, this.indisponivelAte),
        situacao: situacao ?? this.situacao,
        aptoAtual: escolher<String>(aptoAtual, this.aptoAtual),
        reservaAtualId: escolher<String>(reservaAtualId, this.reservaAtualId),
        previsaoFim: escolher<DateTime>(previsaoFim, this.previsaoFim),
        livreAte: escolher<DateTime>(livreAte, this.livreAte),
        proximaReservaInicio:
            escolher<DateTime>(proximaReservaInicio, this.proximaReservaInicio),
        proximaReservaApto:
            escolher<String>(proximaReservaApto, this.proximaReservaApto),
        alerta: escolher<String>(alerta, this.alerta),
        roupaDeOutroMorador: roupaDeOutroMorador ?? this.roupaDeOutroMorador,
      );
}
