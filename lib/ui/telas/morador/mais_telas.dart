import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../estado.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/reserva_widgets.dart';
import '../../widgets/roupa_widgets.dart';
import 'shell_morador.dart';

class MaisTela extends ConsumerWidget {
  const MaisTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(sessaoProvider).morador;
    if (m == null) return const SizedBox();
    final avisos = ref.watch(avisosProvider(m.aptoId)).value ?? const <Aviso>[];
    final naoLidos = avisos.where((a) => !a.lido).length;
    final itens = [
      (Icons.event_note_rounded, 'Minhas reservas', 'Próximas reservas do apartamento', '/m/reservas', 0),
      (Icons.history_rounded, 'Histórico', 'Lavagens e secagens, com resumo do mês', '/m/historico', 0),
      (Icons.notifications_rounded, 'Avisos', 'Tudo que o sistema te avisou', '/m/avisos', naoLidos),
      (Icons.inventory_2_rounded, 'Roupas retiradas', 'Roupas fora da máquina esperando o dono', '/m/roupas', 0),
      (Icons.assignment_rounded, 'Minhas ocorrências', 'Problemas que você relatou', '/m/ocorrencias', 0),
      (Icons.lightbulb_rounded, 'Sugestões', 'Ideias para o app e a lavanderia', '/m/sugestoes', 0),
    ];
    return PaginaMorador(titulo: 'Mais', filhos: [
      CartaoBase(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Cores.marca, child: Text(m.nome.characters.first, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w900))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.nome, style: Theme.of(context).textTheme.titleLarge),
              Text('Apartamento ${m.aptoId} · ${m.aptoId.substring(0, 1)}º andar', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
            ]),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(sessaoProvider.notifier).sair();
              context.go('/entrar');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (ic, t, s, rota, n) in itens)
            SizedBox(
              width: (c.maxWidth - (cols - 1) * 12) / cols,
              child: CartaoBase(
                onTap: () => context.go(rota),
                child: Row(children: [
                  Contador(n, child: Container(width: 46, height: 46, decoration: BoxDecoration(color: Cores.fundoDe(Cores.marca), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: Cores.marca))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)), Text(s, style: const TextStyle(color: Cores.textoSuave, fontSize: 13))])),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 20),
      const CartaoBase(
        cor: Color(0xFFF7F9FC),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Privacidade', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Guardamos só o número do apartamento e o primeiro nome. Outros moradores veem apenas o número do apartamento nas reservas, nunca o nome. Fale com o síndico para corrigir ou excluir seus dados.', style: TextStyle(color: Cores.textoSuave, fontSize: 13.5)),
        ]),
      ),
    ]);
  }
}

class MinhasReservasTela extends ConsumerWidget {
  const MinhasReservasTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(sessaoProvider).morador!;
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final lista = (ref.watch(reservasDoAptoProvider(m.aptoId)).value ?? const <Reserva>[])
        .where((r) => (r.status == StatusReserva.agendada || r.status == StatusReserva.emUso || r.status == StatusReserva.precisaAcao) && r.fim.isAfter(agora))
        .sortedBy((r) => r.inicio);
    return PaginaMorador(titulo: 'Minhas reservas', subtitulo: 'Todas as pessoas do Ap ${m.aptoId}', voltar: true, filhos: [
      if (lista.isEmpty) EstadoVazio(icone: Icons.event_available_rounded, titulo: 'Nenhuma reserva futura', acao: 'Reservar', onAcao: () => context.go('/m/reservar')),
      for (final r in lista) Padding(padding: const EdgeInsets.only(bottom: 10), child: LinhaReserva(reserva: r, agora: agora, onTap: () => context.go('/m/reserva/${r.id}'))),
    ]);
  }
}

class HistoricoTela extends ConsumerStatefulWidget {
  const HistoricoTela({super.key});
  @override
  ConsumerState<HistoricoTela> createState() => _HistoricoTelaState();
}

