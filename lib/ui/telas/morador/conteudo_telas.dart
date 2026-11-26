import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/maquina_widgets.dart';
import 'shell_morador.dart';

(Color, IconData, String) visualPrioridade(PrioridadeNoticia p) => switch (p) {
      PrioridadeNoticia.urgente => (Cores.problema, Icons.priority_high_rounded, 'Urgente'),
      PrioridadeNoticia.importante => (Cores.reservada, Icons.star_rounded, 'Importante'),
      PrioridadeNoticia.informativo => (Cores.marcaClara, Icons.info_rounded, 'Informativo'),
    };

/// Texto simples com "## subtítulo", "- item" e parágrafos separados por linha em branco.
class CorpoTexto extends StatelessWidget {
  const CorpoTexto(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final blocos = <Widget>[];
    for (final par in texto.split('\n\n')) {
      final linhas = par.split('\n');
      for (final l in linhas) {
        if (l.startsWith('## ')) {
          blocos.add(Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(l.substring(3), style: t.titleMedium)));
        } else if (l.startsWith('- ')) {
          blocos.add(Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 8), child: CircleAvatar(radius: 3, backgroundColor: Cores.marca)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.substring(2), style: t.bodyLarge)),
            ]),
          ));
        } else if (l.trim().isNotEmpty) {
          blocos.add(Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: t.bodyLarge)));
        }
      }
      blocos.add(const SizedBox(height: 8));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocos);
  }
}

// ───────────────────────── Notícias ─────────────────────────

class NoticiasTela extends ConsumerWidget {
  const NoticiasTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final lista = [...(ref.watch(noticiasProvider).value ?? const <Noticia>[])]
      ..sort((a, b) => a.fixada != b.fixada ? (a.fixada ? -1 : 1) : b.publicadaEm.compareTo(a.publicadaEm));
    return PaginaMorador(
      titulo: 'Notícias',
      subtitulo: 'Comunicados do síndico',
      filhos: [
        if (lista.isEmpty) const EstadoVazio(icone: Icons.campaign_outlined, titulo: 'Nenhum comunicado ainda'),
        for (final n in lista) Padding(padding: const EdgeInsets.only(bottom: 12), child: CartaoNoticia(noticia: n, agora: agora, onTap: () => context.go('/m/noticia/${n.id}'))),
      ],
    );
  }
}

