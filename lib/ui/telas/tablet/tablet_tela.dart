import 'dart:async';

import 'package:collection/collection.dart';
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
import '../../widgets/logo.dart';
import '../../widgets/maquina_widgets.dart';
import '../../widgets/reserva_widgets.dart';
import '../../widgets/roupa_widgets.dart';
import '../morador/conteudo_telas.dart';
import '../morador/maquina_tela.dart';
import '../morador/reservar_tela.dart';
import 'identificacao_tablet.dart';

const _timeout = Duration(seconds: 60);

/// Modo quiosque (seção 7): painel ao vivo + ações em nome de quem se identificar.
class TabletTela extends ConsumerStatefulWidget {
  const TabletTela({super.key});
  @override
  ConsumerState<TabletTela> createState() => _TabletTelaState();
}

class _TabletTelaState extends ConsumerState<TabletTela> {
  final _nav = GlobalKey<NavigatorState>();
  Timer? _timer;
  DateTime _ultimoToque = DateTime.now();
  int _restante = _timeout.inSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _verificar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toque() => _ultimoToque = DateTime.now();

  void _verificar() {
    if (ref.read(sessaoProvider).moradorTablet == null) return;
    final r = _timeout.inSeconds - DateTime.now().difference(_ultimoToque).inSeconds;
    if (r <= 0) {
      _encerrar(motivo: 'Sessão encerrada por inatividade.');
    } else if (r != _restante) {
      setState(() => _restante = r);
    }
  }

  void _encerrar({String? motivo}) {
    ref.read(sessaoProvider.notifier).encerrarTablet();
    _nav.currentState?.popUntil((r) => r.isFirst);
    setState(() => _restante = _timeout.inSeconds);
    if (motivo != null && mounted) mostrarSucesso(_nav.currentContext ?? context, motivo);
  }

  /// Garante identificação antes de uma ação; devolve o contexto ou null.
  Future<ContextoAcao?> _identificar() async {
    final atual = ref.read(contextoAcaoProvider);
    if (atual != null) return atual;
    final ctxNav = _nav.currentContext!;
    final m = await mostrarIdentificacaoTablet(ctxNav);
    if (m == null) return null;
    ref.read(sessaoProvider.notifier).identificarNoTablet(m);
    _toque();
    setState(() => _restante = _timeout.inSeconds);
    return ref.read(contextoAcaoProvider);
  }

  void _aposAcao(bool ok) {
    if (!ok || !mounted) return;
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && ref.read(sessaoProvider).moradorTablet != null && DateTime.now().difference(_ultimoToque).inSeconds >= 5) {
        _encerrar(motivo: 'Pronto! Sessão encerrada.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider);
    final quem = sessao.moradorTablet;
    return Listener(
      onPointerDown: (_) => _toque(),
      child: Scaffold(
        backgroundColor: Cores.fundo,
        body: SafeArea(
          child: Column(children: [
            _BarraTopo(onSairModo: () {
              ref.read(sessaoProvider.notifier).sair();
              context.go('/entrar');
            }),
            if (quem != null) _BarraSessao(morador: quem, restante: _restante, onTrocar: () async {
              _encerrar();
              await _identificar();
            }, onSair: () => _encerrar()),
            Expanded(
              child: Navigator(
                key: _nav,
                onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _PainelTablet(identificar: _identificar, aposAcao: _aposAcao)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BarraTopo extends ConsumerWidget {
  const _BarraTopo({required this.onSairModo});
  final VoidCallback onSairModo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final fech = ref.watch(fechamentoProvider).value;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Cores.borda))),
      child: Row(children: [
        const LogoLavanderon(altura: 26),
        const SizedBox(width: 18),
        Selo(cor: fech == null ? Cores.livre : Cores.indisponivel, forte: true, icone: fech == null ? Icons.lock_open_rounded : Icons.lock_rounded, texto: fech == null ? 'ABERTA 24 h' : 'FECHADA'),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Fmt.hora(agora), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
          Text(Fmt.dataLonga(agora), style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
        const SizedBox(width: 8),
        PopupMenuButton<int>(
          tooltip: 'Opções do tablet',
          icon: const Icon(Icons.more_vert_rounded),
          itemBuilder: (_) => const [PopupMenuItem(value: 1, child: Text('Sair do modo tablet (síndico)'))],
          onSelected: (_) => onSairModo(),
        ),
      ]),
    );
  }
}

class _BarraSessao extends StatelessWidget {
  const _BarraSessao({required this.morador, required this.restante, required this.onTrocar, required this.onSair});
  final Morador morador;
  final int restante;
  final VoidCallback onTrocar, onSair;
  @override
  Widget build(BuildContext context) {
    final alerta = restante <= 10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: alerta ? Cores.reservada : Cores.marca,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(children: [
        const Icon(Icons.person_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Text(alerta ? 'Ainda está aí? Saindo em $restante s' : 'Usando como: ${morador.nome} · Ap ${morador.aptoId}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(value: restante / _timeout.inSeconds, strokeWidth: 3, color: Colors.white, backgroundColor: Colors.white24),
        ),
        const SizedBox(width: 14),
        TextButton.icon(onPressed: onTrocar, style: TextButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.swap_horiz_rounded), label: Text(alerta ? 'Continuar' : 'Trocar pessoa')),
        const SizedBox(width: 6),
        FilledButton.icon(onPressed: onSair, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Cores.marca, minimumSize: const Size(0, 42)), icon: const Icon(Icons.logout_rounded), label: const Text('Sair')),
      ]),
    );
  }
}

class _PainelTablet extends ConsumerWidget {
  const _PainelTablet({required this.identificar, required this.aposAcao});
  final Future<ContextoAcao?> Function() identificar;
  final void Function(bool) aposAcao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final maquinas = ref.watch(maquinasProvider).value ?? const <Maquina>[];
    final noticias = ref.watch(noticiasProvider).value ?? const <Noticia>[];
    final fech = ref.watch(fechamentoProvider).value;
    final destaque = noticias.where((n) => n.fixada || n.prioridade == PrioridadeNoticia.urgente).firstOrNull;
    final largo = MediaQuery.sizeOf(context).width >= 1000;

    Future<void> acao(Future<bool> Function(ContextoAcao) f) async {
      final ctx = await identificar();
      if (ctx == null || !context.mounted) return;
      aposAcao(await f(ctx));
    }

    Future<void> abrirMaquina(Maquina m) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PaginaTablet(
          titulo: m.nome,
          child: Consumer(builder: (c, ref, _) {
            final mm = (ref.watch(maquinasProvider).value ?? const <Maquina>[]).firstWhereOrNull((x) => x.id == m.id) ?? m;
            final ctx = ref.watch(contextoAcaoProvider);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (ctx == null) ...[
                FilledButton.icon(onPressed: identificar, icon: const Icon(Icons.person_search_rounded), label: const Text('Identificar-se para usar ou relatar')),
                const SizedBox(height: 14),
              ],
              PainelMaquina(maquina: mm, agora: ref.watch(agoraProvider).value ?? agora),
            ]);
          }),
        )));

