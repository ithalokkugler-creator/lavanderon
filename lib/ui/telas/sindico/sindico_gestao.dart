import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio.dart';
import '../../tema/tema.dart';
import '../../widgets/base.dart';
import '../morador/conteudo_telas.dart';
import 'sindico_shell.dart';

// ───────────────────────── Apartamentos ─────────────────────────

class ApartamentosSindicoTela extends ConsumerStatefulWidget {
  const ApartamentosSindicoTela({super.key});
  @override
  ConsumerState<ApartamentosSindicoTela> createState() => _ApartamentosState();
}

class _ApartamentosState extends ConsumerState<ApartamentosSindicoTela> {
  String? _sel;
  @override
  Widget build(BuildContext context) {
    final aptos = ref.watch(apartamentosProvider).value ?? const <Apartamento>[];
    final moradores = ref.watch(moradoresProvider).value ?? const <Morador>[];
    final existentes = aptos.where((a) => a.existe).toList();
    final ativos = existentes.where((a) => a.ativo).length;
    final sel = aptos.firstWhereOrNull((a) => a.id == _sel);
    final repo = ref.read(lavanderonRepositoryProvider);

    final grade = CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Toque num apartamento para ver os moradores e ativar ou suspender o acesso.', style: TextStyle(color: Cores.textoSuave)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(children: [
            for (var andar = 6; andar >= 1; andar--)
              Row(children: [
                SizedBox(width: 44, child: Text('$andarº', style: const TextStyle(fontWeight: FontWeight.w900, color: Cores.textoSuave))),
                for (var f = 1; f <= 20; f++)
                  Builder(builder: (_) {
                    final id = '$andar${f.toString().padLeft(2, '0')}';
                    final a = aptos.firstWhereOrNull((x) => x.id == id);
                    final existe = a?.existe ?? false;
                    final ativo = a?.ativo ?? false;
                    final cor = !existe ? Cores.borda : (ativo ? Cores.livre : Cores.problema);
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: existe ? () => setState(() => _sel = id) : null,
                        child: Container(
                          width: 44,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !existe ? const Color(0xFFF1F3F7) : Cores.fundoDe(cor),
                            border: Border.all(color: _sel == id ? Cores.marca : cor.withValues(alpha: existe ? 0.6 : 1), width: _sel == id ? 2.5 : 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(id, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: existe ? cor : Cores.textoFraco)),
                        ),
                      ),
                    );
                  }),
              ]),
          ]),
        ),
        const SizedBox(height: 12),
        const Wrap(spacing: 14, children: [
          _Ponto(Cores.livre, 'Ativo (paga)'),
          _Ponto(Cores.problema, 'Suspenso'),
          _Ponto(Cores.textoFraco, 'Número não existe'),
        ]),
      ]),
    );

    final detalhe = sel == null
        ? const CartaoBase(child: EstadoVazio(icone: Icons.touch_app_rounded, titulo: 'Selecione um apartamento'))
        : CartaoBase(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('Apartamento ${sel.id}', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Selo(cor: sel.ativo ? Cores.livre : Cores.problema, texto: sel.ativo ? 'Ativo' : 'Suspenso', forte: true),
              ]),
              Text('${sel.andar}º andar', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text('Moradores', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final m in moradores.where((m) => m.aptoId == sel.id)) LinhaInfo(Icons.person_rounded, m.nome),
              if (!moradores.any((m) => m.aptoId == sel.id)) const Text('Nenhum morador cadastrado.', style: TextStyle(color: Cores.textoSuave)),
              const SizedBox(height: 16),
              BotaoAcao(
                rotulo: sel.ativo ? 'Suspender (não pagou)' : 'Ativar (pagou a mensalidade)',
                icone: sel.ativo ? Icons.block_rounded : Icons.check_circle_rounded,
                cor: sel.ativo ? Cores.problema : Cores.livre,
                onPressed: () => repo.definirAptoAtivo(sel.id, !sel.ativo),
                sucesso: sel.ativo ? 'Ap ${sel.id} suspenso.' : 'Ap ${sel.id} ativado.',
              ),
            ]),
          );

    return PaginaSindico(
      titulo: 'Apartamentos',
      subtitulo: '${existentes.length} apartamentos · $ativos ativos · ${existentes.length - ativos} suspensos · ${moradores.length} moradores',
      filhos: [
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 1150) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: grade), const SizedBox(width: 18), SizedBox(width: 340, child: detalhe)]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [grade, const SizedBox(height: 14), detalhe]);
        }),
      ],
    );
  }
}