class CartaoNoticia extends StatelessWidget {
  const CartaoNoticia({super.key, required this.noticia, required this.agora, this.onTap});
  final Noticia noticia;
  final DateTime agora;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final (cor, ic, rot) = visualPrioridade(noticia.prioridade);
    return CartaoBase(
      onTap: onTap,
      corBorda: noticia.prioridade == PrioridadeNoticia.urgente ? cor.withValues(alpha: 0.4) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Selo(cor: cor, icone: ic, texto: rot),
          if (noticia.fixada) ...[const SizedBox(width: 8), const Selo(cor: Cores.textoSuave, icone: Icons.push_pin_rounded, texto: 'Fixada')],
          const Spacer(),
          if (!noticia.lida) Container(width: 10, height: 10, decoration: const BoxDecoration(color: Cores.marca, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 10),
        Text(noticia.titulo, style: TextStyle(fontSize: 17, fontWeight: noticia.lida ? FontWeight.w700 : FontWeight.w900)),
        const SizedBox(height: 4),
        Text(noticia.resumo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoSuave)),
        const SizedBox(height: 8),
        Text('${noticia.autor} · ${Fmt.dia(noticia.publicadaEm, agora)}', style: const TextStyle(color: Cores.textoFraco, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class NoticiaTela extends ConsumerStatefulWidget {
  const NoticiaTela({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NoticiaTela> createState() => _NoticiaTelaState();
}

class _NoticiaTelaState extends ConsumerState<NoticiaTela> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(lavanderonRepositoryProvider).marcarNoticiaLida(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final n = (ref.watch(noticiasProvider).value ?? const <Noticia>[]).where((x) => x.id == widget.id).firstOrNull;
    if (n == null) return const PaginaMorador(titulo: 'Notícia', voltar: true, filhos: []);
    final (cor, ic, rot) = visualPrioridade(n.prioridade);
    return PaginaMorador(
      titulo: 'Notícia',
      voltar: true,
      filhos: [
        ConteudoLimitado(
          largura: 760,
          child: CartaoBase(
            padding: const EdgeInsets.all(26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Selo(cor: cor, icone: ic, texto: rot),
              const SizedBox(height: 12),
              Text(n.titulo, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('${n.autor} · ${Fmt.dataLonga(n.publicadaEm)} · ${n.leituras} leituras', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
              const Divider(height: 34),
              CorpoTexto(n.corpo),
            ]),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Tutoriais ─────────────────────────

IconData iconeCategoriaTutorial(String c) {
  final x = c.toLowerCase();
  if (x.contains('secad')) return Icons.dry_rounded;
  if (x.contains('lavad')) return Icons.local_laundry_service_rounded;
  if (x.contains('etiqueta') || x.contains('símbol')) return Icons.label_rounded;
  if (x.contains('segur') || x.contains('cuidad')) return Icons.health_and_safety_rounded;
  if (x.contains('produto') || x.contains('dosag')) return Icons.water_drop_rounded;
  if (x.contains('primeir') || x.contains('sistema')) return Icons.rocket_launch_rounded;
  return Icons.menu_book_rounded;
}

class TutoriaisTela extends ConsumerStatefulWidget {
  const TutoriaisTela({super.key, this.rotaBase = '/m/tutorial'});
  final String rotaBase;
  @override
  ConsumerState<TutoriaisTela> createState() => _TutoriaisTelaState();
}

class _TutoriaisTelaState extends ConsumerState<TutoriaisTela> {
  String _busca = '';
  @override
  Widget build(BuildContext context) => PaginaMorador(
        titulo: 'Tutoriais',
        subtitulo: 'Como lavar e secar do jeito certo',
        filhos: [ListaTutoriais(busca: _busca, onBusca: (v) => setState(() => _busca = v), onAbrir: (t) => context.go('${widget.rotaBase}/${t.id}'))],
      );
}

class ListaTutoriais extends ConsumerWidget {
  const ListaTutoriais({super.key, required this.busca, required this.onBusca, required this.onAbrir});
  final String busca;
  final ValueChanged<String> onBusca;
  final void Function(Tutorial) onAbrir;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(tutoriaisProvider).value ?? const <Tutorial>[];
    final q = busca.toLowerCase();
    final lista = q.isEmpty
        ? todos
        : todos.where((t) => '${t.titulo} ${t.resumo} ${t.categoria} ${t.passos.map((p) => '${p.titulo} ${p.texto}').join(' ')}'.toLowerCase().contains(q)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(onChanged: onBusca, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar: edredom, tênis, lã, filtro…')),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 620 ? 2 : 1);
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final t in lista)
            SizedBox(
              width: (c.maxWidth - (cols - 1) * 12) / cols,
              child: CartaoBase(
                onTap: () => onAbrir(t),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Cores.fundoDe(Cores.agua), borderRadius: BorderRadius.circular(14)),
                    child: Icon(iconeCategoriaTutorial(t.categoria), color: const Color(0xFF00838F)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.categoria.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900, color: Cores.textoFraco)),
                      const SizedBox(height: 2),
                      Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      const SizedBox(height: 4),
                      Text(t.resumo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoSuave, fontSize: 13.5)),
                      const SizedBox(height: 8),
                      Text('${t.passos.length} passos · ${t.minutos} min de leitura', style: const TextStyle(color: Cores.textoFraco, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]);
      }),
      if (lista.isEmpty) const EstadoVazio(icone: Icons.search_off_rounded, titulo: 'Nada encontrado'),
    ]);
  }
}

class TutorialTela extends ConsumerWidget {
  const TutorialTela({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = (ref.watch(tutoriaisProvider).value ?? const <Tutorial>[]).where((x) => x.id == id).firstOrNull;
    if (t == null) return const PaginaMorador(titulo: 'Tutorial', voltar: true, filhos: []);
    return PaginaMorador(titulo: 'Tutorial', voltar: true, filhos: [ConteudoLimitado(largura: 760, child: DetalheTutorial(tutorial: t))]);
  }
}

class DetalheTutorial extends StatelessWidget {
  const DetalheTutorial({super.key, required this.tutorial});
  final Tutorial tutorial;
  @override
  Widget build(BuildContext context) {
    final t = tutorial;
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF006978), Color(0xFF00ACC1)]),
          borderRadius: BorderRadius.circular(Medidas.raio),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(iconeCategoriaTutorial(t.categoria), color: Colors.white),
            const SizedBox(width: 8),
            Text(t.categoria, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
            if (t.tipoMaquina != null) ...[const SizedBox(width: 8), Icon(iconeTipo(t.tipoMaquina!), color: Colors.white70, size: 18)],
          ]),
          const SizedBox(height: 10),
          Text(t.titulo, style: tt.headlineSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(t.resumo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 16),
      for (final (i, p) in t.passos.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CartaoBase(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 16, backgroundColor: Cores.marca, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.titulo, style: tt.titleMedium),
                  const SizedBox(height: 4),
                  Text(p.texto, style: tt.bodyLarge),
                  if (p.dica != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Cores.fundoDe(Cores.reservada), borderRadius: BorderRadius.circular(12)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lightbulb_rounded, color: Cores.reservada, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.dica!, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}