    final painel = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (fech != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: FaixaAlerta(cor: Cores.indisponivel, icone: Icons.lock_rounded, titulo: 'Lavanderia fechada', texto: fech.motivo)),
      SecaoMaquinas(tipo: TipoMaquina.lavadora, maquinas: maquinas, agora: agora, grande: true, onTap: abrirMaquina),
      const SizedBox(height: 16),
      SecaoMaquinas(tipo: TipoMaquina.secadora, maquinas: maquinas, agora: agora, grande: true, onTap: abrirMaquina),
    ]);

    final lateral = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ProximasHoras(agora: agora),
      const SizedBox(height: 14),
      ListaRoupasRetiradas(limite: 4, obterContexto: identificar),
      if (destaque != null) ...[
        const SizedBox(height: 14),
        FaixaAlerta(cor: Cores.reservada, icone: Icons.campaign_rounded, titulo: destaque.titulo, texto: destaque.resumo),
      ],
    ]);

    final botoes = [
      _BotaoTablet(Icons.play_circle_fill_rounded, 'Usar máquina agora', Cores.livre, () => acao((ctx) async {
            final m = await _escolherLivre(context, ref);
            if (m == null || !context.mounted) return false;
            return fluxoUsarAgora(context, ref, m, ctx);
          })),
      _BotaoTablet(Icons.task_alt_rounded, 'Confirmar minha reserva', Cores.marca, () => acao((ctx) => _confirmarMinha(context, ref, ctx))),
      _BotaoTablet(Icons.calendar_month_rounded, 'Reservar', Cores.reservada, () => acao((ctx) async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (c) => _PaginaTablet(titulo: 'Reservar', child: GradeReserva(grande: true, aoReservar: (_) => Navigator.of(c).pop()))));
            return true;
          })),
      _BotaoTablet(Icons.checkroom_rounded, 'Roupa na máquina', Cores.pronta, () => acao((ctx) async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoupaNaMaquinaPagina()));
            return true;
          })),
      _BotaoTablet(Icons.report_rounded, 'Relatar problema', Cores.problema, () => acao((ctx) async {
            await abrirRelatar(context);
            return false;
          })),
      _BotaoTablet(Icons.menu_book_rounded, 'Tutoriais e notícias', Cores.agua, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ConteudoTablet()))),
    ];

    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(22), children: [
          if (largo)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: painel), const SizedBox(width: 22), Expanded(flex: 3, child: lateral)])
          else ...[painel, const SizedBox(height: 18), lateral],
        ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Cores.borda))),
        child: LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 1000 ? 6 : 3;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final b in botoes) SizedBox(width: w, child: b)]);
        }),
      ),
    ]);
  }

  Future<Maquina?> _escolherLivre(BuildContext context, WidgetRef ref) {
    final agora = ref.read(lavanderonRepositoryProvider).agoraAtual;
    final livres = (ref.read(maquinasProvider).value ?? const <Maquina>[]).where((m) => m.status == StatusMaquina.disponivel && m.situacao == SituacaoMaquina.livre).sortedBy((m) => '${m.tipo.index}${m.ordem}');
    return showDialog<Maquina>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Qual máquina você vai usar?'),
        content: SizedBox(
          width: 640,
          child: livres.isEmpty
              ? const EstadoVazio(icone: Icons.hourglass_empty_rounded, titulo: 'Nenhuma máquina livre agora')
              : GradeMaquinas(maquinas: livres, agora: agora, grande: true, onTap: (m) => Navigator.pop(c, m)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Voltar'))],
      ),
    );
  }

  Future<bool> _confirmarMinha(BuildContext context, WidgetRef ref, ContextoAcao ctx) async {
    final repo = ref.read(lavanderonRepositoryProvider);
    final agora = repo.agoraAtual;
    final lista = await repo.reservasDoApto(ctx.aptoId).first;
    final janela = lista.where((r) => r.status == StatusReserva.agendada && r.podeConfirmar(agora)).toList();
    final emUso = lista.where((r) => r.status == StatusReserva.emUso).toList();
    if (!context.mounted) return false;
    if (janela.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(emUso.isEmpty ? 'Nenhuma reserva para confirmar agora' : 'Seu uso já está confirmado'),
          content: SizedBox(
            width: 520,
            child: emUso.isEmpty
                ? const Text('Só dá para confirmar de 10 min antes até 15 min depois do início. Se a máquina estiver livre, use "Usar máquina agora".')
                : CartaoCronometro(reserva: emUso.first, agora: agora, ctx: ctx),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Ok'))],
        ),
      );
      return false;
    }
    final r = janela.length == 1
        ? janela.first
        : await showDialog<Reserva>(
            context: context,
            builder: (c) => SimpleDialog(title: const Text('Qual reserva?'), children: [
              for (final x in janela) SimpleDialogOption(onPressed: () => Navigator.pop(c, x), child: Text('${x.maquinaNome} · ${Fmt.hora(x.inicio)}')),
            ]),
          );
    if (r == null || !context.mounted) return false;
    return fluxoConfirmarUso(context, ref, r, ctx);
  }
}

