import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dominio.dart';
import '../tema/tema.dart';
import '../widgets/base.dart';
import '../widgets/logo.dart';

class EntradaTela extends ConsumerStatefulWidget {
  const EntradaTela({super.key});
  @override
  ConsumerState<EntradaTela> createState() => _EntradaTelaState();
}

enum _Modo { morador, sindico, tablet }

class _EntradaTelaState extends ConsumerState<EntradaTela> {
  _Modo _modo = _Modo.morador;
  final _apto = TextEditingController();
  final _nome = TextEditingController();

  @override
  void dispose() {
    _apto.dispose();
    _nome.dispose();
    super.dispose();
  }

  Future<void> _entrarMorador() async {
    final m = await ref.read(lavanderonRepositoryProvider).entrar(_apto.text, _nome.text);
    ref.read(sessaoProvider.notifier).entrarMorador(m);
    if (mounted) context.go('/m/inicio');
  }

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 900;
    final formulario = _Formulario(
      modo: _modo,
      onModo: (m) => setState(() => _modo = m),
      apto: _apto,
      nome: _nome,
      onEntrarMorador: _entrarMorador,
      onDemo: (a, n) {
        _apto.text = a;
        _nome.text = n;
      },
      onSindico: () {
        ref.read(sessaoProvider.notifier).entrarSindico('Roberto (síndico)');
        context.go('/sindico/painel');
      },
      onTablet: () {
        ref.read(sessaoProvider.notifier).modoTablet();
        context.go('/tablet');
      },
    );

