import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio.dart';
import '../estado.dart';
import '../fluxos/fluxos.dart';
import '../tema/tema.dart';
import '../util/fmt.dart';
import 'base.dart';
import 'maquina_widgets.dart';

(String, Color, IconData) visualReserva(StatusReserva s) => switch (s) {
      StatusReserva.agendada => ('Agendada', Cores.reservada, Icons.schedule_rounded),
      StatusReserva.emUso => ('Em uso', Cores.emUso, Icons.autorenew_rounded),
      StatusReserva.concluida => ('Concluída', Cores.livre, Icons.check_circle_rounded),
      StatusReserva.cancelada => ('Cancelada', Cores.indisponivel, Icons.cancel_rounded),
      StatusReserva.naoCompareceu => ('Não compareceu', Cores.problema, Icons.person_off_rounded),
      StatusReserva.precisaAcao => ('Precisa de ação', Cores.problema, Icons.priority_high_rounded),
      StatusReserva.interrompida => ('Interrompida', Cores.semRegistro, Icons.pause_circle_rounded),
    };

String nomeOrigem(OrigemAcao o) => switch (o) {
      OrigemAcao.app => 'pelo app',
      OrigemAcao.tablet => 'pelo tablet',
      OrigemAcao.sindico => 'pelo síndico',
    };

/// Reserva "ativa" do apartamento: em uso primeiro; senão a próxima agendada/precisa de ação.
Reserva? reservaEmFoco(List<Reserva> lista, DateTime agora) {
  final emUso = lista.where((r) => r.status == StatusReserva.emUso).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
  if (emUso.isNotEmpty) return emUso.first;
  final proximas = lista.where((r) => (r.status == StatusReserva.agendada || r.status == StatusReserva.precisaAcao) && r.fim.isAfter(agora)).toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
  return proximas.firstOrNull;
}

/// Cartão principal: cronômetro durante o uso, ou próxima reserva com "Confirmar uso".
class CartaoReservaFoco extends ConsumerWidget {
  const CartaoReservaFoco({super.key, required this.reserva, required this.agora, this.onDetalhes, this.grande = false});
  final Reserva reserva;
  final DateTime agora;
  final VoidCallback? onDetalhes;
  final bool grande;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextoAcaoProvider);
    if (reserva.status == StatusReserva.emUso) return CartaoCronometro(reserva: reserva, agora: agora, ctx: ctx, onDetalhes: onDetalhes, grande: grande);
    if (reserva.status == StatusReserva.precisaAcao) return _CartaoPrecisaAcao(reserva: reserva, ctx: ctx, agora: agora);
    return _CartaoProxima(reserva: reserva, agora: agora, ctx: ctx, onDetalhes: onDetalhes);
  }
}

class CartaoCronometro extends ConsumerWidget {
  const CartaoCronometro({super.key, required this.reserva, required this.agora, required this.ctx, this.onDetalhes, this.grande = false});
  final Reserva reserva;
  final DateTime agora;
  final ContextoAcao? ctx;
  final VoidCallback? onDetalhes;
  final bool grande;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cr = reserva.cronometro;
    final restante = cr?.terminaEm.difference(agora);
    final pronta = restante != null && restante.inSeconds <= 0;
    final cor = pronta ? Cores.pronta : Cores.emUso;
    final total = cr == null ? const Duration(minutes: 45) : Duration(minutes: cr.duracaoMin);
    final prazoMin = ref.watch(configProvider).value?.prazoRetiradaMin ?? 10;
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pronta ? const [Color(0xFF00838F), Color(0xFF00A3A3)] : const [Color(0xFF0D47A1), Color(0xFF1E6FD9)],
        ),
        borderRadius: BorderRadius.circular(Medidas.raio + 4),
        boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      padding: EdgeInsets.all(grande ? 26 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(pronta ? Icons.notifications_active_rounded : Icons.timer_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pronta ? 'Sua roupa está pronta!' : 'Em uso · ${reserva.maquinaNome}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          if (onDetalhes != null)
            IconButton(onPressed: onDetalhes, icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20), tooltip: 'Detalhes'),
        ]),
        const SizedBox(height: 10),
        if (cr != null && !pronta) ...[
          Text(Fmt.cronometro(restante!), style: t.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()], height: 1)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (1 - restante.inSeconds / total.inSeconds).clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text('${cr.programa == null ? '' : '${cr.programa} · '}pronta às ${Fmt.hora(cr.terminaEm)}',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        ] else if (pronta) ...[
          Text('Retire da ${reserva.maquinaNome}', style: t.headlineSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Pronta desde ${Fmt.hora(cr!.terminaEm)}. A partir das ${Fmt.hora(cr.terminaEm.add(Duration(minutes: prazoMin)))}, outro morador pode retirá-la e deixá-la no balcão.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ] else
          const Text('Uso confirmado.', style: TextStyle(color: Colors.white70)),
        if (ctx != null) ...[
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (!pronta && cr != null)
              _BotaoClaro(
                icone: Icons.add_rounded,
                texto: '+5 min',
                onTap: () async {
                  try {
                    await ref.read(lavanderonRepositoryProvider).ajustarCronometro(reserva.id, 5);
                  } catch (e) {
                    if (context.mounted) mostrarErro(context, e);
                  }
                },
              ),
            _BotaoClaro(icone: Icons.check_rounded, texto: 'Já retirei', forte: true, onTap: () => fluxoFinalizar(context, ref, reserva, ctx!)),
          ]),
        ],
      ]),
    );
  }
}

