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
  late _Opcao _op = widget.tipoInicial == TipoMaquina.secadora ? _Opcao.secar : _Opcao.lavar;
  TipoMaquina get _tipo => _op == _Opcao.secar ? TipoMaquina.secadora : TipoMaquina.lavadora;
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
    // Secadoras do horário seguinte (combo e sugestão "secar logo depois"). 23:00 → 00:00 do dia seguinte.
    final secHoje = _tipo == TipoMaquina.lavadora ? ref.watch(gradeProvider((dia, TipoMaquina.secadora))).value ?? const <SlotGrade>[] : const <SlotGrade>[];
    final secAmanha = _tipo == TipoMaquina.lavadora ? ref.watch(gradeProvider((dia.add(const Duration(days: 1)), TipoMaquina.secadora))).value ?? const <SlotGrade>[] : const <SlotGrade>[];
    int secadorasApos(SlotGrade s) {
      final x = [...secHoje, ...secAmanha].where((y) => y.inicio == s.fim).firstOrNull;
      return x == null || x.passado || x.fechado ? 0 : x.livres;
    }

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
      SegmentedButton<_Opcao>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact, padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4))),
        segments: [
          for (final o in _Opcao.values)
            ButtonSegment(
              value: o,
              label: Text(o.rotulo, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
              icon: MediaQuery.sizeOf(context).width < 460 && o == _Opcao.combo ? null : Icon(o.icone),
            ),
        ],
        selected: {_op},
        onSelectionChanged: (s) => setState(() => _op = s.first),
      ),
      if (_op == _Opcao.combo)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Reserve a lavadora e, no horário seguinte, uma secadora, de uma vez só.', style: TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 12),
      grade.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e'),
        data: (slots) {
          // Horários que já terminaram não aparecem. O horário em andamento vira o cartão "Agora".
          final futuros = slots.where((s) => s.fim.isAfter(agora)).toList();
          final atual = futuros.where((s) => !s.inicio.isAfter(agora)).firstOrNull;
          final proximos = futuros.where((s) => s.inicio.isAfter(agora)).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (atual != null) ...[
              const SizedBox(height: 6),
              _CartaoAgora(slot: atual, tipo: _tipo, agora: agora, habilitado: ctx != null && ativo),
            ],
            if (proximos.isEmpty)
              EstadoVazio(
                icone: Icons.event_busy_rounded,
                titulo: 'Não há mais horários neste dia',
                texto: 'Escolha o dia seguinte para ver os próximos horários.',
                acao: _diaIdx < dias - 1 ? 'Ver o próximo dia' : null,
                onAcao: () => setState(() => _diaIdx++),
              ),
            for (final (nome, h0, ic) in _periodos)
              if (proximos.any((s) => s.inicio.hour >= h0 && s.inicio.hour < h0 + 6)) ...[
                _CabecalhoPeriodo(nome: nome, icone: ic, key: _rolagem.putIfAbsent(nome, GlobalKey.new)),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
                  final lista = proximos.where((s) => s.inicio.hour >= h0 && s.inicio.hour < h0 + 6).toList();
                  return Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final s in lista)
                      SizedBox(
                        width: (c.maxWidth - (cols - 1) * 10) / cols,
                        child: _op == _Opcao.combo
                            ? _CelulaCombo(
                                slot: s,
                                secadoras: secadorasApos(s),
                                grande: widget.grande,
                                habilitado: ctx != null && ativo,
                                onTap: () => _confirmar(s, ctx!, secadorasDepois: secadorasApos(s), comboObrigatorio: true),
                              )
                            : _CelulaSlot(
                                slot: s,
                                grande: widget.grande,
                                habilitado: ctx != null && ativo,
                                onTap: () => _confirmar(s, ctx!, secadorasDepois: _tipo == TipoMaquina.lavadora ? secadorasApos(s) : 0),
                              ),
                      ),
                  ]);
                }),
              ],
          ]);
        },
      ),
    ]);
  }

  /// Confirmação da reserva. Para lavagem, oferece "Secar logo depois" (combo, RN-24)
  /// já marcado quando há secadora livre no horário seguinte.
  Future<void> _confirmar(SlotGrade s, ContextoAcao ctx, {int secadorasDepois = 0, bool comboObrigatorio = false}) async {
    String? escolhida;
    var combo = comboObrigatorio || secadorasDepois > 0;
    final podeCombo = s.tipo == TipoMaquina.lavadora && secadorasDepois > 0;
    final agora = ref.read(lavanderonRepositoryProvider).agoraAtual;
    final fimSec = s.fim.add(s.fim.difference(s.inicio));
    final r = await showModalBottomSheet<(Reserva, Reserva?)>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final livres = s.maquinas.where((m) => m.livre).toList();
        final fazendoCombo = combo && podeCombo;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(fazendoCombo ? 'Confirmar lavar + secar' : 'Confirmar reserva', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 6),
              LinhaInfo(iconeTipo(s.tipo), '${verboTipo(s.tipo)} · ${Fmt.intervalo(s.inicio, s.fim, agora)}'),
              if (fazendoCombo) LinhaInfo(Icons.dry_rounded, 'Secar · ${Fmt.hora(s.fim)}–${Fmt.hora(fimSec)} · secadora escolhida automaticamente'),
              if (comboObrigatorio && !podeCombo)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: FaixaAlerta(cor: Cores.reservada, icone: Icons.info_outline_rounded, titulo: 'Sem secadora livre no horário seguinte', texto: 'Dá para reservar só a lavagem, ou escolha outro horário.'),
                ),
              if (podeCombo && !comboObrigatorio) ...[
                const SizedBox(height: 10),
                CartaoBase(
                  raio: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  cor: combo ? Cores.fundoDe(Cores.agua) : Colors.white,
                  corBorda: combo ? Cores.agua : null,
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: combo,
                    onChanged: (v) => set(() => combo = v ?? false),
                    secondary: const Icon(Icons.dry_rounded, color: Color(0xFF00838F)),
                    title: Text('Secar logo depois · ${Fmt.hora(s.fim)}–${Fmt.hora(fimSec)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(secadorasDepois == 1 ? '1 secadora livre nesse horário' : '$secadorasDepois secadoras livres nesse horário'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(fazendoCombo ? 'Qual lavadora?' : 'Qual máquina?', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                rotulo: fazendoCombo ? 'Reservar lavar + secar' : (comboObrigatorio ? 'Reservar só a lavagem' : 'Confirmar'),
                icone: Icons.check_rounded,
                onPressed: () async {
                  final repo = ref.read(lavanderonRepositoryProvider);
                  if (fazendoCombo) {
                    final (lav, sec) = await repo.reservarCombo(quem: ctx.quem, inicioLavagem: s.inicio, lavadoraId: escolhida, origem: ctx.origem);
                    if (c.mounted) Navigator.pop(c, (lav, sec));
                  } else {
                    final res = await repo.reservar(quem: ctx.quem, inicio: s.inicio, tipo: s.tipo, maquinaId: escolhida, origem: ctx.origem);
                    if (c.mounted) Navigator.pop(c, (res, null));
                  }
                },
              ),
            ]),
          ),
        );
      }),
    );
    if (r == null || !mounted) return;
    final (principal, secagem) = r;
    mostrarSucesso(
      context,
      secagem == null
          ? 'Reservado! ${principal.maquinaNome}, ${Fmt.intervalo(principal.inicio, principal.fim, agora)}.'
          : 'Reservado! ${principal.maquinaNome} às ${Fmt.hora(principal.inicio)} e ${secagem.maquinaNome} às ${Fmt.hora(secagem.inicio)}.',
    );
    widget.aoReservar?.call(principal);
  }
}

