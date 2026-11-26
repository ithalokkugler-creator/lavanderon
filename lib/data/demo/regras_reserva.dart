import 'package:collection/collection.dart';

import '../../core/formatos.dart';
import '../../domain/app_erro.dart';
import '../../domain/models/models.dart';
import 'derivacao.dart';
import 'estado_demo.dart';

String _origemTexto(OrigemAcao o) => switch (o) {
      OrigemAcao.app => 'no app',
      OrigemAcao.tablet => 'no tablet',
      OrigemAcao.sindico => 'pelo síndico',
    };

/// Regras de reserva, uso e cronômetro: RN-01 a RN-11, RN-19 e RN-27.
class RegrasReserva {
  RegrasReserva(this.e, this.d);
  final EstadoDemo e;
  final Derivacao d;

  // ------------------------------------------------------------ Validações

  void exigirAptoAtivo(Morador quem, OrigemAcao origem) {
    if (origem == OrigemAcao.sindico) return;
    if (!e.aptoAtivo(quem.aptoId)) {
      throw const AppErro('APTO_SUSPENSO',
          'O acesso do seu apartamento está suspenso. Fale com o síndico.');
    }
  }

  void _exigirDono(Reserva r, Morador quem) {
    if (r.aptoId != quem.aptoId) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva é de outro apartamento.');
    }
  }

  /// RN-04. Conta reservas do dia (agendadas, em uso e já usadas) e as
  /// futuras ativas do apartamento.
  void _checarLimites(String aptoId, TipoMaquina tipo, DateTime inicio,
      {bool checarFuturas = true}) {
    final doDia = e.reservas.values.where((r) =>
        r.aptoId == aptoId &&
        r.tipo == tipo &&
        mesmoDia(r.inicio, inicio) &&
        (r.ativa || r.status == StatusReserva.concluida));
    if (doDia.length >= e.config.limiteDia(tipo)) {
      throw const AppErro('LIMITE',
          'Seu apartamento já atingiu o limite de reservas para esse dia.');
    }
    if (checarFuturas) {
      final futuras = e.reservas.values.where((r) =>
          r.aptoId == aptoId &&
          (r.status == StatusReserva.agendada ||
              r.status == StatusReserva.precisaAcao) &&
          r.inicio.isAfter(e.agora));
      if (futuras.length >= e.config.futurasMax) {
        throw AppErro('LIMITE',
            'Seu apartamento já tem ${e.config.futurasMax} reservas futuras. Cancele uma para reservar outra.');
      }
    }
  }

  void _exigirAberta(DateTime ini, DateTime fim) {
    final f = e.fechamentoNoPeriodo(ini, fim);
    if (f != null) {
      throw AppErro('FECHADA',
          'A lavanderia estará fechada nesse horário: ${f.motivo}.');
    }
  }

  AppErro _erroIndisponivel(Maquina m) {
    final como = m.status == StatusMaquina.manutencao
        ? 'em manutenção'
        : m.status == StatusMaquina.desativada
            ? 'desativada'
            : 'bloqueada';
    return AppErro('MAQUINA_INDISPONIVEL',
        'A ${m.nome} está $como. Veja as outras opções.');
  }

  // --------------------------------------------------------------- Reservar

  Reserva reservar({
    required Morador quem,
    required DateTime inicio,
    required TipoMaquina tipo,
    String? maquinaId,
    OrigemAcao origem = OrigemAcao.app,
  }) {
    exigirAptoAtivo(quem, origem);
    final agora = e.agora;
    final ini = e.inicioDoSlot(inicio);
    final fim = ini.add(e.slot);

    if (!ini.isAfter(agora)) {
      throw const AppErro('HORARIO_INVALIDO',
          'Esse horário já começou. Para usar uma máquina agora, use "Usar agora".');
    }
    if (ini.isAfter(agora.add(Duration(days: e.config.antecedenciaDias)))) {
      throw AppErro('HORARIO_INVALIDO',
          'Você pode reservar com até ${e.config.antecedenciaDias} dias de antecedência.');
    }
    _exigirAberta(ini, fim);
    _checarLimites(quem.aptoId, tipo, ini);

    Maquina escolhida;
    if (maquinaId != null) {
      escolhida = e.maquinaBase(maquinaId);
      if (escolhida.tipo != tipo) {
        throw const AppErro('NAO_PERMITIDO',
            'Essa máquina não é do tipo escolhido.');
      }
      if (e.indisponivelNoPeriodo(escolhida, ini, fim)) {
        throw _erroIndisponivel(escolhida);
      }
      if (e.ocupante(maquinaId, ini, fim) != null) {
        throw const AppErro('SLOT_OCUPADO',
            'Alguém acabou de reservar esse horário. Escolha outro.');
      }
    } else {
      final livres = d.alternativas(tipo, ini);
      if (livres.isEmpty) {
        throw const AppErro('SLOT_OCUPADO',
            'Alguém acabou de reservar esse horário. Escolha outro.');
      }
      escolhida = e.maquinaBase(livres.first.id);
    }

    final r = Reserva(
      id: e.novoId('r'),
      maquinaId: escolhida.id,
      maquinaNome: escolhida.nome,
      tipo: tipo,
      aptoId: quem.aptoId,
      criadaPorNome: quem.nome,
      inicio: ini,
      fim: fim,
      status: StatusReserva.agendada,
      origem: origem,
      historico: [
        e.linha('Reserva criada por ${quem.nome} ${_origemTexto(origem)}'),
      ],
    );
    e.salvarReserva(r);
    return r;
  }

  // -------------------------------------------------------------- Usar agora

  Reserva usarAgora({
    required Morador quem,
    required String maquinaId,
    required int duracaoMin,
    String? programa,
    OrigemAcao origem = OrigemAcao.app,
  }) {
    exigirAptoAtivo(quem, origem);
    _validarDuracao(duracaoMin);
    final agora = e.agora;
    final m = e.maquinaBase(maquinaId);
    final ini = e.inicioDoSlot(agora);
    var fim = ini.add(e.slot);
    final termina = agora.add(Duration(minutes: duracaoMin));

    _exigirAberta(agora, termina);
    if (e.indisponivelNoPeriodo(m, agora, termina)) throw _erroIndisponivel(m);
    _checarLimites(quem.aptoId, m.tipo, ini, checarFuturas: false);

    final situacao = d.maquina(maquinaId).situacao;
    if (situacao == SituacaoMaquina.emUso ||
        situacao == SituacaoMaquina.aguardandoRetirada ||
        situacao == SituacaoMaquina.ocupadaSemRegistro) {
      throw AppErro('SLOT_OCUPADO',
          'A ${m.nome} está ocupada agora. Escolha outra máquina.');
    }
    final atual = e.ocupante(maquinaId, ini, fim);
    if (atual != null) {
      throw AppErro('SLOT_OCUPADO',
          'A ${m.nome} está reservada às ${hora(atual.inicio)}. Escolha outra máquina.');
    }

    // Slot(s) seguinte(s), se o programa passar do fim do horário (RN-11/27).
    final provisoria = Reserva(
      id: 'tmp',
      maquinaId: m.id,
      maquinaNome: m.nome,
      tipo: m.tipo,
      aptoId: quem.aptoId,
      criadaPorNome: quem.nome,
      inicio: ini,
      fim: fim,
      status: StatusReserva.agendada,
    );
    fim = _fimParaCronometro(provisoria, termina);

    final r = Reserva(
      id: e.novoId('r'),
      maquinaId: m.id,
      maquinaNome: m.nome,
      tipo: m.tipo,
      aptoId: quem.aptoId,
      criadaPorNome: quem.nome,
      inicio: ini,
      fim: fim,
      status: StatusReserva.emUso,
      origem: origem,
      usoImediato: true,
      checkinEm: agora,
      cronometro: Cronometro(
        programa: programa,
        duracaoMin: duracaoMin,
        iniciadoEm: agora,
        terminaEm: termina,
      ),
      historico: [
        e.linha('Uso imediato iniciado por ${quem.nome} ${_origemTexto(origem)}'),
        e.linha(
            'Cronômetro ligado: ${minutosLegivel(duracaoMin)}${programa != null ? ' ($programa)' : ''}, pronta às ${hora(termina)}'),
      ],
    );
    e.salvarReserva(r);
    e.aguardando.remove(m.id);
    return r;
  }

  // ------------------------------------------------------------ Confirmar uso

  void confirmarUso({
    required String reservaId,
    required Morador quem,
    required int duracaoMin,
    String? programa,
    OrigemAcao origem = OrigemAcao.app,
  }) {
    final r = e.reserva(reservaId);
    _exigirDono(r, quem);
    exigirAptoAtivo(quem, origem);
    _validarDuracao(duracaoMin);
    if (r.status != StatusReserva.agendada) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não pode mais ser confirmada.');
    }
    final agora = e.agora;
    final de = r.inicio.subtract(Duration(minutes: e.config.checkinAntesMin));
    final ate = r.inicio.add(Duration(minutes: e.config.toleranciaMin));
    if (agora.isBefore(de)) {
      throw AppErro('FORA_JANELA_CHECKIN',
          'Você pode confirmar o uso a partir das ${hora(de)}.');
    }
    if (agora.isAfter(ate)) {
      throw const AppErro('FORA_JANELA_CHECKIN',
          'O prazo para confirmar esse horário já passou.');
    }
    final m = e.maquinaBase(r.maquinaId);
    if (e.indisponivelNoPeriodo(m, agora, r.fim)) throw _erroIndisponivel(m);
    _exigirMaquinaSemRoupaAlheia(r);
    aplicarCheckin(r, duracaoMin, programa, origem, quem.nome);
  }

  void _exigirMaquinaSemRoupaAlheia(Reserva r) {
    final ag = e.aguardando[r.maquinaId];
    if (ag != null && ag.aptoId != r.aptoId) {
      throw AppErro('SLOT_OCUPADO',
          'A ${r.maquinaNome} ainda está com a roupa de outro morador. Use "A máquina está ocupada" para trocar de máquina.');
    }
    final oc = e.ocupadaAte[r.maquinaId];
    if (oc != null && oc.isAfter(e.agora)) {
      throw AppErro('SLOT_OCUPADO',
          'A ${r.maquinaNome} está marcada como ocupada (uso não registrado) até ${hora(oc)}. Troque de máquina.');
    }
  }

  /// Faz o check-in: liga o cronômetro e estende o horário se preciso (RN-27).
  void aplicarCheckin(Reserva r, int duracaoMin, String? programa,
      OrigemAcao origem, String nomeQuem,
      {bool tolerante = false, String? linhaExtra}) {
    final agora = e.agora;
    var termina = agora.add(Duration(minutes: duracaoMin));
    final novoFim = _fimParaCronometro(r, termina, tolerante: tolerante);
    if (tolerante && termina.isAfter(novoFim)) termina = novoFim;
    final dur = termina.difference(agora).inMinutes;
    e.salvarReserva(r.copyWith(
      status: StatusReserva.emUso,
      checkinEm: agora,
      fim: novoFim,
      cronometro: Cronometro(
        programa: programa,
        duracaoMin: dur,
        iniciadoEm: agora,
        terminaEm: termina,
      ),
      historico: [
        ...r.historico,
        if (linhaExtra != null) e.linha(linhaExtra),
        e.linha('Uso confirmado por $nomeQuem ${_origemTexto(origem)}'),
        e.linha(
            'Cronômetro ligado: ${minutosLegivel(dur)}${programa != null ? ' ($programa)' : ''}, pronta às ${hora(termina)}'),
        if (novoFim.isAfter(r.fim))
          e.linha('Horário estendido até ${hora(novoFim)}'),
      ],
    ));
    e.aguardando.remove(r.maquinaId);
  }

  void _validarDuracao(int min) {
    if (min < 1 || min > 240) {
      throw const AppErro('NAO_PERMITIDO',
          'Informe um tempo entre 1 e 240 minutos.');
    }
  }

  /// RN-27 + RN-05: devolve o novo fim do horário para caber o cronômetro.
  DateTime _fimParaCronometro(Reserva r, DateTime termina,
      {bool tolerante = false}) {
    if (!termina.isAfter(r.fim)) return r.fim;
    final slotMin = e.config.slotMin;
    final precisa =
        (termina.difference(r.inicio).inMinutes / slotMin).ceil();
    if (precisa > 2) {
      if (tolerante) return r.fim;
      throw AppErro('CRONOMETRO_EXCEDE',
          'Esse programa termina ${hora(termina)}, depois do limite de 2 horários seguidos da ${r.maquinaNome}. Escolha um programa mais curto.');
    }
    final novoFim = r.inicio.add(Duration(minutes: precisa * slotMin));
    final base = e.maquinaBase(r.maquinaId);
    for (var s = r.fim; s.isBefore(novoFim); s = s.add(e.slot)) {
      final fimS = s.add(e.slot);
      final oc = e.ocupante(r.maquinaId, s, fimS, exceto: r.id);
      final bloqueio = e.indisponivelNoPeriodo(base, s, fimS);
      final fechada = e.fechamentoNoPeriodo(s, fimS);
      if (oc != null || bloqueio || fechada != null) {
        if (tolerante) return r.fim;
        final quando = oc != null ? oc.inicio : s;
        final motivo = oc != null
            ? 'está reservada'
            : fechada != null
                ? 'estará fechada'
                : 'ficará indisponível';
        throw AppErro('CRONOMETRO_EXCEDE',
            'Esse programa termina ${hora(termina)}, mas a ${r.maquinaNome} $motivo a partir de ${hora(quando)}. Escolha um programa mais curto ou outra máquina.');
      }
    }
    return novoFim;
  }

  // ------------------------------------------------------ Ajustar cronômetro

  void ajustarCronometro(String reservaId, int deltaMin) {
    final r = e.reserva(reservaId);
    final c = r.cronometro;
    if (r.status != StatusReserva.emUso || c == null) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não tem um cronômetro em andamento.');
    }
    final agora = e.agora;
    var termina = c.terminaEm.add(Duration(minutes: deltaMin));
    if (!termina.isAfter(agora)) {
      termina = agora.add(const Duration(minutes: 1));
    }
    final novoFim = _fimParaCronometro(r, termina);
    e.salvarReserva(r.copyWith(
      fim: novoFim,
      cronometro: c.copyWith(
        terminaEm: termina,
        duracaoMin: termina.difference(c.iniciadoEm).inMinutes,
      ),
      historico: [
        ...r.historico,
        e.linha(
            'Cronômetro ajustado ${deltaMin >= 0 ? '+' : ''}$deltaMin min: pronta às ${hora(termina)}'),
        if (novoFim.isAfter(r.fim))
          e.linha('Horário estendido até ${hora(novoFim)}'),
      ],
    ));
    // Se ainda não terminou, os avisos do cronômetro valem de novo.
    e.flags
      ..remove('cron5:$reservaId')
      ..remove('pronta:$reservaId')
      ..remove('prazo:$reservaId');
    final ag = e.aguardando[r.maquinaId];
    if (ag != null && ag.reservaId == reservaId) {
      e.aguardando.remove(r.maquinaId);
    }
  }

  // --------------------------------------------------------------- Finalizar

  void finalizar(String reservaId, Morador quem) {
    final r = e.reserva(reservaId);
    _exigirDono(r, quem);
    final ag = e.aguardando[r.maquinaId];
    final esperando = ag != null && ag.reservaId == r.id;
    if (r.status != StatusReserva.emUso && !esperando) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não está em uso.');
    }
    final agora = e.agora;
    e.salvarReserva(r.copyWith(
      status: r.status == StatusReserva.emUso ? StatusReserva.concluida : r.status,
      finalizadaEm: agora,
      historico: [
        ...r.historico,
        e.linha('Uso finalizado por ${quem.nome}: roupa retirada'),
      ],
    ));
    if (esperando) e.aguardando.remove(r.maquinaId);
  }

  // ---------------------------------------------------------------- Cancelar

  void cancelar(String reservaId, Morador quem) {
    final r = e.reserva(reservaId);
    _exigirDono(r, quem);
    final agora = e.agora;
    if (!r.podeCancelar(agora)) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não pode mais ser cancelada.');
    }
    final tardio = r.cancelamentoTardio(agora);
    e.salvarReserva(r.copyWith(
      status: StatusReserva.cancelada,
      motivoCancelamento: 'Cancelada pelo apartamento',
      historico: [
        ...r.historico,
        e.linha(
            'Cancelada por ${quem.nome}${tardio ? ' (cancelamento tardio, menos de 30 min do início)' : ''}'),
      ],
    ));
  }

  // ----------------------------------------------------------- Trocar máquina

  Reserva trocarMaquina({
    required String reservaId,
    required String novaMaquinaId,
    required Morador quem,
  }) {
    final r = e.reserva(reservaId);
    _exigirDono(r, quem);
    exigirAptoAtivo(quem, OrigemAcao.app);
    if (r.status != StatusReserva.agendada &&
        r.status != StatusReserva.precisaAcao) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não pode mais ser alterada.');
    }
    final nova = e.maquinaBase(novaMaquinaId);
    if (nova.tipo != r.tipo) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Escolha uma máquina do mesmo tipo.');
    }
    if (e.indisponivelNoPeriodo(nova, r.inicio, r.fim)) {
      throw _erroIndisponivel(nova);
    }
    if (e.ocupante(nova.id, r.inicio, r.fim, exceto: r.id) != null) {
      throw const AppErro('SLOT_OCUPADO',
          'Alguém acabou de reservar esse horário. Escolha outro.');
    }
    final nr = r.copyWith(
      maquinaId: nova.id,
      maquinaNome: nova.nome,
      status: StatusReserva.agendada,
      mensagemAcao: null,
      historico: [
        ...r.historico,
        e.linha('${quem.nome} trocou de ${r.maquinaNome} para ${nova.nome}'),
      ],
    );
    e.salvarReserva(nr);
    return nr;
  }

  // ------------------------------------------------- Utilitário para outras regras

  /// Reservas futuras/agendadas da máquina, em ordem.
  List<Reserva> agendadasDa(String maquinaId) => e.reservas.values
      .where((r) =>
          r.maquinaId == maquinaId && r.status == StatusReserva.agendada)
      .sortedBy<DateTime>((r) => r.inicio);
}
