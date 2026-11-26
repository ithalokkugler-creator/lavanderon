import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../estado.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/maquina_widgets.dart';
import 'shell_morador.dart';

/// Reservar em 3 toques: dia → tipo → horário (seção 6.4). Reutilizado no tablet.
class ReservarTela extends ConsumerWidget {
  const ReservarTela({super.key, this.tipoInicial});
  final TipoMaquina? tipoInicial;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PaginaMorador(
        titulo: 'Reservar',
        subtitulo: 'Escolha o dia, o tipo e o horário',
        filhos: [GradeReserva(tipoInicial: tipoInicial, aoReservar: (r) => context.go('/m/reserva/${r.id}'))],
      );
}

class GradeReserva extends ConsumerStatefulWidget {
  const GradeReserva({super.key, this.tipoInicial, this.aoReservar, this.grande = false});
  final TipoMaquina? tipoInicial;
  final void Function(Reserva)? aoReservar;
  final bool grande;
  @override
  ConsumerState<GradeReserva> createState() => _GradeReservaState();
}

class _GradeReservaState extends ConsumerState<GradeReserva> {
  int _diaIdx = 0;
  late TipoMaquina _tipo = widget.tipoInicial ?? TipoMaquina.lavadora;
  final _rolagem = <String, GlobalKey>{};

  static const _periodos = [('Madrugada', 0, Icons.bedtime_rounded), ('Manhã', 6, Icons.wb_twilight_rounded), ('Tarde', 12, Icons.wb_sunny_rounded), ('Noite', 18, Icons.nights_stay_rounded)];

  @override
  Widget build(BuildContext context) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final cfg = ref.watch(configProvider).value;
    final dias = cfg?.antecedenciaDias ?? 7;
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = hoje.add(Duration(days: _diaIdx));
    final grade = ref.watch(gradeProvider((dia, _tipo)));
    final ctx = ref.watch(contextoAcaoProvider);
    final ativo = ref.watch(aptoAtivoProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!ativo) const Padding(padding: EdgeInsets.only(bottom: 12), child: FaixaAlerta(cor: Cores.problema, icone: Icons.block_rounded, titulo: 'Reservas indisponíveis', texto: 'A lavanderia não está ativa para o seu apartamento.')),
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dias,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final d = hoje.add(Duration(days: i));
            final sel = i == _diaIdx;
            return _ChipDia(rotulo: i == 0 ? 'Hoje' : (i == 1 ? 'Amanhã' : Fmt.dataCurta(d).split(',').first), sub: '${d.day}/${d.month}', selecionado: sel, onTap: () => setState(() => _diaIdx = i));
          },
        ),
      ),
      const SizedBox(height: 14),
      SegmentedButton<TipoMaquina>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: TipoMaquina.lavadora, label: Text('Lavar'), icon: Icon(Icons.local_laundry_service_rounded)),
          ButtonSegment(value: TipoMaquina.secadora, label: Text('Secar'), icon: Icon(Icons.dry_rounded)),
        ],
        selected: {_tipo},
        onSelectionChanged: (s) => setState(() => _tipo = s.first),
      ),
      const SizedBox(height: 12),
      grade.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e'),
        data: (slots) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (nome, h0, ic) in _periodos) ...[
            _CabecalhoPeriodo(nome: nome, icone: ic, key: _rolagem.putIfAbsent(nome, GlobalKey.new)),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
              final lista = slots.where((s) => s.inicio.hour >= h0 && s.inicio.hour < h0 + 6).toList();
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final s in lista)
                  SizedBox(
                    width: (c.maxWidth - (cols - 1) * 10) / cols,
                    child: _CelulaSlot(
                      slot: s,
                      grande: widget.grande,
                      habilitado: ctx != null && ativo,
                      onTap: () => _confirmar(s, ctx!),
                    ),
                  ),
              ]);
            }),
          ],
        ]),
      ),
    ]);
  }

  Future<void> _confirmar(SlotGrade s, ContextoAcao ctx) async {
    String? escolhida;
    final agora = ref.read(lavanderonRepositoryProvider).agoraAtual;
    final r = await showModalBottomSheet<Reserva>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final livres = s.maquinas.where((m) => m.livre).toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Confirmar reserva', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 6),
              LinhaInfo(iconeTipo(s.tipo), '${verboTipo(s.tipo)} · ${Fmt.intervalo(s.inicio, s.fim, agora)}'),
              const SizedBox(height: 12),
              RadioGroup<String?>(
                groupValue: escolhida,
                onChanged: (v) => set(() => escolhida = v),
                child: Column(children: [
                  const RadioListTile<String?>(value: null, title: Text('Qualquer máquina', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Escolhemos a menos usada no mês')),
                  for (final m in livres) RadioListTile<String?>(value: m.maquinaId, title: Text(m.nome)),
                ]),
              ),
              const SizedBox(height: 12),
              BotaoAcao(
                rotulo: 'Confirmar',
                icone: Icons.check_rounded,
                onPressed: () async {
                  final res = await ref.read(lavanderonRepositoryProvider).reservar(quem: ctx.quem, inicio: s.inicio, tipo: s.tipo, maquinaId: escolhida, origem: ctx.origem);
                  if (c.mounted) Navigator.pop(c, res);
                },
              ),
            ]),
          ),
        );
      }),
    );
    if (r == null || !mounted) return;
    mostrarSucesso(context, 'Reservado! ${r.maquinaNome}, ${Fmt.intervalo(r.inicio, r.fim, agora)}.');
    widget.aoReservar?.call(r);
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.rotulo, required this.sub, required this.selecionado, required this.onTap});
  final String rotulo, sub;
  final bool selecionado;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 84,
        child: CartaoBase(
          onTap: onTap,
          raio: 16,
          padding: const EdgeInsets.symmetric(vertical: 10),
          cor: selecionado ? Cores.marca : Colors.white,
          corBorda: selecionado ? Cores.marca : null,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(rotulo, style: TextStyle(fontWeight: FontWeight.w900, color: selecionado ? Colors.white : Cores.texto)),
            Text(sub, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selecionado ? Colors.white70 : Cores.textoSuave)),
          ]),
        ),
      );
}