class _Ponto extends StatelessWidget {
  const _Ponto(this.cor, this.t);
  final Color cor;
  final String t;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: Cores.fundoDe(cor), border: Border.all(color: cor), borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]);
}

// ───────────────────────── Comunicados ─────────────────────────

class ComunicadosSindicoTela extends ConsumerWidget {
  const ComunicadosSindicoTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final lista = (ref.watch(noticiasProvider).value ?? const <Noticia>[]).sortedBy((n) => n.publicadaEm).reversed.toList();
    return PaginaSindico(
      titulo: 'Comunicados',
      subtitulo: 'Aparecem na aba Notícias dos moradores',
      fab: FloatingActionButton.extended(onPressed: () => _novo(context, ref), icon: const Icon(Icons.edit_rounded), label: const Text('Novo comunicado')),
      filhos: [
        for (final n in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Stack(children: [
              CartaoNoticia(noticia: n, agora: agora),
              Positioned(right: 16, bottom: 14, child: Text('${n.leituras} leituras', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w800, fontSize: 12.5))),
            ]),
          ),
      ],
    );
  }

  void _novo(BuildContext context, WidgetRef ref) {
    final titulo = TextEditingController(), corpo = TextEditingController();
    var prio = PrioridadeNoticia.informativo;
    var fixar = false;
    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Novo comunicado'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, children: [
                  for (final p in PrioridadeNoticia.values)
                    ChoiceChip(label: Text(visualPrioridade(p).$3), selected: prio == p, onSelected: (_) => set(() => prio = p)),
                  FilterChip(label: const Text('Fixar no topo'), selected: fixar, onSelected: (v) => set(() => fixar = v)),
                ]),
                const SizedBox(height: 14),
                TextField(controller: titulo, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 10),
                TextField(
                  controller: corpo,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Texto', hintText: 'Use linha em branco entre parágrafos, "## " para subtítulo e "- " para lista.', alignLabelWithHint: true),
                ),
                const SizedBox(height: 10),
                Text(prio == PrioridadeNoticia.urgente ? 'Urgente: todos recebem notificação e uma faixa aparece no início até lerem.' : 'Os moradores recebem notificação (informativos respeitam o horário silencioso das 22:00 às 07:00).',
                    style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            BotaoAcao(
              rotulo: 'Publicar',
              expandir: false,
              onPressed: () async {
                if (titulo.text.trim().isEmpty) return;
                await ref.read(lavanderonRepositoryProvider).publicarNoticia(titulo: titulo.text.trim(), corpo: corpo.text.trim(), prioridade: prio, fixada: fixar);
                if (c.mounted) Navigator.pop(c);
              },
              sucesso: 'Comunicado publicado.',
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Estatísticas ─────────────────────────

class EstatisticasSindicoTela extends ConsumerWidget {
  const EstatisticasSindicoTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final est = ref.watch(estatisticasProvider);
    return PaginaSindico(
      titulo: 'Estatísticas',
      subtitulo: 'Últimos 30 dias',
      acoes: [OutlinedButton.icon(onPressed: () => mostrarSucesso(context, 'No sistema real, gera um CSV para a prestação de contas.'), icon: const Icon(Icons.download_rounded), label: const Text('Exportar CSV'))],
      filhos: [
        est.when(
          loading: () => const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (e) => _Conteudo(e),
        ),
      ],
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo(this.e);
  final Estatisticas e;
  @override
  Widget build(BuildContext context) {
    final total = e.reservas30d.fold<int>(0, (s, x) => s + x.$2);
    final abertas = e.ocorrenciasAbertas.values.fold<int>(0, (s, x) => s + x);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LinhaResponsiva(filhos: [
        Kpi(valor: '$total', rotulo: 'reservas em 30 dias', icone: Icons.event_rounded, cor: Cores.marca),
        Kpi(valor: '${(e.taxaComparecimento30d * 100).round()}%', rotulo: 'comparecimento (meta 80%)', icone: Icons.verified_rounded, cor: e.taxaComparecimento30d >= 0.8 ? Cores.livre : Cores.reservada),
        Kpi(valor: '${(e.ocupacaoHoje * 100).round()}%', rotulo: 'ocupação hoje', icone: Icons.donut_large_rounded, cor: Cores.agua),
        Kpi(valor: '$abertas', rotulo: 'ocorrências abertas', icone: Icons.assignment_late_rounded, cor: Cores.problema),
      ]),
      const SizedBox(height: 18),
      CartaoBase(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reservas por dia', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              maxY: (e.reservas30d.fold<int>(1, (m, x) => math.max(m, x.$2)) * 1.2).ceilToDouble(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Cores.borda, strokeWidth: 1)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox() : Text(v.toInt().toString(), style: const TextStyle(fontSize: 11, color: Cores.textoSuave)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= e.reservas30d.length || (e.reservas30d.length - 1 - i) % 5 != 0) return const SizedBox();
                      final d = e.reservas30d[i].$1;
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 11, color: Cores.textoSuave)));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (i, x) in e.reservas30d.indexed)
                  BarChartGroupData(x: i, barRods: [BarChartRodData(toY: x.$2.toDouble(), color: Cores.marca, width: 9, borderRadius: BorderRadius.circular(3))]),
              ],
            )),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, c) {
        final mapa = _MapaCalor(e.mapaCalor);
        final uso = _UsoMaquinas(e.usoPorMaquina30d);
        return c.maxWidth >= 1000
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: mapa), const SizedBox(width: 18), Expanded(flex: 2, child: uso)])
            : Column(children: [mapa, const SizedBox(height: 18), uso]);
      }),
      const SizedBox(height: 18),
      CartaoBase(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Apartamentos que mais usam', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final (i, (apto, n, ns)) in e.topAptos.take(8).indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${i + 1}º', style: const TextStyle(fontWeight: FontWeight.w900, color: Cores.textoSuave))),
                SizedBox(width: 70, child: Text('Ap $apto', style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(minHeight: 10, value: n / math.max(1, e.topAptos.first.$2), color: Cores.marca, backgroundColor: Cores.fundo),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 90, child: Text('$n reservas', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                SizedBox(width: 100, child: Text(ns == 0 ? '' : '$ns faltas', textAlign: TextAlign.right, style: const TextStyle(color: Cores.problema, fontWeight: FontWeight.w800))),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _MapaCalor extends StatelessWidget {
  const _MapaCalor(this.dados);
  final List<List<int>> dados;
  static const _dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  @override
  Widget build(BuildContext context) {
    final max = dados.expand((x) => x).fold<int>(1, math.max);
    return CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quando a lavanderia lota', style: Theme.of(context).textTheme.titleMedium),
        const Text('Reservas por dia da semana e hora. Bom para escolher horário de manutenção.', style: TextStyle(color: Cores.textoSuave, fontSize: 13)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cel = ((c.maxWidth - 40) / 24).clamp(8.0, 30.0);
          return Column(children: [
            for (var d = 0; d < 7; d++)
              Row(children: [
                SizedBox(width: 40, child: Text(_dias[d], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Cores.textoSuave))),
                for (var h = 0; h < 24; h++)
                  Tooltip(
                    message: '${_dias[d]} ${h.toString().padLeft(2, '0')}h: ${d < dados.length && h < dados[d].length ? dados[d][h] : 0} reservas',
                    child: Container(
                      width: cel - 2,
                      height: 20,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Color.lerp(const Color(0xFFEFF4FB), Cores.marca, (d < dados.length && h < dados[d].length ? dados[d][h] : 0) / max),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ]),
            const SizedBox(height: 4),
            Row(children: [
              const SizedBox(width: 40),
              for (final h in [0, 6, 12, 18]) SizedBox(width: cel * 6, child: Text('${h}h', style: const TextStyle(fontSize: 11, color: Cores.textoSuave))),
            ]),
          ]);
        }),
      ]),
    );
  }
}