class _HistoricoTelaState extends ConsumerState<HistoricoTela> {
  bool _soMinhas = false;
  @override
  Widget build(BuildContext context) {
    final m = ref.watch(sessaoProvider).morador!;
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final todas = (ref.watch(reservasDoAptoProvider(m.aptoId)).value ?? const <Reserva>[])
        .where((r) => r.status != StatusReserva.agendada && r.status != StatusReserva.emUso && r.status != StatusReserva.precisaAcao)
        .where((r) => !_soMinhas || r.criadaPorNome == m.nome)
        .sortedBy((r) => r.inicio)
        .reversed
        .toList();
    final mes = todas.where((r) => r.inicio.month == agora.month && r.inicio.year == agora.year).toList();
    final concl = mes.where((r) => r.status == StatusReserva.concluida).toList();
    final noShow = mes.where((r) => r.status == StatusReserva.naoCompareceu).length;
    final taxa = (concl.length + noShow) == 0 ? 100 : (concl.length * 100 / (concl.length + noShow)).round();
    final maisUsada = groupBy(concl, (Reserva r) => r.maquinaNome).entries.sortedBy<num>((e) => -e.value.length).firstOrNull?.key ?? '—';
    final horario = groupBy(concl, (Reserva r) => r.inicio.hour).entries.sortedBy<num>((e) => -e.value.length).firstOrNull?.key;
    final porMes = groupBy(todas, (Reserva r) => DateTime(r.inicio.year, r.inicio.month));

    return PaginaMorador(titulo: 'Histórico', voltar: true, acoes: [
      FilterChip(label: const Text('Só as minhas'), selected: _soMinhas, onSelected: (v) => setState(() => _soMinhas = v)),
    ], filhos: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 760 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        Widget card(String v, String r, IconData ic, Color cor) => SizedBox(
              width: w,
              child: CartaoBase(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(ic, color: cor),
                  const SizedBox(height: 8),
                  Text(v, style: Theme.of(context).textTheme.headlineSmall),
                  Text(r, style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            );
        return Wrap(spacing: 12, runSpacing: 12, children: [
          card('${concl.where((r) => r.tipo == TipoMaquina.lavadora).length} + ${concl.where((r) => r.tipo == TipoMaquina.secadora).length}', 'lavagens + secagens no mês', Icons.local_laundry_service_rounded, Cores.marca),
          card('$taxa%', noShow == 0 ? 'comparecimento' : 'comparecimento · $noShow faltas', Icons.verified_rounded, taxa >= 80 ? Cores.livre : Cores.reservada),
          card(maisUsada, 'máquina mais usada', Icons.star_rounded, Cores.reservada),
          card(horario == null ? '—' : '${horario.toString().padLeft(2, '0')}h', 'horário preferido', Icons.schedule_rounded, Cores.agua),
        ]);
      }),
      const SizedBox(height: 10),
      if (todas.isEmpty) const EstadoVazio(icone: Icons.history_rounded, titulo: 'Sem histórico ainda'),
      for (final e in porMes.entries) ...[
        TituloSecao(Fmt.dataLonga(e.key).split(' de ').skip(1).join(' de ').replaceFirstMapped(RegExp(r'^\w'), (x) => x[0]!.toUpperCase()), subtitulo: '${e.value.length} registros'),
        for (final r in e.value) Padding(padding: const EdgeInsets.only(bottom: 8), child: LinhaReserva(reserva: r, agora: agora)),
      ],
    ]);
  }
}

(IconData, Color) visualAviso(CategoriaAviso c) => switch (c) {
      CategoriaAviso.reserva => (Icons.event_rounded, Cores.reservada),
      CategoriaAviso.cronometro => (Icons.timer_rounded, Cores.pronta),
      CategoriaAviso.roupa => (Icons.inventory_2_rounded, Cores.semRegistro),
      CategoriaAviso.conduta => (Icons.gavel_rounded, Cores.problema),
      CategoriaAviso.ocorrencia => (Icons.build_circle_rounded, Cores.emUso),
      CategoriaAviso.sistema => (Icons.info_rounded, Cores.marca),
      CategoriaAviso.sindico => (Icons.admin_panel_settings_rounded, Cores.marca),
    };

