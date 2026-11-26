import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/logo.dart';
import '../../widgets/maquina_widgets.dart';
import 'sindico_operacao.dart';

class _ItemS {
  const _ItemS(this.rota, this.rotulo, this.icone);
  final String rota, rotulo;
  final IconData icone;
}

const _itens = [
  _ItemS('/sindico/painel', 'Painel', Icons.space_dashboard_rounded),
  _ItemS('/sindico/agenda', 'Agenda', Icons.calendar_view_week_rounded),
  _ItemS('/sindico/maquinas', 'Máquinas', Icons.local_laundry_service_rounded),
  _ItemS('/sindico/ocorrencias', 'Ocorrências', Icons.assignment_late_rounded),
  _ItemS('/sindico/apartamentos', 'Apartamentos', Icons.apartment_rounded),
  _ItemS('/sindico/comunicados', 'Comunicados', Icons.campaign_rounded),
  _ItemS('/sindico/estatisticas', 'Estatísticas', Icons.insights_rounded),
  _ItemS('/sindico/config', 'Configurações', Icons.tune_rounded),
];

class ShellSindico extends ConsumerWidget {
  const ShellSindico({super.key, required this.child, required this.local});
  final Widget child;
  final String local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final largo = MediaQuery.sizeOf(context).width >= Medidas.breakDesktop;
    final abertas = (ref.watch(ocorrenciasProvider).value ?? const <Ocorrencia>[]).where((o) => o.status == StatusOcorrencia.aberta).length;
    final nome = ref.watch(sessaoProvider).adminNome ?? 'Síndico';

    Widget menu({bool fecharAoTocar = false}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.fromLTRB(22, 24, 22, 4), child: LogoLavanderon(altura: 24)),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Text('ÁREA DO SÍNDICO', style: TextStyle(fontSize: 11.5, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: Cores.textoFraco)),
          ),
          for (final i in _itens)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Material(
                color: local.startsWith(i.rota) ? Cores.fundoDe(Cores.marca) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Contador(i.rota.endsWith('ocorrencias') ? abertas : 0, child: Icon(i.icone, color: local.startsWith(i.rota) ? Cores.marca : Cores.textoSuave)),
                  title: Text(i.rotulo, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: local.startsWith(i.rota) ? Cores.marca : Cores.texto)),
                  onTap: () {
                    if (fecharAoTocar) Navigator.pop(context);
                    context.go(i.rota);
                  },
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: CartaoBase(
              cor: Cores.fundo,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const CircleAvatar(backgroundColor: Cores.marca, child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nome, style: const TextStyle(fontWeight: FontWeight.w800)), const Text('Síndico', style: TextStyle(color: Cores.textoSuave, fontSize: 12.5))])),
                IconButton(
                  tooltip: 'Sair',
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () {
                    ref.read(sessaoProvider.notifier).sair();
                    context.go('/entrar');
                  },
                ),
              ]),
            ),
          ),
        ]);

    if (largo) {
      return Scaffold(
        body: Row(children: [
          Container(width: 256, decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Cores.borda))), child: SafeArea(child: menu())),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      drawer: Drawer(backgroundColor: Colors.white, child: SafeArea(child: menu(fecharAoTocar: true))),
      body: child,
    );
  }
}

/// Página padrão da área do síndico.
class PaginaSindico extends StatelessWidget {
  const PaginaSindico({super.key, required this.titulo, required this.filhos, this.subtitulo, this.acoes, this.fab});
  final String titulo;
  final String? subtitulo;
  final List<Widget> filhos;
  final List<Widget>? acoes;
  final Widget? fab;
  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= Medidas.breakDesktop;
    return Scaffold(
      floatingActionButton: fab,
      appBar: AppBar(
        automaticallyImplyLeading: !largo,
        toolbarHeight: 76,
        titleSpacing: largo ? 32 : 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitulo != null) Text(subtitulo!, style: const TextStyle(fontSize: 13, color: Cores.textoSuave, fontWeight: FontWeight.w600)),
        ]),
        actions: [...?acoes, const SizedBox(width: 16)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(largo ? 32 : 16, 4, largo ? 32 : 16, 96),
        children: [ConteudoLimitado(largura: 1320, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos))],
      ),
    );
  }
}