class _BotaoClaro extends StatelessWidget {
  const _BotaoClaro({required this.icone, required this.texto, required this.onTap, this.forte = false});
  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  final bool forte;
  @override
  Widget build(BuildContext context) => Material(
        color: forte ? Colors.white : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icone, size: 20, color: forte ? Cores.marca : Colors.white),
              const SizedBox(width: 6),
              Text(texto, style: TextStyle(fontWeight: FontWeight.w800, color: forte ? Cores.marca : Colors.white)),
            ]),
          ),
        ),
      );
}

class _CartaoProxima extends ConsumerWidget {
  const _CartaoProxima({required this.reserva, required this.agora, required this.ctx, this.onDetalhes});
  final Reserva reserva;
  final DateTime agora;
  final ContextoAcao? ctx;
  final VoidCallback? onDetalhes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeConfirmar = reserva.podeConfirmar(agora);
    final t = Theme.of(context).textTheme;
    return CartaoBase(
      onTap: onDetalhes,
      corBorda: podeConfirmar ? Cores.marca : null,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
          Text(podeConfirmar ? 'É AGORA' : 'SUA PRÓXIMA RESERVA',
              style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: podeConfirmar ? Cores.marca : Cores.textoSuave)),
          Selo(cor: Cores.reservada, icone: Icons.schedule_rounded, texto: reserva.inicio.isAfter(agora) ? 'começa ${Fmt.relativo(reserva.inicio, agora)}' : 'começou ${Fmt.relativo(reserva.inicio, agora)}'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          IconeMaquina(reserva.tipo, tamanho: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(reserva.maquinaNome, style: t.titleLarge),
              Text(Fmt.intervalo(reserva.inicio, reserva.fim, agora), style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
              if (reserva.comboId != null)
                for (final par in (ref.watch(reservasDoAptoProvider(reserva.aptoId)).value ?? const <Reserva>[])
                    .where((x) => x.comboId == reserva.comboId && x.id != reserva.id && x.status == StatusReserva.agendada))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.dry_rounded, size: 16, color: Color(0xFF00838F)),
                      const SizedBox(width: 4),
                      Flexible(child: Text('Depois: ${par.maquinaNome} às ${Fmt.hora(par.inicio)}', style: const TextStyle(color: Color(0xFF00838F), fontWeight: FontWeight.w800, fontSize: 13))),
                    ]),
                  ),
            ]),
          ),
        ]),
        if (ctx != null && podeConfirmar) ...[
          const SizedBox(height: 16),
          BotaoAcao(rotulo: 'Confirmar uso', icone: Icons.play_circle_fill_rounded, onPressed: () async => fluxoConfirmarUso(context, ref, reserva, ctx!)),
          const SizedBox(height: 8),
          BotaoAcao(
            rotulo: 'A máquina está ocupada',
            icone: Icons.swap_horiz_rounded,
            estilo: EstiloBotao.contorno,
            onPressed: () async => fluxoMaquinaOcupada(context, ref, reserva, ctx!),
          ),
        ] else if (ctx != null) ...[
          const SizedBox(height: 14),
          _ComecarAntes(reserva: reserva, ctx: ctx!),
        ],
        if (ctx != null && onDetalhes != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onDetalhes,
            style: OutlinedButton.styleFrom(
              foregroundColor: Cores.marca,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: Cores.marca.withValues(alpha: 0.45), width: 1.5),
            ),
            icon: const Icon(Icons.edit_calendar_rounded),
            label: const Text('Editar agendamento ou relatar problema', textAlign: TextAlign.center),
          ),
        ],
      ]),
    );
  }
}