class AvisosTela extends ConsumerWidget {
  const AvisosTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(sessaoProvider).morador!;
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final lista = (ref.watch(avisosProvider(m.aptoId)).value ?? const <Aviso>[]).sortedBy((a) => a.criadoEm).reversed.toList();
    final repo = ref.read(lavanderonRepositoryProvider);
    return PaginaMorador(
      titulo: 'Avisos',
      voltar: true,
      acoes: [
        if (lista.any((a) => !a.lido))
          TextButton(
            onPressed: () {
              for (final a in lista.where((a) => !a.lido)) {
                repo.marcarAvisoLido(a.id);
              }
            },
            child: const Text('Marcar todos como lidos'),
          ),
      ],
      filhos: [
        if (lista.isEmpty) const EstadoVazio(icone: Icons.notifications_none_rounded, titulo: 'Nenhum aviso'),
        for (final a in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Builder(builder: (context) {
              final (ic, cor) = visualAviso(a.categoria);
              return CartaoBase(
                cor: a.lido ? Colors.white : const Color(0xFFF5F9FF),
                corBorda: a.lido ? null : Cores.marca.withValues(alpha: 0.25),
                onTap: () {
                  repo.marcarAvisoLido(a.id);
                  if (a.rota != null) context.go(a.rota!.startsWith('/m') ? a.rota! : '/m${a.rota}');
                },
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Cores.fundoDe(cor), borderRadius: BorderRadius.circular(12)), child: Icon(ic, color: cor, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.titulo, style: TextStyle(fontWeight: a.lido ? FontWeight.w700 : FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(a.corpo, style: const TextStyle(color: Cores.textoSuave, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(Fmt.relativo(a.criadoEm, agora), style: const TextStyle(color: Cores.textoFraco, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  if (!a.lido) Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: Cores.marca, shape: BoxShape.circle)),
                ]),
              );
            }),
          ),
      ],
    );
  }
}

class RoupasTela extends StatelessWidget {
  const RoupasTela({super.key});
  @override
  Widget build(BuildContext context) => const PaginaMorador(titulo: 'Roupas retiradas', voltar: true, filhos: [ListaRoupasRetiradas(limite: 50)]);
}

(String, Color) visualStatusOcorrencia(StatusOcorrencia s) => switch (s) {
      StatusOcorrencia.aberta => ('Aberta', Cores.problema),
      StatusOcorrencia.emAndamento => ('Em andamento', Cores.reservada),
      StatusOcorrencia.resolvida => ('Resolvida', Cores.livre),
      StatusOcorrencia.descartada => ('Descartada', Cores.indisponivel),
    };

String nomeTipoOcorrencia(TipoOcorrencia t) => switch (t) {
      TipoOcorrencia.maquina => 'Máquina',
      TipoOcorrencia.lavanderia => 'Lavanderia',
      TipoOcorrencia.usoIndevido => 'Uso indevido',
      TipoOcorrencia.roupaEsquecida => 'Roupa esquecida',
      TipoOcorrencia.roupaRetirada => 'Roupa retirada',
    };

class OcorrenciasMoradorTela extends ConsumerWidget {
  const OcorrenciasMoradorTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(sessaoProvider).morador!;
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final lista = (ref.watch(ocorrenciasProvider).value ?? const <Ocorrencia>[]).where((o) => o.relatorApto == m.aptoId).sortedBy((o) => o.criadaEm).reversed.toList();
    return PaginaMorador(titulo: 'Minhas ocorrências', voltar: true, filhos: [
      if (lista.isEmpty) const EstadoVazio(icone: Icons.assignment_turned_in_rounded, titulo: 'Nada relatado', texto: 'Quando você relatar um problema, ele aparece aqui com a resposta do síndico.'),
      for (final o in lista)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Builder(builder: (context) {
            final (st, cor) = visualStatusOcorrencia(o.status);
            return CartaoBase(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Selo(cor: Cores.marca, texto: nomeTipoOcorrencia(o.tipo)),
                  const SizedBox(width: 8),
                  Selo(cor: cor, texto: st),
                  const Spacer(),
                  Text(Fmt.relativo(o.criadaEm, agora), style: const TextStyle(color: Cores.textoFraco, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Text('${o.categoria}${o.maquinaNome == null ? '' : ' · ${o.maquinaNome}'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                if (o.descricao != null) Text(o.descricao!, style: const TextStyle(color: Cores.textoSuave)),
                if (o.resposta != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Cores.fundoDe(Cores.marca), borderRadius: BorderRadius.circular(12)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.admin_panel_settings_rounded, color: Cores.marca, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Síndico: ${o.resposta}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ],
              ]),
            );
          }),
        ),
    ]);
  }
}