class _UsoMaquinas extends StatelessWidget {
  const _UsoMaquinas(this.uso);
  final Map<String, int> uso;
  @override
  Widget build(BuildContext context) {
    final lista = uso.entries.sortedBy((e) => e.key);
    final max = lista.fold<int>(1, (m, e) => math.max(m, e.value));
    return CartaoBase(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Uso por máquina', style: Theme.of(context).textTheme.titleMedium),
        const Text('Equilíbrio de desgaste', style: TextStyle(color: Cores.textoSuave, fontSize: 13)),
        const SizedBox(height: 12),
        for (final e in lista)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 96, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 9, value: e.value / max, color: Cores.agua, backgroundColor: Cores.fundo))),
              SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
      ]),
    );
  }
}

// ───────────────────────── Configurações ─────────────────────────

class ConfigSindicoTela extends ConsumerWidget {
  const ConfigSindicoTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(configProvider).value;
    if (c == null) return const PaginaSindico(titulo: 'Configurações', filhos: []);
    Widget grupo(String titulo, IconData ic, List<(String, String)> itens) => CartaoBase(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(ic, color: Cores.marca), const SizedBox(width: 10), Text(titulo, style: Theme.of(context).textTheme.titleMedium)]),
            const SizedBox(height: 10),
            for (final (k, v) in itens)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(v, style: const TextStyle(fontWeight: FontWeight.w900, color: Cores.marca)),
                ]),
              ),
          ]),
        );
    String progs(TipoMaquina t) => (c.programas[t] ?? const <Programa>[]).map((p) => '${p.nome} ${p.minutos}').join(' · ');
    return PaginaSindico(
      titulo: 'Configurações',
      subtitulo: 'Regras da lavanderia (no sistema real, todas editáveis aqui)',
      filhos: [
        LinhaResponsiva(minLargura: 380, filhos: [
          grupo('Funcionamento', Icons.schedule_rounded, [('Horário', '24 h, todos os dias'), ('Duração do horário', '${c.slotMin} min'), ('Antecedência máxima', '${c.antecedenciaDias} dias')]),
          grupo('Limites por apartamento', Icons.apartment_rounded, [('Lavagens por dia', '${c.lavagensDia}'), ('Secagens por dia', '${c.secagensDia}'), ('Reservas futuras', '${c.futurasMax}')]),
          grupo('Confirmação de uso', Icons.task_alt_rounded, [('Pode confirmar a partir de', '${c.checkinAntesMin} min antes'), ('Tolerância de atraso', '${c.toleranciaMin} min'), ('Aviso antes de ficar pronta', '${c.avisoAntesMin} min')]),
          grupo('Cronômetro', Icons.timer_rounded, [('Lavadora', progs(TipoMaquina.lavadora)), ('Secadora', progs(TipoMaquina.secadora))]),
          grupo('Roupas e conduta', Icons.inventory_2_rounded, [('Prazo para retirar a roupa', '${c.prazoRetiradaMin} min'), ('Advertências e suspensões', 'Não aplicadas'), ('Aviso "síndico foi informado"', 'Automático se confiável')]),
          grupo('Problemas', Icons.build_rounded, [('Bloqueio noturno', '${c.bloqueioNoturnoDe} → ${c.bloqueioNoturnoAte}'), ('Realocação automática', 'Ligada'), ('Grade mostra apartamento', 'Sim')]),
        ]),
        const SizedBox(height: 16),
        CartaoBase(
          cor: Cores.fundoDe(Cores.agua),
          child: Row(children: [
            const Icon(Icons.group_rounded, color: Cores.pronta),
            const SizedBox(width: 12),
            const Expanded(child: Text('Administradores: síndico, subsíndicos e zelador. Só o síndico adiciona ou remove administradores.', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
    );
  }
}
