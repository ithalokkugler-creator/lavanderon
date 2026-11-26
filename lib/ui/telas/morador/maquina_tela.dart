import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../estado.dart';
import '../../fluxos/fluxos.dart';
import '../../fluxos/relatar_paginas.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/maquina_widgets.dart';
import '../../widgets/reserva_widgets.dart';
import 'shell_morador.dart';

/// Tela de uma máquina (também é o destino do QR code colado nela).
class MaquinaTela extends ConsumerWidget {
  const MaquinaTela({super.key, required this.maquinaId});
  final String maquinaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final m = (ref.watch(maquinasProvider).value ?? const <Maquina>[]).where((x) => x.id == maquinaId).firstOrNull;
    if (m == null) return const PaginaMorador(titulo: 'Máquina', voltar: true, filhos: [Center(child: CircularProgressIndicator())]);
    return PaginaMorador(titulo: m.nome, subtitulo: nomeTipo(m.tipo), voltar: true, filhos: [PainelMaquina(maquina: m, agora: agora, rotaReserva: (id) => '/m/reserva/$id')]);
  }
}

/// Conteúdo da máquina com ações contextuais. Reutilizado no tablet.
class PainelMaquina extends ConsumerWidget {
  const PainelMaquina({super.key, required this.maquina, required this.agora, this.rotaReserva, this.aoReservar});
  final Maquina maquina;
  final DateTime agora;
  final String Function(String reservaId)? rotaReserva;
  final VoidCallback? aoReservar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = maquina;
    final v = visualMaquina(m, agora);
    final ctx = ref.watch(contextoAcaoProvider);
    final ativo = ref.watch(aptoAtivoProvider);
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final reservasApto = ctx == null ? const <Reserva>[] : (ref.watch(reservasDoAptoProvider(ctx.aptoId)).value ?? const <Reserva>[]);
    final minhaAqui = reservasApto
        .where((r) => r.maquinaId == m.id && (r.status == StatusReserva.emUso || (r.status == StatusReserva.agendada && r.podeConfirmar(agora))))
        .firstOrNull;
    final grade = ref.watch(gradeProvider((hoje, m.tipo))).value ?? const <SlotGrade>[];
    final agendaHoje = [
      for (final s in grade)
        if (!s.passado || s.fim.isAfter(agora)) (s, s.maquinas.where((x) => x.maquinaId == m.id).firstOrNull),
    ];
    final livreAgora = m.status == StatusMaquina.disponivel && m.situacao == SituacaoMaquina.livre;
    final temRoupaParada = m.situacao == SituacaoMaquina.aguardandoRetirada && minhaAqui == null;
    final largo = MediaQuery.sizeOf(context).width >= Medidas.breakDesktop;

    final cabecalho = CartaoBase(
      corBorda: v.cor.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconeMaquina(m.tipo, cor: v.cor, tamanho: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Selo(cor: v.cor, icone: v.icone, texto: v.rotulo, forte: true),
              const SizedBox(height: 8),
              Text(v.detalhe, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
          if (v.restante != null && !v.restante!.isNegative)
            AnelCronometro(restante: v.restante!, total: Duration(minutes: m.cicloMin), cor: v.cor, tamanho: 64, grosso: true),
        ]),
        if (m.alerta != null) ...[const SizedBox(height: 14), FaixaAlerta(cor: Cores.reservada, icone: Icons.info_outline_rounded, titulo: 'Atenção', texto: m.alerta)],
        const SizedBox(height: 14),
        LinhaInfo(Icons.timer_outlined, 'Ciclo padrão: ${Fmt.minutos(m.cicloMin)}'),
      ]),
    );

    final acoes = <Widget>[
      if (minhaAqui != null) ...[
        CartaoReservaFoco(reserva: minhaAqui, agora: agora, onDetalhes: rotaReserva == null ? null : () => context.go(rotaReserva!(minhaAqui.id))),
        const SizedBox(height: 12),
      ],
      if (ctx != null && ativo && livreAgora && minhaAqui == null) ...[
        BotaoAcao(rotulo: 'Usar agora', icone: Icons.play_circle_fill_rounded, onPressed: () async => fluxoUsarAgora(context, ref, m, ctx)),
        const SizedBox(height: 10),
      ],
      if (ctx != null && temRoupaParada) ...[
        BotaoAcao(
          rotulo: 'Roupa de alguém na máquina',
          icone: Icons.checkroom_rounded,
          cor: Cores.pronta,
          onPressed: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoupaNaMaquinaPagina(maquinaId: m.id))),
        ),
        const SizedBox(height: 10),
      ],
      if (ctx != null && ativo && aoReservar != null) ...[
        BotaoAcao(rotulo: 'Reservar um horário', icone: Icons.calendar_month_rounded, estilo: EstiloBotao.contorno, onPressed: () async => aoReservar!()),
        const SizedBox(height: 10),
      ],
      if (ctx != null)
        BotaoAcao(
          rotulo: 'Relatar problema nesta máquina',
          icone: Icons.build_circle_outlined,
          estilo: EstiloBotao.contorno,
          cor: Cores.problema,
          onPressed: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RelatarMaquinaPagina(maquinaId: m.id))),
        ),
    ];

    final agenda = CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Agenda de hoje', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (agendaHoje.isEmpty) const Text('Sem mais horários hoje.', style: TextStyle(color: Cores.textoSuave)),
        for (final (s, sm) in agendaHoje.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 92, child: Text('${Fmt.hora(s.inicio)}–${Fmt.hora(s.fim)}', style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(
                child: sm == null || sm.motivoIndisponivel != null
                    ? Text(sm?.motivoIndisponivel ?? 'Indisponível', style: const TextStyle(color: Cores.indisponivel))
                    : sm.livre
                        ? const Text('Livre', style: TextStyle(color: Cores.livre, fontWeight: FontWeight.w800))
                        : Text('Reservado · Ap ${sm.aptoReserva ?? '—'}', style: const TextStyle(color: Cores.reservada, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
      ]),
    );

    if (largo) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cabecalho, const SizedBox(height: 16), ...acoes])),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: agenda),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cabecalho, const SizedBox(height: 16), ...acoes, const SizedBox(height: 16), agenda]);
  }
}