String nomeStatusSugestao(StatusSugestao s) => switch (s) {
      StatusSugestao.recebida => 'Recebida',
      StatusSugestao.emAvaliacao => 'Em avaliação',
      StatusSugestao.planejada => 'Planejada',
      StatusSugestao.implementada => 'Implementada',
      StatusSugestao.recusada => 'Não será feita',
    };

Color corStatusSugestao(StatusSugestao s) => switch (s) {
      StatusSugestao.recebida => Cores.textoSuave,
      StatusSugestao.emAvaliacao => Cores.reservada,
      StatusSugestao.planejada => Cores.marcaClara,
      StatusSugestao.implementada => Cores.livre,
      StatusSugestao.recusada => Cores.indisponivel,
    };

class SugestoesTela extends ConsumerWidget {
  const SugestoesTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextoAcaoProvider);
    final lista = (ref.watch(sugestoesProvider).value ?? const <Sugestao>[]).sortedBy<num>((s) => -s.votos);
    return PaginaMorador(
      titulo: 'Sugestões',
      subtitulo: 'Vote nas ideias que você quer ver',
      voltar: true,
      fab: ctx == null ? null : FloatingActionButton.extended(onPressed: () => _nova(context, ref, ctx), icon: const Icon(Icons.add_rounded), label: const Text('Nova sugestão')),
      filhos: [
        for (final s in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CartaoBase(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  IconButton.filledTonal(
                    isSelected: s.votadaPorMim,
                    selectedIcon: const Icon(Icons.thumb_up_alt_rounded),
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    onPressed: ctx == null ? null : () => ref.read(lavanderonRepositoryProvider).votarSugestao(s.id, ctx.quem),
                  ),
                  Text('${s.votos}', style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 6, children: [Selo(cor: corStatusSugestao(s.status), texto: nomeStatusSugestao(s.status)), Selo(cor: Cores.marca, texto: s.categoria)]),
                    const SizedBox(height: 8),
                    Text(s.titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text(s.descricao, style: const TextStyle(color: Cores.textoSuave)),
                    if (s.resposta != null) ...[
                      const SizedBox(height: 8),
                      Text('Resposta do síndico: ${s.resposta}', style: const TextStyle(fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  void _nova(BuildContext context, WidgetRef ref, ContextoAcao ctx) {
    final t = TextEditingController(), d = TextEditingController();
    var cat = 'Aplicativo';
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Nova sugestão'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, children: [
                for (final x in ['Aplicativo', 'Lavanderia', 'Regras', 'Outro']) ChoiceChip(label: Text(x), selected: cat == x, onSelected: (_) => set(() => cat = x)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: t, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 10),
              TextField(controller: d, maxLines: 3, decoration: const InputDecoration(labelText: 'Descreva a ideia')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            BotaoAcao(
              rotulo: 'Enviar',
              expandir: false,
              onPressed: () async {
                if (t.text.trim().isEmpty) return;
                await ref.read(lavanderonRepositoryProvider).criarSugestao(quem: ctx.quem, titulo: t.text.trim(), descricao: d.text.trim(), categoria: cat);
                if (c.mounted) Navigator.pop(c);
              },
              sucesso: 'Sugestão enviada!',
            ),
          ],
        ),
      ),
    );
  }
}