class Kpi extends StatelessWidget {
  const Kpi({super.key, required this.valor, required this.rotulo, required this.icone, required this.cor, this.sub});
  final String valor, rotulo;
  final String? sub;
  final IconData icone;
  final Color cor;
  @override
  Widget build(BuildContext context) => CartaoBase(
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: Cores.fundoDe(cor), borderRadius: BorderRadius.circular(14)), child: Icon(icone, color: cor)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valor, style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.1)),
              Text(rotulo, style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700, fontSize: 13)),
              if (sub != null) Text(sub!, style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

/// Linha de colunas responsiva.
class LinhaResponsiva extends StatelessWidget {
  const LinhaResponsiva({super.key, required this.filhos, this.minLargura = 230, this.espaco = 14});
  final List<Widget> filhos;
  final double minLargura, espaco;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minLargura).floor().clamp(1, filhos.length);
        final w = (c.maxWidth - (cols - 1) * espaco) / cols;
        return Wrap(spacing: espaco, runSpacing: espaco, children: [for (final f in filhos) SizedBox(width: w, child: f)]);
      });
}

// ───────────────────────── Painel ─────────────────────────

class PainelSindicoTela extends ConsumerWidget {
  const PainelSindicoTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final maquinas = ref.watch(maquinasProvider).value ?? const <Maquina>[];
    final ocorr = ref.watch(ocorrenciasProvider).value ?? const <Ocorrencia>[];
    final roupas = ref.watch(roupasRetiradasProvider).value ?? const <RoupaRetirada>[];
    final fech = ref.watch(fechamentoProvider).value;
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final reservasHoje = ref.watch(reservasDoDiaProvider(hoje)).value ?? const <Reserva>[];
    final abertas = ocorr.where((o) => o.status == StatusOcorrencia.aberta || o.status == StatusOcorrencia.emAndamento).sortedBy((o) => o.criadaEm).reversed.toList()
      ..sort((a, b) => (b.urgente ? 1 : 0) - (a.urgente ? 1 : 0));
    final validas = reservasHoje.where((r) => r.status != StatusReserva.cancelada).toList();
    final checkins = validas.where((r) => r.checkinEm != null).length;
    final noShow = validas.where((r) => r.status == StatusReserva.naoCompareceu).length;
    final emUso = maquinas.where((m) => m.situacao == SituacaoMaquina.emUso).length;
    final indisp = maquinas.where((m) => m.status != StatusMaquina.disponivel).length;
    final roupasAntigas = roupas.where((r) => r.recolhidaEm == null && agora.difference(r.desde).inHours >= 24).length;

    return PaginaSindico(
      titulo: 'Painel',
      subtitulo: '${Fmt.dataLonga(agora)} · ${Fmt.hora(agora)}',
      filhos: [
        InterruptorLavanderia(fechamento: fech),
        const SizedBox(height: 16),
        LinhaResponsiva(filhos: [
          Kpi(valor: '${validas.length}', rotulo: 'reservas hoje', icone: Icons.event_rounded, cor: Cores.marca),
          Kpi(valor: '$checkins', rotulo: 'usos confirmados', icone: Icons.task_alt_rounded, cor: Cores.livre),
          Kpi(valor: '$noShow', rotulo: 'não compareceram', icone: Icons.person_off_rounded, cor: Cores.problema),
          Kpi(valor: '$emUso/${maquinas.length}', rotulo: 'máquinas em uso agora', icone: Icons.autorenew_rounded, cor: Cores.emUso, sub: indisp > 0 ? '$indisp indisponíveis' : null),
        ]),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, c) {
          final duas = c.maxWidth >= 980;
          final esquerda = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TituloSecao('Máquinas agora', acao: 'Gerenciar', onAcao: () => context.go('/sindico/maquinas')),
            SecaoMaquinas(tipo: TipoMaquina.lavadora, maquinas: maquinas, agora: agora, onTap: (m) => acoesMaquina(context, ref, m)),
            const SizedBox(height: 14),
            SecaoMaquinas(tipo: TipoMaquina.secadora, maquinas: maquinas, agora: agora, onTap: (m) => acoesMaquina(context, ref, m)),
          ]);
          final direita = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TituloSecao('Ocorrências abertas', acao: 'Ver todas', onAcao: () => context.go('/sindico/ocorrencias')),
            if (abertas.isEmpty) const CartaoBase(child: Text('Nenhuma ocorrência aberta. 🎉', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final o in abertas.take(5)) Padding(padding: const EdgeInsets.only(bottom: 10), child: CartaoOcorrencia(ocorrencia: o, agora: agora, compacto: true)),
            const SizedBox(height: 10),
            const TituloSecao('Pendências'),
            CartaoBase(
              child: Column(children: [
                _Pendencia(Icons.person_add_alt_1_rounded, 'Pedidos de acesso', '2 aguardando', Cores.marca),
                _Pendencia(Icons.inventory_2_rounded, 'Roupas retiradas há mais de 24 h', roupasAntigas == 0 ? 'nenhuma' : '$roupasAntigas', Cores.semRegistro),
                _Pendencia(Icons.lightbulb_rounded, 'Sugestões novas', '${(ref.watch(sugestoesProvider).value ?? const <Sugestao>[]).where((s) => s.status == StatusSugestao.recebida).length}', Cores.reservada),
                const _Pendencia(Icons.tablet_mac_rounded, 'Tablet da lavanderia', 'online', Cores.livre),
              ]),
            ),
          ]);
          return duas
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: esquerda), const SizedBox(width: 24), Expanded(flex: 2, child: direita)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [esquerda, const SizedBox(height: 18), direita]);
        }),
      ],
    );
  }
}

