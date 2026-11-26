import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class ReservaTela extends ConsumerWidget {
  const ReservaTela({super.key, required this.reservaId});
  final String reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextoAcaoProvider);
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final r = ctx == null ? null : (ref.watch(reservasDoAptoProvider(ctx.aptoId)).value ?? const <Reserva>[]).where((x) => x.id == reservaId).firstOrNull;
    if (r == null) {
      return const PaginaMorador(titulo: 'Reserva', voltar: true, filhos: [EstadoVazio(icone: Icons.search_off_rounded, titulo: 'Reserva não encontrada')]);
    }
    return PaginaMorador(titulo: r.maquinaNome, subtitulo: Fmt.intervalo(r.inicio, r.fim, agora), voltar: true, filhos: [DetalheReserva(reserva: r, agora: agora, ctx: ctx!)]);
  }
}

class DetalheReserva extends ConsumerWidget {
  const DetalheReserva({super.key, required this.reserva, required this.agora, required this.ctx});
  final Reserva reserva;
  final DateTime agora;
  final ContextoAcao ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reserva;
    final (txt, cor, ic) = visualReserva(r.status);
    final largo = MediaQuery.sizeOf(context).width >= Medidas.breakDesktop;
    final ativa = r.status == StatusReserva.agendada || r.status == StatusReserva.emUso || r.status == StatusReserva.precisaAcao;

    final principal = <Widget>[
      if (ativa) CartaoReservaFoco(reserva: r, agora: agora, grande: largo),
      if (!ativa)
        CartaoBase(
          child: Row(children: [
            IconeMaquina(r.tipo, cor: cor, tamanho: 52),
            const SizedBox(width: 14),
            Expanded(child: Text(r.maquinaNome, style: Theme.of(context).textTheme.titleLarge)),
            Selo(cor: cor, icone: ic, texto: txt, forte: true),
          ]),
        ),
      const SizedBox(height: 16),
      if (r.status == StatusReserva.agendada) ...[
        // Empilhados: no celular, lado a lado o texto era cortado.
        BotaoAcao(rotulo: 'Trocar de máquina', icone: Icons.swap_horiz_rounded, estilo: EstiloBotao.contorno, onPressed: () async => fluxoTrocar(context, ref, r, ctx)),
        const SizedBox(height: 10),
        BotaoAcao(rotulo: 'Cancelar reserva', icone: Icons.close_rounded, estilo: EstiloBotao.contorno, cor: Cores.problema, onPressed: () async {
          if (await fluxoCancelar(context, ref, r, ctx) && context.mounted) Navigator.of(context).maybePop();
        }),
        if (r.inicio.difference(agora).inMinutes < 30 && r.inicio.isAfter(agora))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Cancelar a menos de 30 min do início conta como cancelamento tardio (só entra nas estatísticas).', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
          ),
      ],
      if (r.status == StatusReserva.emUso) ...[
        BotaoAcao(
          rotulo: 'Minha roupa foi retirada',
          icone: Icons.inventory_2_rounded,
          estilo: EstiloBotao.contorno,
          cor: Cores.semRegistro,
          onPressed: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MinhaRoupaRetiradaPagina(maquinaId: r.maquinaId))),
        ),
        const SizedBox(height: 10),
      ],
      if (ativa)
        BotaoAcao(
          rotulo: 'Relatar problema na ${r.maquinaNome}',
          icone: Icons.build_circle_outlined,
          estilo: EstiloBotao.texto,
          onPressed: () async => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RelatarMaquinaPagina(maquinaId: r.maquinaId))),
        ),
    ];

    final detalhes = CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Detalhes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LinhaInfo(iconeTipo(r.tipo), '${nomeTipo(r.tipo)} · ${r.maquinaNome}'),
        LinhaInfo(Icons.schedule_rounded, Fmt.intervalo(r.inicio, r.fim, agora)),
        if (r.comboId != null)
          for (final par in (ref.watch(reservasDoAptoProvider(r.aptoId)).value ?? const <Reserva>[]).where((x) => x.comboId == r.comboId && x.id != r.id))
            LinhaInfo(Icons.auto_awesome_rounded, 'Combo: ${par.tipo == TipoMaquina.secadora ? 'secar' : 'lavar'} na ${par.maquinaNome} às ${Fmt.hora(par.inicio)}', cor: const Color(0xFF00838F)),
        LinhaInfo(Icons.person_rounded, 'Reservada por ${r.criadaPorNome} (Ap ${r.aptoId}) ${nomeOrigem(r.origem)}'),
        if (r.checkinEm != null) LinhaInfo(Icons.play_circle_outline_rounded, 'Uso confirmado às ${Fmt.hora(r.checkinEm!)}'),
        if (r.cronometro != null) LinhaInfo(Icons.timer_outlined, '${r.cronometro!.programa ?? 'Programa'} · ${Fmt.minutos(r.cronometro!.duracaoMin)} · pronta às ${Fmt.hora(r.cronometro!.terminaEm)}'),
        if (r.motivoCancelamento != null) LinhaInfo(Icons.info_outline_rounded, r.motivoCancelamento!, cor: Cores.problema),
        if (r.historico.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Linha do tempo', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final (i, h) in r.historico.indexed)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: i == r.historico.length - 1 ? Cores.marca : Cores.borda, shape: BoxShape.circle)),
                if (i < r.historico.length - 1) Container(width: 2, height: 22, color: Cores.borda),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(h, style: const TextStyle(fontSize: 13.5)))),
            ]),
        ],
      ]),
    );

    if (largo) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: principal)),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: detalhes),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...principal, const SizedBox(height: 16), detalhes]);
  }
}