class _BotaoTablet extends StatelessWidget {
  const _BotaoTablet(this.icone, this.texto, this.cor, this.onTap);
  final IconData icone;
  final String texto;
  final Color cor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Cores.fundoDe(cor),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: cor.withValues(alpha: 0.35), width: 1.5)),
            child: Row(children: [
              Icon(icone, color: cor, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(texto, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color.lerp(cor, Colors.black, 0.35)))),
            ]),
          ),
        ),
      );
}

class _ProximasHoras extends ConsumerWidget {
  const _ProximasHoras({required this.agora});
  final DateTime agora;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final reservas = (ref.watch(reservasDoDiaProvider(hoje)).value ?? const <Reserva>[])
        .where((r) => r.status == StatusReserva.agendada && r.inicio.isAfter(agora))
        .sortedBy((r) => r.inicio)
        .take(6)
        .toList();
    return CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Próximas horas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (reservas.isEmpty) const Text('Sem reservas nas próximas horas.', style: TextStyle(color: Cores.textoSuave)),
        for (final r in reservas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 54, child: Text(Fmt.hora(r.inicio), style: const TextStyle(fontWeight: FontWeight.w900))),
              Icon(iconeTipo(r.tipo), size: 18, color: Cores.reservada),
              const SizedBox(width: 6),
              Expanded(child: Text(r.maquinaNome, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('Ap ${r.aptoId}', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    );
  }
}

class _PaginaTablet extends StatelessWidget {
  const _PaginaTablet({required this.titulo, required this.child});
  final String titulo;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo), toolbarHeight: 64),
        body: ListView(padding: const EdgeInsets.all(22), children: [ConteudoLimitado(child: child)]),
      );
}

class _ConteudoTablet extends ConsumerStatefulWidget {
  const _ConteudoTablet();
  @override
  ConsumerState<_ConteudoTablet> createState() => _ConteudoTabletState();
}

class _ConteudoTabletState extends ConsumerState<_ConteudoTablet> {
  String _busca = '';
  @override
  Widget build(BuildContext context) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final noticias = ref.watch(noticiasProvider).value ?? const <Noticia>[];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tutoriais e notícias'), bottom: const TabBar(tabs: [Tab(text: 'Tutoriais'), Tab(text: 'Notícias')])),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(22), children: [
            ListaTutoriais(
              busca: _busca,
              onBusca: (v) => setState(() => _busca = v),
              onAbrir: (t) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PaginaTablet(titulo: 'Tutorial', child: DetalheTutorial(tutorial: t)))),
            ),
          ]),
          ListView(padding: const EdgeInsets.all(22), children: [
            for (final n in noticias)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CartaoNoticia(
                  noticia: n,
                  agora: agora,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PaginaTablet(titulo: n.titulo, child: CartaoBase(padding: const EdgeInsets.all(24), child: CorpoTexto(n.corpo))))),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