enum _Opcao {
  lavar('Lavar', Icons.local_laundry_service_rounded),
  secar('Secar', Icons.dry_rounded),
  combo('Lavar + Secar', Icons.auto_awesome_rounded);

  const _Opcao(this.rotulo, this.icone);
  final String rotulo;
  final IconData icone;
}

/// Célula do combo: lavar às H → secar às H+1.
class _CelulaCombo extends StatelessWidget {
  const _CelulaCombo({required this.slot, required this.secadoras, required this.onTap, required this.habilitado, this.grande = false});
  final SlotGrade slot;
  final int secadoras;
  final VoidCallback onTap;
  final bool habilitado, grande;
  @override
  Widget build(BuildContext context) {
    final ok = slot.livres > 0 && secadoras > 0 && !slot.fechado;
    final cor = ok ? Cores.livre : (slot.livres > 0 ? Cores.reservada : Cores.problema);
    final status = ok ? 'Disponível' : (slot.livres == 0 ? 'Sem lavadora' : 'Sem secadora depois');
    return Opacity(
      opacity: ok ? 1 : 0.7,
      child: CartaoBase(
        onTap: habilitado && slot.livres > 0 ? onTap : null,
        raio: 14,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: grande ? 16 : 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                const Icon(Icons.local_laundry_service_rounded, size: 18, color: Cores.marca),
                Text(Fmt.hora(slot.inicio), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Cores.textoSuave),
                const Icon(Icons.dry_rounded, size: 18, color: Color(0xFF00838F)),
                Text(Fmt.hora(slot.fim), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
              ]),
              const SizedBox(height: 2),
              Text('${slot.livres} lavadora${slot.livres == 1 ? '' : 's'} · $secadoras secadora${secadoras == 1 ? '' : 's'}',
                  style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          Text(status, style: TextStyle(color: cor, fontWeight: FontWeight.w800)),
          if (habilitado && slot.livres > 0) const Icon(Icons.chevron_right, color: Cores.textoSuave),
        ]),
      ),
    );
  }
}

