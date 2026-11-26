import 'package:collection/collection.dart';

import '../../core/formatos.dart';
import '../../domain/models/models.dart';
import 'estado_demo.dart';

/// Quanto antes do início uma máquina livre passa a aparecer como "reservada".
const int kJanelaReservadaMin = 30;

/// Cálculos derivados (somente leitura): situação das máquinas, grade de
/// horários, alternativas, estatísticas e informação de roupa na máquina.
class Derivacao {
  Derivacao(this.e);
  final EstadoDemo e;

  // ---------------------------------------------------------------- Máquinas

  List<Maquina> maquinas() {
    final lista = e.maquinas.values.map(_derivar).toList();
    lista.sort((a, b) {
      final t = a.tipo.index.compareTo(b.tipo.index);
      return t != 0 ? t : a.ordem.compareTo(b.ordem);
    });
    return lista;
  }

  Maquina maquina(String id) => _derivar(e.maquinaBase(id));

  /// Assinatura barata do estado visível, para detectar mudanças por tempo.
  String assinatura() =>
      maquinas().map((m) => '${m.id}:${m.situacao.index}:${m.status.index}').join('|');

  Maquina _derivar(Maquina base) {
    final agora = e.agora;
    var status = base.status;
    var motivo = base.motivoIndisponivel;
    var ate = base.indisponivelAte;
    if (status == StatusMaquina.bloqueadaHoje &&
        ate != null &&
        !agora.isBefore(ate)) {
      status = StatusMaquina.disponivel;
      motivo = null;
      ate = null;
    }

    final daMaquina =
        e.reservas.values.where((r) => r.maquinaId == base.id).toList();
    final emUso = daMaquina.firstWhereOrNull((r) =>
        r.status == StatusReserva.emUso &&
        r.cronometro != null &&
        !r.cronometro!.terminou(agora));
    final cronTerminada = daMaquina
        .where((r) =>
            r.status == StatusReserva.emUso &&
            r.cronometro != null &&
            r.cronometro!.terminou(agora))
        .sortedBy<DateTime>((r) => r.cronometro!.terminaEm)
        .lastOrNull;
    final ag = e.aguardando[base.id];
    final ocupadaAte = e.ocupadaAte[base.id];

    // Próxima reserva ainda não confirmada cujo horário não terminou.
    final proxima = daMaquina
        .where((r) => r.status == StatusReserva.agendada && r.fim.isAfter(agora))
        .sortedBy<DateTime>((r) => r.inicio)
        .firstOrNull;

    var situacao = SituacaoMaquina.livre;
    String? aptoAtual;
    String? reservaAtual;
    DateTime? previsao;

    if (emUso != null) {
      situacao = SituacaoMaquina.emUso;
      aptoAtual = emUso.aptoId;
      reservaAtual = emUso.id;
      previsao = emUso.cronometro!.terminaEm;
    } else if (ag != null || cronTerminada != null) {
      situacao = SituacaoMaquina.aguardandoRetirada;
      aptoAtual = ag?.aptoId ?? cronTerminada!.aptoId;
      reservaAtual = ag?.reservaId ?? cronTerminada!.id;
      previsao = ag?.desde ?? cronTerminada!.cronometro!.terminaEm;
    } else if (ocupadaAte != null && ocupadaAte.isAfter(agora)) {
      situacao = SituacaoMaquina.ocupadaSemRegistro;
      previsao = ocupadaAte;
    } else if (proxima != null &&
        proxima.inicio.difference(agora).inMinutes < kJanelaReservadaMin) {
      situacao = SituacaoMaquina.reservada;
    }

    DateTime? livreAte;
    if (proxima != null && mesmoDia(proxima.inicio, agora)) {
      livreAte = proxima.inicio;
    }

    String? alerta;
    final leve = e.ocorrencias.firstWhereOrNull((o) =>
        o.tipo == TipoOcorrencia.maquina &&
        o.maquinaId == base.id &&
        o.aberta &&
        !o.bloqueouMaquina);
    if (leve != null) {
      alerta = leve.confirmacoes > 1
          ? '${leve.categoria} (${leve.confirmacoes} relatos)'
          : leve.categoria;
    }

    final roupaOutro =
        e.roupas.any((r) => r.localMaquinaId == base.id && !r.recolhida);

    return base.copyWith(
      status: status,
      motivoIndisponivel: motivo,
      indisponivelAte: ate,
      situacao: situacao,
      aptoAtual: aptoAtual,
      reservaAtualId: reservaAtual,
      previsaoFim: previsao,
      livreAte: livreAte,
      proximaReservaInicio: proxima?.inicio,
      proximaReservaApto: proxima?.aptoId,
      alerta: alerta,
      roupaDeOutroMorador: roupaOutro,
    );
  }

