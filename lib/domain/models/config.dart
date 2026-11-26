import 'maquina.dart';
import 'reserva.dart';
import 'unset.dart';

class Fechamento {
  const Fechamento({
    required this.id,
    required this.motivo,
    required this.inicio,
    this.fim,
    this.ativo = true,
  });

  final String id;
  final String motivo;
  final DateTime inicio;

  /// `null` = fechada até o síndico reabrir.
  final DateTime? fim;
  final bool ativo;

  /// O fechamento cobre algum instante do intervalo [de, ate)?
  bool cobre(DateTime de, DateTime ate) =>
      ativo && inicio.isBefore(ate) && (fim == null || fim!.isAfter(de));

  Fechamento copyWith({Object? fim = kUnset, bool? ativo}) => Fechamento(
        id: id,
        motivo: motivo,
        inicio: inicio,
        fim: escolher<DateTime>(fim, this.fim),
        ativo: ativo ?? this.ativo,
      );
}

class ConfigRegras {
  const ConfigRegras({
    this.slotMin = 60,
    this.antecedenciaDias = 7,
    this.lavagensDia = 2,
    this.secagensDia = 2,
    this.futurasMax = 6,
    this.checkinAntesMin = 10,
    this.toleranciaMin = 15,
    this.prazoRetiradaMin = 10,
    this.avisoAntesMin = 5,
    this.programas = programasPadrao,
    this.bloqueioNoturnoDe = '20:00',
    this.bloqueioNoturnoAte = '08:00',
  });

  final int slotMin;
  final int antecedenciaDias;
  final int lavagensDia;
  final int secagensDia;
  final int futurasMax;
  final int checkinAntesMin;
  final int toleranciaMin;
  final int prazoRetiradaMin;
  final int avisoAntesMin;
  final Map<TipoMaquina, List<Programa>> programas;
  final String bloqueioNoturnoDe;
  final String bloqueioNoturnoAte;

  static const Map<TipoMaquina, List<Programa>> programasPadrao = {
    TipoMaquina.lavadora: [
      Programa('Rápido', 30),
      Programa('Normal', 45),
      Programa('Pesado', 70),
    ],
    TipoMaquina.secadora: [
      Programa('Delicada', 40),
      Programa('Normal', 60),
      Programa('Pesada', 80),
    ],
  };

  int limiteDia(TipoMaquina t) =>
      t == TipoMaquina.lavadora ? lavagensDia : secagensDia;
}

class SlotMaquina {
  const SlotMaquina({
    required this.maquinaId,
    required this.nome,
    required this.livre,
    this.aptoReserva,
    this.motivoIndisponivel,
  });

  final String maquinaId;
  final String nome;
  final bool livre;

  /// Apartamento que reservou (RN-17: o número aparece, o nome nunca).
  final String? aptoReserva;
  final String? motivoIndisponivel;
}

class SlotGrade {
  const SlotGrade({
    required this.inicio,
    required this.fim,
    required this.tipo,
    required this.livres,
    required this.total,
    this.passado = false,
    this.fechado = false,
    this.maquinas = const [],
  });

  final DateTime inicio;
  final DateTime fim;
  final TipoMaquina tipo;
  final int livres;

  /// Máquinas do tipo cadastradas (inclui as indisponíveis; veja `maquinas`).
  final int total;

  /// O horário já terminou.
  final bool passado;

  /// Lavanderia fechada neste horário.
  final bool fechado;
  final List<SlotMaquina> maquinas;
}
