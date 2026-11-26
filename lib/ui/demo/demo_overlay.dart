import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../dominio.dart';
import '../estado.dart';
import '../tema/tema.dart';
import '../util/fmt.dart';
import '../telas/morador/mais_telas.dart';

/// Camada de apresentação: painel de demonstração, moldura de celular/tablet
/// e alertas em destaque (roupa pronta, roupa retirada...). Fica acima de todas as telas.
class DemoOverlay extends ConsumerStatefulWidget {
  const DemoOverlay({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends ConsumerState<DemoOverlay> {
  StreamSubscription<Aviso>? _sub;
  final _alertas = <Aviso>[];

  @override
  void initState() {
    super.initState();
    _sub = ref.read(lavanderonRepositoryProvider).novosAvisos().listen(_novoAviso);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _novoAviso(Aviso a) {
    final s = ref.read(sessaoProvider);
    final apto = s.perfil == Perfil.tablet ? null : s.morador?.aptoId;
    final relevante = apto != null && a.aptoId == apto;
    if (!relevante || !mounted) return;
    setState(() => _alertas.insert(0, a));
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) setState(() => _alertas.remove(a));
    });
  }

  @override
  Widget build(BuildContext context) {
    final modo = ref.watch(modoTelaProvider);
    final aberto = ref.watch(painelDemoProvider);
    final mq = MediaQuery.of(context);
    final grande = mq.size.width >= 900;

    Widget app = widget.child;
    if (grande && modo != ModoTela.livre) {
      final tam = modo == ModoTela.celular ? const Size(390, 844) : const Size(1180, 820);
      final escala = ((mq.size.height - 48) / tam.height).clamp(0.5, 1.0);
      final escalaL = ((mq.size.width - (aberto ? 420 : 48)) / tam.width).clamp(0.4, 1.0);
      final e = escala < escalaL ? escala : escalaL;
      app = ColoredBox(
        color: const Color(0xFF0B1B36),
        child: Center(
          child: Transform.scale(
            scale: e,
            child: Container(
              width: tam.width + 24,
              height: tam.height + 24,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111317),
                borderRadius: BorderRadius.circular(modo == ModoTela.celular ? 52 : 34),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(modo == ModoTela.celular ? 40 : 24),
                child: MediaQuery(
                  data: mq.copyWith(size: tam, padding: modo == ModoTela.celular ? const EdgeInsets.only(top: 24) : EdgeInsets.zero),
                  child: SizedBox.fromSize(size: tam, child: widget.child),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(child: app),
        // Alertas em destaque
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: _alertas.isEmpty,
            child: Column(children: [for (final a in _alertas.take(2)) _AlertaDestaque(aviso: a, onFechar: () => setState(() => _alertas.remove(a)))]),
          ),
        ),
        if (aberto) Positioned(right: 58, bottom: 16, top: 16, child: _PainelDemo(grande: grande)),
        // Aba vertical na borda direita: não cobre botões das telas.
        Positioned(right: 0, top: 0, bottom: 0, child: Center(child: _BotaoDemo(aberto: aberto))),
      ]),
    );
  }
}

class _BotaoDemo extends ConsumerWidget {
  const _BotaoDemo({required this.aberto});
  final bool aberto;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    const raio = BorderRadius.horizontal(left: Radius.circular(16));
    return Material(
      color: aberto ? Cores.marca : const Color(0xFF14213D),
      borderRadius: raio,
      elevation: 6,
      child: InkWell(
        borderRadius: raio,
        onTap: () => ref.read(painelDemoProvider.notifier).alternar(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(aberto ? Icons.close_rounded : Icons.slideshow_rounded, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 3,
              child: Text('DEMO · ${Fmt.hora(agora)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PainelDemo extends ConsumerWidget {
  const _PainelDemo({required this.grande});
  final bool grande;

  void _ir(WidgetRef ref, Perfil p) {
    final s = ref.read(sessaoProvider.notifier);
    final router = ref.read(routerProvider);
    switch (p) {
      case Perfil.morador:
        router.go('/entrar');
      case Perfil.tablet:
        s.modoTablet();
        router.go('/tablet');
      case Perfil.sindico:
        s.entrarSindico('Roberto (síndico)');
        router.go('/sindico/painel');
    }
  }

  Future<void> _entrarComo(WidgetRef ref, String apto, String nome) async {
    final m = await ref.read(lavanderonRepositoryProvider).entrar(apto, nome);
    ref.read(sessaoProvider.notifier).entrarMorador(m);
    ref.read(routerProvider).go('/m/inicio');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(lavanderonRepositoryProvider);
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final modo = ref.watch(modoTelaProvider);
    final perfil = ref.watch(sessaoProvider).perfil;
    final t = Theme.of(context).textTheme;

    Widget secao(String s) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: Cores.textoFraco)),
        );

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Cores.borda),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          const Icon(Icons.slideshow_rounded, color: Cores.marca),
          const SizedBox(width: 8),
          Expanded(child: Text('Painel de demonstração', style: t.titleMedium)),
        ]),
        const SizedBox(height: 4),
        const Text('Só existe nesta apresentação. Os dados são fictícios e ficam no navegador.', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
        secao('Relógio simulado'),
        Text(Fmt.hora(agora), style: t.displaySmall?.copyWith(fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
        Text(Fmt.dataLonga(agora), style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (r, d) in [('+5 min', const Duration(minutes: 5)), ('+15 min', const Duration(minutes: 15)), ('+1 h', const Duration(hours: 1))])
            FilledButton.tonal(onPressed: () => repo.avancarRelogio(d), child: Text(r)),
        ]),
        const SizedBox(height: 6),
        const Text('Avance o tempo para ver o cronômetro tocar, o prazo de retirada e a liberação de quem não apareceu.', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
        secao('Ver como'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('Morador'), selected: perfil == Perfil.morador, onSelected: (_) => _ir(ref, Perfil.morador)),
          ChoiceChip(label: const Text('Tablet'), selected: perfil == Perfil.tablet, onSelected: (_) => _ir(ref, Perfil.tablet)),
          ChoiceChip(label: const Text('Síndico'), selected: perfil == Perfil.sindico, onSelected: (_) => _ir(ref, Perfil.sindico)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (a, n) in [('302', 'Maria'), ('410', 'Carlos'), ('105', 'Ana')])
            ActionChip(avatar: const Icon(Icons.person_rounded, size: 18), label: Text('$n · $a'), onPressed: () => _entrarComo(ref, a, n)),
        ]),
        if (grande) ...[
          secao('Tamanho da tela'),
          SegmentedButton<ModoTela>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ModoTela.livre, label: Text('Livre'), icon: Icon(Icons.desktop_windows_rounded)),
              ButtonSegment(value: ModoTela.celular, label: Text('Celular'), icon: Icon(Icons.smartphone_rounded)),
              ButtonSegment(value: ModoTela.tablet, label: Text('Tablet'), icon: Icon(Icons.tablet_rounded)),
            ],
            selected: {modo},
            onSelectionChanged: (s) => ref.read(modoTelaProvider.notifier).definir(s.first),
          ),
        ],
        secao('Roteiro sugerido'),
        for (final (i, passo) in const [
          'Entre como Maria (302): veja o painel ao vivo e a reserva das 19:00 na Lavadora 4.',
          'Avance +15 min e confirme o uso: escolha o programa e veja o cronômetro.',
          'Abra a Lavadora 3 (pronta há alguns minutos) e registre que retirou a roupa e deixou no balcão.',
          'Troque para o Tablet e use uma máquina sem celular.',
          'Relate um problema numa máquina com reserva e veja a realocação.',
          'Entre como Síndico: ocorrências, aviso de conduta, fechar a lavanderia e estatísticas.',
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 11, backgroundColor: Cores.fundoDe(Cores.marca), child: Text('${i + 1}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Cores.marca))),
              const SizedBox(width: 10),
              Expanded(child: Text(passo, style: const TextStyle(fontSize: 13.5))),
            ]),
          ),
        secao('Dados'),
        OutlinedButton.icon(
          onPressed: () {
            repo.restaurar();
            ref.read(sessaoProvider.notifier).sair();
            ref.read(routerProvider).go('/entrar');
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restaurar dados iniciais'),
        ),
      ]),
    );
  }
}

class _AlertaDestaque extends StatelessWidget {
  const _AlertaDestaque({required this.aviso, required this.onFechar});
  final Aviso aviso;
  final VoidCallback onFechar;
  @override
  Widget build(BuildContext context) {
    final (ic, cor) = visualAviso(aviso.categoria);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.translate(offset: Offset(0, -40 * (1 - v)), child: Opacity(opacity: v.clamp(0, 1), child: child)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cor.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: Cores.fundoDe(cor), shape: BoxShape.circle), child: Icon(ic, color: cor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(aviso.titulo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text(aviso.corpo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoSuave, fontSize: 13.5)),
            ]),
          ),
          IconButton(onPressed: onFechar, icon: const Icon(Icons.close_rounded, size: 20)),
        ]),
      ),
    );
  }
}