  // ------------------------------------------------------------------- Grade

  List<SlotGrade> grade(DateTime dia, TipoMaquina tipo) {
    final d0 = inicioDoDia(dia);
    final ms = e.baseDoTipo(tipo);
    final agora = e.agora;
    final porSlot = (24 * 60) ~/ e.config.slotMin;
    final slots = <SlotGrade>[];
    for (var i = 0; i < porSlot; i++) {
      final ini = d0.add(Duration(minutes: i * e.config.slotMin));
      final fim = ini.add(e.slot);
      final fechado = e.fechamentoNoPeriodo(ini, fim) != null;
      final itens = <SlotMaquina>[];
      for (final m in ms) {
        final oc = e.ocupante(m.id, ini, fim);
        String? motivo;
        var livre = true;
        String? apto;
        if (oc != null) {
          livre = false;
          apto = oc.aptoId;
        } else if (e.indisponivelNoPeriodo(m, ini, fim)) {
          livre = false;
          motivo = m.motivoIndisponivel ??
              (m.status == StatusMaquina.manutencao
                  ? 'Em manutenção'
                  : 'Indisponível');
        } else if ((e.ocupadaAte[m.id]?.isAfter(ini) ?? false) &&
            fim.isAfter(agora)) {
          livre = false;
          motivo = 'Ocupada (uso não registrado)';
        }
        itens.add(SlotMaquina(
          maquinaId: m.id,
          nome: m.nome,
          livre: livre && !fechado,
          aptoReserva: apto,
          motivoIndisponivel: fechado && livre ? 'Lavanderia fechada' : motivo,
        ));
      }
      slots.add(SlotGrade(
        inicio: ini,
        fim: fim,
        tipo: tipo,
        livres: itens.where((s) => s.livre).length,
        total: ms.length,
        passado: !fim.isAfter(agora),
        fechado: fechado,
        maquinas: itens,
      ));
    }
    return slots;
  }

  // ------------------------------------------------------------ Alternativas

  /// A máquina pode receber alguém no slot [ini, fim)?
  bool livreNoSlot(Maquina base, DateTime ini, DateTime fim, {String? exceto}) {
    if (e.indisponivelNoPeriodo(base, ini, fim)) return false;
    if (e.ocupante(base.id, ini, fim, exceto: exceto) != null) return false;
    final agora = e.agora;
    if (fim.isAfter(agora)) {
      final oc = e.ocupadaAte[base.id];
      if (oc != null && oc.isAfter(ini) && oc.isAfter(agora)) return false;
      if (!ini.isAfter(agora)) {
        // O slot já está rolando: a máquina precisa estar fisicamente livre.
        final s = _derivar(base).situacao;
        if (s == SituacaoMaquina.emUso ||
            s == SituacaoMaquina.aguardandoRetirada ||
            s == SituacaoMaquina.ocupadaSemRegistro) {
          return false;
        }
      }
    }
    return true;
  }

  List<Maquina> alternativas(TipoMaquina tipo, DateTime inicio,
      {String? excetoMaquinaId, String? excetoReserva}) {
    final ini = e.inicioDoSlot(inicio);
    final fim = ini.add(e.slot);
    final livres = e
        .baseDoTipo(tipo)
        .where((m) => m.id != excetoMaquinaId)
        .where((m) => livreNoSlot(m, ini, fim, exceto: excetoReserva))
        .toList();
    livres.sort((a, b) {
      final c = e.usoRecente(a.id).compareTo(e.usoRecente(b.id));
      return c != 0 ? c : a.ordem.compareTo(b.ordem);
    });
    return livres.map(_derivar).toList();
  }

  // -------------------------------------------------------------------- Roupa