/// Horário em andamento: não dá para reservar, só usar agora uma máquina livre.
class _CartaoAgora extends ConsumerWidget {
  const _CartaoAgora({required this.slot, required this.tipo, required this.agora, required this.habilitado});
  final SlotGrade slot;
  final TipoMaquina tipo;
  final DateTime agora;
  final bool habilitado;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final livres = maquinasLivresAgora(ref.watch(maquinasProvider).value ?? const <Maquina>[], tipo);
    final ctx = ref.watch(contextoAcaoProvider);
    final cor = livres.isEmpty ? Cores.textoSuave : Cores.livre;
    final selo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(10)),
      child: const Text('AGORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
    final horario = Text('${Fmt.hora(slot.inicio)}–${Fmt.hora(slot.fim)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16));
    final texto = Text(
      livres.isEmpty
          ? 'Nenhuma ${nomeTipo(tipo).toLowerCase()} livre neste momento.'
          : '${livres.length == 1 ? '1 livre' : '${livres.length} livres'} agora. Este horário já começou: é só chegar e usar.',
      style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w600, fontSize: 13.5),
    );
    final botao = livres.isNotEmpty && habilitado && ctx != null
        ? FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Cores.livre),
            onPressed: () async {
              final m = await escolherMaquinaLivre(context, ref, tipo);
              if (m != null && context.mounted) await fluxoUsarAgora(context, ref, m, ctx);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Usar agora'),
          )
        : null;

    return CartaoBase(
      corBorda: cor.withValues(alpha: 0.5),
      cor: Cores.fundoDe(cor),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, c) {
        // Celular: empilhado (selo + horário, texto, botão largo). Tela larga: em linha.
        if (c.maxWidth < 520) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [selo, const SizedBox(width: 12), horario]),
            const SizedBox(height: 8),
            texto,
            if (botao != null) ...[const SizedBox(height: 12), botao],
          ]);
        }
        return Row(children: [
          selo,
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [horario, texto])),
          if (botao != null) ...[const SizedBox(width: 10), botao],
        ]);
      }),
    );
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