class _Pendencia extends StatelessWidget {
  const _Pendencia(this.icone, this.texto, this.valor, this.cor);
  final IconData icone;
  final String texto, valor;
  final Color cor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(valor, style: TextStyle(fontWeight: FontWeight.w900, color: cor)),
        ]),
      );
}

class InterruptorLavanderia extends ConsumerWidget {
  const InterruptorLavanderia({super.key, required this.fechamento});
  final Fechamento? fechamento;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aberta = fechamento == null;
    final cor = aberta ? Cores.livre : Cores.indisponivel;
    return CartaoBase(
      corBorda: cor.withValues(alpha: 0.4),
      cor: Cores.fundoDe(cor),
      child: Row(children: [
        Icon(aberta ? Icons.lock_open_rounded : Icons.lock_rounded, color: cor, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(aberta ? 'Lavanderia aberta · 24 h' : 'Lavanderia fechada', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: cor)),
            Text(aberta ? 'Feche para manutenção, limpeza ou emergência. Os moradores afetados são avisados.' : fechamento!.motivo, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 12),
        aberta
            ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Cores.indisponivel), onPressed: () => _fechar(context, ref), icon: const Icon(Icons.lock_rounded), label: const Text('Fechar'))
            : BotaoAcao(rotulo: 'Reabrir', icone: Icons.lock_open_rounded, expandir: false, cor: Cores.livre, sucesso: 'Lavanderia reaberta.', onPressed: () => ref.read(lavanderonRepositoryProvider).reabrirLavanderia()),
      ]),
    );
  }

  Future<void> _fechar(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(lavanderonRepositoryProvider);
    final motivo = TextEditingController(text: 'Manutenção hidráulica');
    var horas = 2;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final ate = horas == 0 ? null : repo.agoraAtual.add(Duration(hours: horas));
        return AlertDialog(
          title: const Text('Fechar a lavanderia'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo (aparece para todos)')),
              const SizedBox(height: 14),
              const Text('Por quanto tempo?', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final h in [1, 2, 4, 8, 0]) ChoiceChip(label: Text(h == 0 ? 'Até eu reabrir' : '$h h'), selected: horas == h, onSelected: (_) => set(() => horas = h)),
              ]),
              const SizedBox(height: 14),
              FutureBuilder<int>(
                future: repo.impactoFechamento(ate),
                builder: (_, s) => FaixaAlerta(
                  cor: Cores.reservada,
                  icone: Icons.event_busy_rounded,
                  titulo: s.hasData ? '${s.data} reservas serão canceladas sem penalidade' : 'Calculando impacto…',
                  texto: 'Quem está com máquina em uso não é cancelado: recebe aviso para retirar a roupa ao fim do ciclo.',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Voltar')),
            BotaoAcao(
              rotulo: 'Fechar agora',
              expandir: false,
              cor: Cores.problema,
              onPressed: () async {
                final n = await repo.fecharLavanderia(motivo.text.trim().isEmpty ? 'Manutenção' : motivo.text.trim(), ate: ate);
                if (c.mounted) {
                  Navigator.pop(c);
                  mostrarSucesso(context, 'Lavanderia fechada. $n reservas canceladas e moradores avisados.');
                }
              },
            ),
          ],
        );
      }),
    );
  }
}