    if (!largo) {
      return Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 28, 22, 40), children: [
            const LogoLavanderon(altura: 34, comAssinatura: true),
            const SizedBox(height: 22),
            Text('Reserve a máquina, confirme o uso e saiba quando sua roupa fica pronta.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Cores.textoSuave, fontWeight: FontWeight.w600)),
            const SizedBox(height: 26),
            formulario,
          ]),
        ),
      );
    }

    return Scaffold(
      body: Row(children: [
        Expanded(flex: 5, child: const _Hero()),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: formulario),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B3C8C), Color(0xFF0D47A1), Color(0xFF0E7FA8)]),
      ),
      padding: const EdgeInsets.fromLTRB(56, 52, 56, 52),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const LogoLavanderon(altura: 36, claro: true, comAssinatura: true),
        const Spacer(),
        Text('A lavanderia do Vision,\nsem surpresas.', style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1)),
        const SizedBox(height: 18),
        Text('Veja o que está livre agora, reserve em 3 toques e receba um aviso quando a sua roupa estiver pronta. Funciona no celular, no computador e no tablet da lavanderia.',
            style: t.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600, height: 1.45)),
        const SizedBox(height: 34),
        const Wrap(spacing: 12, runSpacing: 12, children: [
          _Destaque(Icons.event_available_rounded, 'Reservas em tempo real'),
          _Destaque(Icons.timer_rounded, 'Cronômetro de roupa pronta'),
          _Destaque(Icons.swap_horiz_rounded, 'Máquina ocupada? Troque na hora'),
          _Destaque(Icons.inventory_2_rounded, 'Aviso de roupa retirada'),
        ]),
        const Spacer(),
        Text('Demonstração com dados fictícios · 6 lavadoras e 6 secadoras · aberta 24 h',
            style: t.bodySmall?.copyWith(color: Colors.white60, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Destaque extends StatelessWidget {
  const _Destaque(this.icone, this.texto);
  final IconData icone;
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.modo,
    required this.onModo,
    required this.apto,
    required this.nome,
    required this.onEntrarMorador,
    required this.onDemo,
    required this.onSindico,
    required this.onTablet,
  });
  final _Modo modo;
  final ValueChanged<_Modo> onModo;
  final TextEditingController apto, nome;
  final Future<void> Function() onEntrarMorador;
  final void Function(String, String) onDemo;
  final VoidCallback onSindico, onTablet;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Entrar', style: t.headlineMedium),
      const SizedBox(height: 16),
      SegmentedButton<_Modo>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _Modo.morador, label: Text('Morador'), icon: Icon(Icons.person_rounded)),
          ButtonSegment(value: _Modo.sindico, label: Text('Síndico'), icon: Icon(Icons.admin_panel_settings_rounded)),
          ButtonSegment(value: _Modo.tablet, label: Text('Tablet'), icon: Icon(Icons.tablet_mac_rounded)),
        ],
        selected: {modo},
        onSelectionChanged: (s) => onModo(s.first),
      ),
      const SizedBox(height: 24),
      ...switch (modo) {
        _Modo.morador => _morador(context),
        _Modo.sindico => _sindico(context),
        _Modo.tablet => _tablet(context),
      },
    ]);
  }

  List<Widget> _morador(BuildContext context) => [
        TextField(
          controller: apto,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          decoration: const InputDecoration(labelText: 'Número do apartamento', hintText: 'Ex.: 302', prefixIcon: Icon(Icons.apartment_rounded)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: nome,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => onEntrarMorador(),
          decoration: const InputDecoration(labelText: 'Seu primeiro nome', hintText: 'Ex.: Maria', prefixIcon: Icon(Icons.badge_rounded)),
        ),
        const SizedBox(height: 18),
        BotaoAcao(rotulo: 'Entrar', icone: Icons.login_rounded, onPressed: onEntrarMorador),
        const SizedBox(height: 10),
        Center(
          child: TextButton(onPressed: () => _pedirAcesso(context), child: const Text('Não tenho cadastro: pedir acesso ao síndico')),
        ),
        const SizedBox(height: 18),
        CartaoBase(
          cor: Cores.fundoDe(Cores.agua),
          corBorda: Cores.agua.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Moradores de demonstração', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (a, n) in usuariosDemo)
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text('$a · $n${a == '508' ? ' (suspenso)' : ''}'),
                  onPressed: () => onDemo(a, n),
                ),
            ]),
          ]),
        ),
      ];

  List<Widget> _sindico(BuildContext context) => [
        const _Explicacao(
          icone: Icons.admin_panel_settings_rounded,
          titulo: 'Área do síndico',
          texto: 'Painel com máquinas, agenda, ocorrências, moradores, comunicados e estatísticas. No sistema real, síndico, subsíndicos e zelador entram com e-mail e senha.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: onSindico, icon: const Icon(Icons.login_rounded), label: const Text('Entrar como síndico (demonstração)')),
      ];

  List<Widget> _tablet(BuildContext context) => [
        const _Explicacao(
          icone: Icons.tablet_mac_rounded,
          titulo: 'Tablet da lavanderia',
          texto: 'Painel fixo na lavanderia para quem desceu sem celular. Qualquer morador se identifica com o andar, o final do apartamento e o nome; a sessão termina sozinha.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: onTablet, icon: const Icon(Icons.open_in_full_rounded), label: const Text('Abrir modo tablet')),
      ];

  void _pedirAcesso(BuildContext context) {
    final a = TextEditingController(text: apto.text), n = TextEditingController(text: nome.text), o = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => Consumer(builder: (c, ref, _) {
        return AlertDialog(
          title: const Text('Pedir acesso'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('O síndico recebe seu pedido e aprova com um toque.', style: TextStyle(color: Cores.textoSuave)),
              const SizedBox(height: 14),
              TextField(controller: a, decoration: const InputDecoration(labelText: 'Apartamento')),
              const SizedBox(height: 10),
              TextField(controller: n, decoration: const InputDecoration(labelText: 'Primeiro nome')),
              const SizedBox(height: 10),
              TextField(controller: o, decoration: const InputDecoration(labelText: 'Observação (opcional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            BotaoAcao(
              rotulo: 'Enviar pedido',
              expandir: false,
              onPressed: () async {
                await ref.read(lavanderonRepositoryProvider).pedirAcesso(a.text, n.text, o.text.isEmpty ? null : o.text);
                if (c.mounted) {
                  Navigator.pop(c);
                  mostrarSucesso(context, 'Pedido enviado ao síndico.');
                }
              },
            ),
          ],
        );
      }),
    );
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao({required this.icone, required this.titulo, required this.texto});
  final IconData icone;
  final String titulo, texto;
  @override
  Widget build(BuildContext context) => CartaoBase(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: Cores.marca, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(texto, style: const TextStyle(color: Cores.textoSuave)),
            ]),
          ),
        ]),
      );
}