class _CabecalhoPeriodo extends StatelessWidget {
  const _CabecalhoPeriodo({super.key, required this.nome, required this.icone});
  final String nome;
  final IconData icone;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 10),
        child: Row(children: [
          Icon(icone, size: 18, color: Cores.textoSuave),
          const SizedBox(width: 8),
          Text(nome.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Cores.textoSuave, fontSize: 12.5)),
        ]),
      );
}

class _CelulaSlot extends StatelessWidget {
  const _CelulaSlot({required this.slot, required this.onTap, required this.habilitado, this.grande = false});
  final SlotGrade slot;
  final VoidCallback onTap;
  final bool habilitado, grande;
  @override
  Widget build(BuildContext context) {
    final indisponivel = slot.passado || slot.fechado;
    final lotado = !indisponivel && slot.livres == 0;
    final cor = indisponivel ? Cores.textoFraco : (lotado ? Cores.problema : (slot.livres <= 1 ? Cores.reservada : Cores.livre));
    final texto = slot.fechado ? 'Fechada' : (slot.passado ? 'Passou' : (lotado ? 'Lotado' : (slot.livres == 1 ? '1 livre' : '${slot.livres} livres')));
    final pode = habilitado && !indisponivel && !lotado;
    return Opacity(
      opacity: indisponivel ? 0.55 : 1,
      child: CartaoBase(
        onTap: pode ? onTap : null,
        raio: 14,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: grande ? 18 : 13),
        child: Row(children: [
          Text('${Fmt.hora(slot.inicio)}–${Fmt.hora(slot.fim)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: grande ? 18 : 15.5)),
          const Spacer(),
          if (!indisponivel)
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < slot.total; i++)
                Container(
                  width: 6,
                  height: 14,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(color: i < slot.livres ? cor : Cores.borda, borderRadius: BorderRadius.circular(2)),
                ),
              const SizedBox(width: 10),
            ]),
          Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w800)),
          if (pode) const Icon(Icons.chevron_right, color: Cores.textoSuave),
        ]),
      ),
    );
  }
}