/// "Começar agora": se há máquina livre agora, não precisa esperar o horário da reserva.
class _ComecarAntes extends ConsumerWidget {
  const _ComecarAntes({required this.reserva, required this.ctx});
  final Reserva reserva;
  final ContextoAcao ctx;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maqId = ref.watch(antecipavelProvider(reserva.id)).value;
    if (maqId == null) {
      return Text('A máquina não está livre agora. Você poderá confirmar o uso a partir das ${Fmt.hora(reserva.inicio.subtract(const Duration(minutes: 10)))}.',
          style: const TextStyle(color: Cores.textoSuave, fontSize: 13.5));
    }
    final outra = maqId != reserva.maquinaId;
    final nome = (ref.watch(maquinasProvider).value ?? const <Maquina>[]).where((m) => m.id == maqId).firstOrNull?.nome ?? 'máquina';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Cores.fundoDe(Cores.livre), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.bolt_rounded, color: Cores.livre),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              outra
                  ? 'A ${reserva.maquinaNome} está ocupada, mas a $nome está livre agora. Quer começar nela sem esperar?'
                  : 'A $nome está livre agora. Não precisa esperar o horário: comece já.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      BotaoAcao(
        rotulo: outra ? 'Começar agora na $nome' : 'Começar agora',
        icone: Icons.play_circle_fill_rounded,
        cor: Cores.livre,
        onPressed: () async => fluxoConfirmarUso(context, ref, reserva, ctx, maquinaId: maqId),
      ),
    ]);
  }
}

class _CartaoPrecisaAcao extends ConsumerWidget {
  const _CartaoPrecisaAcao({required this.reserva, required this.ctx, required this.agora});
  final Reserva reserva;
  final ContextoAcao? ctx;
  final DateTime agora;
  @override
  Widget build(BuildContext context, WidgetRef ref) => CartaoBase(
        cor: Cores.fundoDe(Cores.problema),
        corBorda: Cores.problema.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.priority_high_rounded, color: Cores.problema),
            SizedBox(width: 8),
            Text('SUA RESERVA PRECISA DE AÇÃO', style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w900, color: Cores.problema)),
          ]),
          const SizedBox(height: 10),
          Text('${reserva.maquinaNome} · ${Fmt.intervalo(reserva.inicio, reserva.fim, agora)}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(reserva.mensagemAcao ?? 'A máquina teve um problema. Escolha outra máquina ou horário.', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (ctx != null) ...[
            const SizedBox(height: 14),
            BotaoAcao(rotulo: 'Escolher outra máquina', icone: Icons.swap_horiz_rounded, cor: Cores.problema, onPressed: () async => fluxoTrocar(context, ref, reserva, ctx!)),
            const SizedBox(height: 8),
            BotaoAcao(rotulo: 'Cancelar sem penalidade', estilo: EstiloBotao.texto, onPressed: () async => fluxoCancelar(context, ref, reserva, ctx!)),
          ],
        ]),
      );
}

/// Linha compacta de reserva (listas e histórico).
class LinhaReserva extends StatelessWidget {
  const LinhaReserva({super.key, required this.reserva, required this.agora, this.onTap, this.mostrarApto = false});
  final Reserva reserva;
  final DateTime agora;
  final VoidCallback? onTap;
  final bool mostrarApto;
  @override
  Widget build(BuildContext context) {
    final (txt, cor, ic) = visualReserva(reserva.status);
    return CartaoBase(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        IconeMaquina(reserva.tipo, cor: cor, tamanho: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mostrarApto ? '${reserva.maquinaNome} · Ap ${reserva.aptoId}' : reserva.maquinaNome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text('${Fmt.intervalo(reserva.inicio, reserva.fim, agora)} · ${reserva.criadaPorNome}', style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
          ]),
        ),
        Selo(cor: cor, texto: txt, icone: ic),
      ]),
    );
  }
}