  InfoRoupaMaquina infoRoupa(String maquinaId) {
    final m = maquina(maquinaId);
    final agora = e.agora;
    final ag = e.aguardando[maquinaId];
    final dono = ag != null
        ? e.reservas[ag.reservaId]
        : e.ultimoUsoConfirmado(maquinaId);
    DateTime? fimCiclo;
    if (ag != null) {
      fimCiclo = ag.desde;
    } else if (dono != null) {
      fimCiclo = dono.cronometro?.terminaEm ?? dono.fim;
    }
    final prazo = fimCiclo?.add(Duration(minutes: e.config.prazoRetiradaMin));
    final temRoupa = m.situacao == SituacaoMaquina.aguardandoRetirada ||
        m.situacao == SituacaoMaquina.ocupadaSemRegistro;
    final donoConhecido = dono != null &&
        (m.situacao == SituacaoMaquina.aguardandoRetirada ||
            m.situacao == SituacaoMaquina.emUso);
    return InfoRoupaMaquina(
      maquina: m,
      donoApto: donoConhecido ? dono.aptoId : null,
      fimCiclo: donoConhecido ? fimCiclo : null,
      prazoRetirada: donoConhecido ? prazo : null,
      prazoPassou: !donoConhecido || prazo == null || !agora.isBefore(prazo),
      temRoupa: temRoupa,
    );
  }

  // ------------------------------------------------------------ Estatísticas

  Estatisticas estatisticas() {
    final agora = e.agora;
    final hoje0 = inicioDoDia(agora);
    final desde = hoje0.subtract(const Duration(days: 29));
    final todas = e.reservas.values.toList();
    bool conta(Reserva r) =>
        r.status != StatusReserva.cancelada;

    final reservas30 = <(DateTime, int)>[];
    for (var i = 0; i < 30; i++) {
      final d = desde.add(Duration(days: i));
      final n = todas
          .where((r) => conta(r) && mesmoDia(r.inicio, d))
          .length;
      reservas30.add((d, n));
    }

    final hoje = todas.where((r) => mesmoDia(r.inicio, agora)).toList();
    final ativasHoje = hoje.where((r) =>
        r.status == StatusReserva.agendada ||
        r.status == StatusReserva.emUso ||
        r.status == StatusReserva.concluida);
    final disponiveis = e.maquinas.values
        .where((m) => m.status != StatusMaquina.desativada)
        .length;
    final slotsDia = (24 * 60) ~/ e.config.slotMin;
    final ocupacao = disponiveis == 0
        ? 0.0
        : (ativasHoje.length / (disponiveis * slotsDia)).clamp(0.0, 1.0);

    final noPeriodo =
        todas.where((r) => !r.inicio.isBefore(desde) && r.inicio.isBefore(agora)).toList();
    final uso = <String, int>{};
    for (final m in e.maquinas.values.sortedBy<num>((m) => m.ordem)) {
      uso[m.nome] = noPeriodo
          .where((r) =>
              r.maquinaId == m.id &&
              (r.status == StatusReserva.concluida ||
                  r.status == StatusReserva.emUso))
          .length;
    }

    final porApto = groupBy(noPeriodo.where(conta), (Reserva r) => r.aptoId);
    final top = porApto.entries
        .map((en) => (
              en.key,
              en.value.length,
              en.value.where((r) => r.status == StatusReserva.naoCompareceu).length
            ))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final mapa = List.generate(7, (_) => List.filled(24, 0));
    for (final r in noPeriodo.where(conta)) {
      mapa[r.inicio.weekday - 1][r.inicio.hour]++;
    }

    final abertas = <TipoOcorrencia, int>{};
    for (final o in e.ocorrencias.where((o) => o.aberta)) {
      abertas[o.tipo] = (abertas[o.tipo] ?? 0) + 1;
    }

    final comparecimentoBase = noPeriodo.where((r) =>
        r.status == StatusReserva.concluida ||
        r.status == StatusReserva.emUso ||
        r.status == StatusReserva.naoCompareceu);
    final compareceu = comparecimentoBase
        .where((r) => r.status != StatusReserva.naoCompareceu)
        .length;

    return Estatisticas(
      reservas30d: reservas30,
      ocupacaoHoje: ocupacao,
      reservasHoje: hoje.where(conta).length,
      checkinsHoje: hoje.where((r) => r.checkinEm != null).length,
      naoCompareceuHoje:
          hoje.where((r) => r.status == StatusReserva.naoCompareceu).length,
      usoPorMaquina30d: uso,
      topAptos: top.take(8).toList(),
      mapaCalor: mapa,
      ocorrenciasAbertas: abertas,
      taxaComparecimento30d: comparecimentoBase.isEmpty
          ? 1.0
          : compareceu / comparecimentoBase.length,
    );
  }
}
