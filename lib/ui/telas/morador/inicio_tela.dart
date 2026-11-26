import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../estado.dart';
import '../../fluxos/fluxos.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/maquina_widgets.dart';
import '../../widgets/reserva_widgets.dart';
import '../../widgets/roupa_widgets.dart';

class InicioTela extends ConsumerWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(sessaoProvider).morador;
    if (m == null) return const SizedBox();
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final maquinas = ref.watch(maquinasProvider).value ?? const <Maquina>[];
    final reservas = ref.watch(reservasDoAptoProvider(m.aptoId)).value ?? const <Reserva>[];
    final avisos = ref.watch(avisosProvider(m.aptoId)).value ?? const <Aviso>[];
    final fechamento = ref.watch(fechamentoProvider).value;
    final ativo = ref.watch(aptoAtivoProvider);
    final roupas = ref.watch(roupasRetiradasProvider).value ?? const <RoupaRetirada>[];
    final noticias = ref.watch(noticiasProvider).value ?? const <Noticia>[];
    final minhasRoupas = roupas.where((r) => r.donoApto == m.aptoId && r.recolhidaEm == null).toList();
    final urgente = noticias.where((n) => n.prioridade == PrioridadeNoticia.urgente && !n.lida).firstOrNull;
    final foco = reservaEmFoco(reservas, agora);
    final outrasPrecisam = reservas.where((r) => r.status == StatusReserva.precisaAcao && r.id != foco?.id).toList();
    final largura = MediaQuery.sizeOf(context).width;
    final largo = largura >= Medidas.breakDesktop;
    final naoLidos = avisos.where((a) => !a.lido).length;

    final alertas = <Widget>[
      if (fechamento != null)
        FaixaAlerta(cor: Cores.indisponivel, icone: Icons.lock_rounded, titulo: 'Lavanderia fechada', texto: '${fechamento.motivo}${fechamento.fim == null ? '' : ' · reabre ${Fmt.dia(fechamento.fim!, agora).toLowerCase()} às ${Fmt.hora(fechamento.fim!)}'}'),
      if (!ativo)
        const FaixaAlerta(cor: Cores.problema, icone: Icons.block_rounded, titulo: 'A lavanderia não está ativa para o seu apartamento', texto: 'Você pode consultar o painel, as notícias e os tutoriais. Fale com o síndico.'),
      for (final r in outrasPrecisam)
        FaixaAlerta(cor: Cores.problema, icone: Icons.priority_high_rounded, titulo: 'Reserva das ${Fmt.hora(r.inicio)} precisa de ação', texto: r.mensagemAcao, onTap: () => context.go('/m/reserva/${r.id}')),
      for (final r in minhasRoupas)
        FaixaAlerta(cor: Cores.semRegistro, icone: Icons.inventory_2_rounded, titulo: 'Suas roupas foram retiradas da ${r.maquinaNome}', texto: 'Estão em: ${r.localTexto} · desde ${Fmt.hora(r.desde)}', acao: 'Ver', onTap: () => context.go('/m/roupas')),
      if (urgente != null)
        FaixaAlerta(cor: Cores.reservada, icone: Icons.campaign_rounded, titulo: urgente.titulo, texto: urgente.resumo, onTap: () => context.go('/m/noticia/${urgente.id}')),
    ];

    final colunaPrincipal = <Widget>[
      if (foco != null) ...[
        CartaoReservaFoco(reserva: foco, agora: agora, grande: largo, onDetalhes: () => context.go('/m/reserva/${foco.id}')),
        const SizedBox(height: 22),
      ] else if (ativo) ...[
        _SemReserva(onReservar: () => context.go('/m/reservar')),
        const SizedBox(height: 22),
      ],
      Row(children: [
        Text('Máquinas agora', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 10),
        const _PontoAoVivo(),
      ]),
      const SizedBox(height: 4),
      const LegendaStatus(),
      const SizedBox(height: 10),
      SecaoMaquinas(tipo: TipoMaquina.lavadora, maquinas: maquinas, agora: agora, onTap: (x) => context.go('/m/maquina/${x.id}')),
      const SizedBox(height: 18),
      SecaoMaquinas(tipo: TipoMaquina.secadora, maquinas: maquinas, agora: agora, onTap: (x) => context.go('/m/maquina/${x.id}')),
    ];

    final colunaLateral = <Widget>[
      _ProximosLivres(agora: agora),
      const SizedBox(height: 18),
      const ListaRoupasRetiradas(rotaVerTodas: '/m/roupas'),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirRelatar(context),
        icon: const Icon(Icons.report_gmailerrorred_rounded),
        label: const Text('Relatar', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Cores.problema,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(largura >= Medidas.breakTablet ? 32 : 16, 18, largura >= Medidas.breakTablet ? 32 : 16, 110),
          children: [
            ConteudoLimitado(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Olá, ${m.nome}', style: Theme.of(context).textTheme.headlineMedium),
                      Text('Ap ${m.aptoId} · ${Fmt.dataLonga(agora)} · ${Fmt.hora(agora)}', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Avisos',
                    onPressed: () => context.go('/m/avisos'),
                    icon: Contador(naoLidos, child: const Icon(Icons.notifications_rounded)),
                  ),
                ]),
                const SizedBox(height: 18),
                for (final a in alertas) Padding(padding: const EdgeInsets.only(bottom: 10), child: a),
                if (alertas.isNotEmpty) const SizedBox(height: 8),
                if (largo)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: colunaPrincipal)),
                    const SizedBox(width: 28),
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: colunaLateral)),
                  ])
                else ...[
                  ...colunaPrincipal,
                  const SizedBox(height: 22),
                  ...colunaLateral,
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemReserva extends StatelessWidget {
  const _SemReserva({required this.onReservar});
  final VoidCallback onReservar;
  @override
  Widget build(BuildContext context) => CartaoBase(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Cores.fundoDe(Cores.marca), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.event_available_rounded, color: Cores.marca, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nenhuma reserva por enquanto', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Toque numa máquina livre para usar agora ou reserve um horário.', style: TextStyle(color: Cores.textoSuave)),
            ]),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: onReservar, child: const Text('Reservar')),
        ]),
      );
}

class _PontoAoVivo extends StatefulWidget {
  const _PontoAoVivo();
  @override
  State<_PontoAoVivo> createState() => _PontoAoVivoState();
}

class _PontoAoVivoState extends State<_PontoAoVivo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        FadeTransition(
          opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
          child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Cores.livre, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
        const Text('ao vivo', style: TextStyle(color: Cores.livre, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ]);
}

class _ProximosLivres extends ConsumerWidget {
  const _ProximosLivres({required this.agora});
  final DateTime agora;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    Widget linha(TipoMaquina tipo) {
      final grade = ref.watch(gradeProvider((hoje, tipo))).value ?? const <SlotGrade>[];
      final livres = grade.where((s) => !s.passado && !s.fechado && s.livres > 0 && s.inicio.isAfter(agora)).take(4).toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(iconeTipo(tipo), color: Cores.marca, size: 20),
          const SizedBox(width: 8),
          SizedBox(width: 52, child: Text(verboTipo(tipo), style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(
            child: livres.isEmpty
                ? const Text('Sem horários hoje', style: TextStyle(color: Cores.textoSuave))
                : Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final s in livres)
                      ActionChip(
                        label: Text(Fmt.hora(s.inicio)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context.go('/m/reservar?tipo=${tipo.name}'),
                      ),
                  ]),
          ),
        ]),
      );
    }

    return CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Próximos horários livres', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        linha(TipoMaquina.lavadora),
        linha(TipoMaquina.secadora),
      ]),
    );
  }
}
