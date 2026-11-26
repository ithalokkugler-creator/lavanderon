import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dominio.dart';
import '../estado.dart';
import '../fluxos/relatar_paginas.dart';
import '../tema/tema.dart';
import '../util/fmt.dart';
import 'base.dart';

/// Lista pública "Roupas retiradas" (6.10). Não mostra quem retirou;
/// o apartamento dono só vê a marca "Suas".
class ListaRoupasRetiradas extends ConsumerWidget {
  const ListaRoupasRetiradas({super.key, this.rotaVerTodas, this.limite = 3, this.obterContexto, this.escuro = false});
  final String? rotaVerTodas;
  final int limite;
  final Future<ContextoAcao?> Function()? obterContexto;
  final bool escuro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final todas = (ref.watch(roupasRetiradasProvider).value ?? const <RoupaRetirada>[]).where((r) => r.recolhidaEm == null).toList()
      ..sort((a, b) => b.desde.compareTo(a.desde));
    final ctxAtual = ref.watch(contextoAcaoProvider);
    final lista = todas.take(limite).toList();

    Future<void> pegar(RoupaRetirada r) async {
      final ctx = obterContexto == null ? ctxAtual : await obterContexto!();
      if (ctx == null || !context.mounted) return;
      try {
        await ref.read(lavanderonRepositoryProvider).roupaRecolhida(r.id, ctx.quem);
        if (context.mounted) mostrarSucesso(context, 'Combinado! Registro encerrado.');
      } catch (e) {
        if (context.mounted) mostrarErro(context, e);
      }
    }

    return CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_rounded, color: Cores.semRegistro),
          const SizedBox(width: 8),
          Expanded(child: Text('Roupas retiradas', style: Theme.of(context).textTheme.titleMedium)),
          if (todas.isNotEmpty) Selo(cor: Cores.semRegistro, texto: '${todas.length}'),
        ]),
        const SizedBox(height: 4),
        const Text('Roupas que alguém tirou da máquina e estão esperando o dono.', style: TextStyle(color: Cores.textoSuave, fontSize: 13)),
        const SizedBox(height: 10),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [Icon(Icons.check_circle_outline, color: Cores.livre), SizedBox(width: 8), Text('Nenhuma roupa esperando. 👏', style: TextStyle(fontWeight: FontWeight.w700))]),
          ),
        for (final r in lista)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ItemRoupa(
              roupa: r,
              agora: agora,
              minha: ctxAtual != null && r.donoApto == ctxAtual.aptoId,
              onPegar: (ctxAtual != null && r.donoApto == ctxAtual.aptoId) || !r.donoConhecido || obterContexto != null ? () => pegar(r) : null,
            ),
          ),
        if (rotaVerTodas != null && todas.length > limite)
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go(rotaVerTodas!), child: Text('Ver todas (${todas.length})'))),
      ]),
    );
  }
}

class _ItemRoupa extends StatelessWidget {
  const _ItemRoupa({required this.roupa, required this.agora, required this.minha, this.onPegar});
  final RoupaRetirada roupa;
  final DateTime agora;
  final bool minha;
  final VoidCallback? onPegar;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: minha ? Cores.fundoDe(Cores.semRegistro) : Cores.fundo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: minha ? Cores.semRegistro.withValues(alpha: 0.4) : Cores.borda),
        ),
        child: Row(children: [
          Icon(iconeLocal(roupa.local), color: Cores.semRegistro),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${roupa.maquinaNome} → ${roupa.localTexto}', style: const TextStyle(fontWeight: FontWeight.w800))),
                if (minha) ...[const SizedBox(width: 6), const Selo(cor: Cores.semRegistro, texto: 'Suas', forte: true)],
              ]),
              Text('desde ${Fmt.hora(roupa.desde)} (${Fmt.relativo(roupa.desde, agora)})${roupa.donoConhecido ? '' : ' · dono desconhecido'}',
                  style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
            ]),
          ),
          if (onPegar != null)
            TextButton(onPressed: onPegar, child: Text(minha ? 'Já peguei' : 'São minhas')),
        ]),
      );
}
