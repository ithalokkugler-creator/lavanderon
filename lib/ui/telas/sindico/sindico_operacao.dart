import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio.dart';
import '../../tema/tema.dart';
import '../../util/fmt.dart';
import '../../widgets/base.dart';
import '../../widgets/maquina_widgets.dart';
import '../../widgets/reserva_widgets.dart';
import '../morador/mais_telas.dart';
import 'sindico_shell.dart';

/// Ações do síndico sobre uma máquina (bloquear, liberar, manutenção).
Future<void> acoesMaquina(BuildContext context, WidgetRef ref, Maquina m) {
  final repo = ref.read(lavanderonRepositoryProvider);
  final agora = repo.agoraAtual;
  final v = visualMaquina(m, agora);
  return showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconeMaquina(m.tipo, cor: v.cor, tamanho: 50),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.nome, style: Theme.of(c).textTheme.titleLarge), Text(v.detalhe, style: const TextStyle(color: Cores.textoSuave))])),
            Selo(cor: v.cor, texto: v.rotulo, icone: v.icone),
          ]),
          const SizedBox(height: 18),
          if (m.status == StatusMaquina.disponivel) ...[
            BotaoAcao(
              rotulo: 'Bloquear hoje',
              icone: Icons.block_rounded,
              cor: Cores.problema,
              onPressed: () async {
                final motivo = await _pedirTexto(c, 'Motivo do bloqueio', 'Ex.: técnico vem amanhã às 10h');
                if (motivo == null) return;
                await repo.bloquearMaquina(m.id, motivo);
                if (c.mounted) Navigator.pop(c);
              },
              sucesso: '${m.nome} bloqueada. Reservas afetadas foram tratadas.',
            ),
            const SizedBox(height: 10),
            BotaoAcao(
              rotulo: 'Colocar em manutenção',
              icone: Icons.build_rounded,
              estilo: EstiloBotao.contorno,
              onPressed: () async {
                final motivo = await _pedirTexto(c, 'Motivo da manutenção', 'Ex.: troca da correia');
                if (motivo == null) return;
                await repo.colocarManutencao(m.id, motivo, agora.add(const Duration(days: 5)));
                if (c.mounted) Navigator.pop(c);
              },
              sucesso: '${m.nome} em manutenção (previsão em 5 dias).',
            ),
          ],
          if (m.status == StatusMaquina.bloqueadaHoje)
            BotaoAcao(rotulo: 'Liberar máquina', icone: Icons.lock_open_rounded, cor: Cores.livre, onPressed: () async {
              await repo.liberarMaquina(m.id);
              if (c.mounted) Navigator.pop(c);
            }, sucesso: '${m.nome} liberada.'),
          if (m.status == StatusMaquina.manutencao)
            BotaoAcao(rotulo: 'Voltar à circulação', icone: Icons.replay_rounded, cor: Cores.livre, onPressed: () async {
              await repo.voltarCirculacao(m.id);
              if (c.mounted) Navigator.pop(c);
            }, sucesso: '${m.nome} de volta.'),
        ]),
      ),
    ),
  );
}

Future<String?> _pedirTexto(BuildContext context, String titulo, String dica) {
  final t = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: SizedBox(width: 400, child: TextField(controller: t, autofocus: true, decoration: InputDecoration(hintText: dica))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, t.text.trim().isEmpty ? titulo : t.text.trim()), child: const Text('Confirmar')),
      ],
    ),
  );
}

// ───────────────────────── Ocorrências ─────────────────────────

IconData iconeTipoOcorrencia(TipoOcorrencia t) => switch (t) {
      TipoOcorrencia.maquina => Icons.build_circle_rounded,
      TipoOcorrencia.lavanderia => Icons.home_repair_service_rounded,
      TipoOcorrencia.usoIndevido => Icons.report_rounded,
      TipoOcorrencia.roupaEsquecida => Icons.checkroom_rounded,
      TipoOcorrencia.roupaRetirada => Icons.inventory_2_rounded,
    };

class CartaoOcorrencia extends ConsumerWidget {
  const CartaoOcorrencia({super.key, required this.ocorrencia, required this.agora, this.compacto = false});
  final Ocorrencia ocorrencia;
  final DateTime agora;
  final bool compacto;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ocorrencia;
    final (st, cor) = visualStatusOcorrencia(o.status);
    return CartaoBase(
      corBorda: o.urgente ? Cores.problema.withValues(alpha: 0.5) : null,
      onTap: () => _detalhe(context, ref, o),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Cores.fundoDe(o.urgente ? Cores.problema : Cores.marca), borderRadius: BorderRadius.circular(12)),
          child: Icon(iconeTipoOcorrencia(o.tipo), color: o.urgente ? Cores.problema : Cores.marca, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${o.categoria}${o.maquinaNome == null ? '' : ' · ${o.maquinaNome}'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (o.urgente) const Selo(cor: Cores.problema, texto: 'Urgente', forte: true),
              if (o.bloqueouMaquina) const Selo(cor: Cores.problema, texto: 'Bloqueou'),
              if (o.confirmacoes > 1) Selo(cor: Cores.marca, texto: '+${o.confirmacoes - 1} confirmaram'),
            ]),
            const SizedBox(height: 2),
            Text('${nomeTipoOcorrencia(o.tipo)} · Ap ${o.relatorApto ?? '—'} (${o.relatorNome}) · ${Fmt.relativo(o.criadaEm, agora)}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (!compacto && o.deducao != null) ...[
              const SizedBox(height: 6),
              Text('Dedução: ${o.deducao}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
        Selo(cor: cor, texto: st),
      ]),
    );
  }

  void _detalhe(BuildContext context, WidgetRef ref, Ocorrencia o) {
    final repo = ref.read(lavanderonRepositoryProvider);
    final resp = TextEditingController(text: o.resposta);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(o.categoria, style: Theme.of(c).textTheme.titleLarge),
            Text('${nomeTipoOcorrencia(o.tipo)}${o.maquinaNome == null ? '' : ' · ${o.maquinaNome}'}', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            LinhaInfo(Icons.person_rounded, 'Relatado por ${o.relatorNome} · Ap ${o.relatorApto ?? '—'} · ${nomeOrigem(o.origem)}'),
            LinhaInfo(Icons.schedule_rounded, '${Fmt.dataLonga(o.criadaEm)} às ${Fmt.hora(o.criadaEm)}'),
            if (o.descricao != null) LinhaInfo(Icons.notes_rounded, o.descricao!),
            if (o.deducao != null) ...[
              const SizedBox(height: 10),
              FaixaAlerta(
                cor: Cores.semRegistro,
                icone: Icons.psychology_alt_rounded,
                titulo: o.deducaoConfiavel ? 'Dedução do sistema (confiável)' : 'Dedução do sistema (só uma pista)',
                texto: '${o.deducao}${o.aptoProvavel == null ? '' : ' · Ap provável: ${o.aptoProvavel}'}',
              ),
            ],
            if (o.respostaApto != null) ...[const SizedBox(height: 10), FaixaAlerta(cor: Cores.marca, icone: Icons.reply_rounded, titulo: 'Resposta do apartamento', texto: o.respostaApto)],
            const SizedBox(height: 14),
            if (o.aptoProvavel != null)
              o.avisoCondutaEnviado
                  ? const LinhaInfo(Icons.mark_email_read_rounded, 'Aviso de conduta já enviado ("o síndico foi informado")', cor: Cores.livre)
                  : BotaoAcao(
                      rotulo: 'Avisar o Ap ${o.aptoProvavel} ("o síndico foi informado")',
                      icone: Icons.gavel_rounded,
                      estilo: EstiloBotao.contorno,
                      cor: Cores.semRegistro,
                      onPressed: () async {
                        await repo.enviarAvisoConduta(o.id);
                        if (c.mounted) Navigator.pop(c);
                      },
                      sucesso: 'Aviso de conduta enviado. Não é penalidade.',
                    ),
            const SizedBox(height: 14),
            TextField(controller: resp, maxLines: 2, decoration: const InputDecoration(labelText: 'Resposta ao morador')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: BotaoAcao(rotulo: 'Em andamento', estilo: EstiloBotao.contorno, onPressed: () async {
                await repo.atualizarOcorrencia(o.id, StatusOcorrencia.emAndamento, resposta: resp.text.isEmpty ? null : resp.text);
                if (c.mounted) Navigator.pop(c);
              })),
              const SizedBox(width: 10),
              Expanded(child: BotaoAcao(rotulo: 'Resolvida', cor: Cores.livre, onPressed: () async {
                await repo.atualizarOcorrencia(o.id, StatusOcorrencia.resolvida, resposta: resp.text.isEmpty ? null : resp.text);
                if (c.mounted) Navigator.pop(c);
              }, sucesso: 'Ocorrência resolvida. O morador foi avisado.')),
            ]),
            TextButton(onPressed: () async {
              await repo.atualizarOcorrencia(o.id, StatusOcorrencia.descartada, resposta: resp.text.isEmpty ? null : resp.text);
              if (c.mounted) Navigator.pop(c);
            }, child: const Text('Descartar (relato indevido ou duplicado)')),
          ]),
        ),
      ),
    );
  }
}

class OcorrenciasSindicoTela extends ConsumerStatefulWidget {
  const OcorrenciasSindicoTela({super.key});
  @override
  ConsumerState<OcorrenciasSindicoTela> createState() => _OcorrenciasSindicoState();
}

class _OcorrenciasSindicoState extends ConsumerState<OcorrenciasSindicoTela> {
  TipoOcorrencia? _tipo;
  bool _soAbertas = true;
  @override
  Widget build(BuildContext context) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final todas = ref.watch(ocorrenciasProvider).value ?? const <Ocorrencia>[];
    final lista = todas
        .where((o) => _tipo == null || o.tipo == _tipo)
        .where((o) => !_soAbertas || o.status == StatusOcorrencia.aberta || o.status == StatusOcorrencia.emAndamento)
        .sortedBy((o) => o.criadaEm)
        .reversed
        .toList();
    return PaginaSindico(titulo: 'Ocorrências', subtitulo: 'Problemas, uso indevido e roupas', filhos: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilterChip(label: const Text('Só abertas'), selected: _soAbertas, onSelected: (v) => setState(() => _soAbertas = v)),
        const SizedBox(width: 8),
        ChoiceChip(label: const Text('Todas'), selected: _tipo == null, onSelected: (_) => setState(() => _tipo = null)),
        for (final t in TipoOcorrencia.values)
          ChoiceChip(
            avatar: Icon(iconeTipoOcorrencia(t), size: 18, color: _tipo == t ? Colors.white : Cores.marca),
            label: Text('${nomeTipoOcorrencia(t)} (${todas.where((o) => o.tipo == t).length})'),
            selected: _tipo == t,
            onSelected: (_) => setState(() => _tipo = t),
          ),
      ]),
      const SizedBox(height: 16),
      if (lista.isEmpty) const EstadoVazio(icone: Icons.assignment_turned_in_rounded, titulo: 'Nada por aqui'),
      for (final o in lista) Padding(padding: const EdgeInsets.only(bottom: 10), child: CartaoOcorrencia(ocorrencia: o, agora: agora)),
    ]);
  }
}

// ───────────────────────── Máquinas ─────────────────────────

class MaquinasSindicoTela extends ConsumerWidget {
  const MaquinasSindicoTela({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final maquinas = (ref.watch(maquinasProvider).value ?? const <Maquina>[]).sortedBy((m) => '${m.tipo.index}${m.ordem.toString().padLeft(2, '0')}');
    return PaginaSindico(titulo: 'Máquinas', subtitulo: '6 lavadoras e 6 secadoras', filhos: [
      for (final m in maquinas)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Builder(builder: (context) {
            final v = visualMaquina(m, agora);
            return CartaoBase(
              onTap: () => acoesMaquina(context, ref, m),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                IconeMaquina(m.tipo, cor: v.cor, tamanho: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text('${v.detalhe} · ciclo ${Fmt.minutos(m.cicloMin)}', style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
                  ]),
                ),
                Selo(cor: v.cor, icone: v.icone, texto: v.rotulo),
                const SizedBox(width: 6),
                const Icon(Icons.more_vert_rounded, color: Cores.textoSuave),
              ]),
            );
          }),
        ),
    ]);
  }
}

// ───────────────────────── Agenda ─────────────────────────

class AgendaSindicoTela extends ConsumerStatefulWidget {
  const AgendaSindicoTela({super.key});
  @override
  ConsumerState<AgendaSindicoTela> createState() => _AgendaSindicoState();
}

class _AgendaSindicoState extends ConsumerState<AgendaSindicoTela> {
  int _dia = 0;
  @override
  Widget build(BuildContext context) {
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = hoje.add(Duration(days: _dia));
    final maquinas = (ref.watch(maquinasProvider).value ?? const <Maquina>[]).sortedBy((m) => '${m.tipo.index}${m.ordem.toString().padLeft(2, '0')}');
    final reservas = (ref.watch(reservasDoDiaProvider(dia)).value ?? const <Reserva>[]).where((r) => r.status != StatusReserva.cancelada).toList();

    Reserva? em(String maqId, int h) => reservas.firstWhereOrNull((r) => r.maquinaId == maqId && r.inicio.isBefore(dia.add(Duration(hours: h + 1))) && r.fim.isAfter(dia.add(Duration(hours: h))));

    return PaginaSindico(
      titulo: 'Agenda',
      subtitulo: '${Fmt.dataLonga(dia)} · ${reservas.length} reservas',
      acoes: [
        IconButton(onPressed: _dia > -7 ? () => setState(() => _dia--) : null, icon: const Icon(Icons.chevron_left_rounded)),
        TextButton(onPressed: () => setState(() => _dia = 0), child: const Text('Hoje')),
        IconButton(onPressed: _dia < 7 ? () => setState(() => _dia++) : null, icon: const Icon(Icons.chevron_right_rounded)),
      ],
      filhos: [
        CartaoBase(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SizedBox(width: 64),
                for (final m in maquinas)
                  SizedBox(width: 78, child: Column(children: [Icon(iconeTipo(m.tipo), size: 18, color: Cores.marca), Text(m.nomeCurto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))])),
              ]),
              const SizedBox(height: 6),
              for (var h = 0; h < 24; h++)
                Row(children: [
                  SizedBox(
                    width: 64,
                    child: Text('${h.toString().padLeft(2, '0')}:00',
                        style: TextStyle(fontWeight: FontWeight.w800, color: _dia == 0 && agora.hour == h ? Cores.marca : Cores.textoSuave, fontSize: 12.5)),
                  ),
                  for (final m in maquinas)
                    Builder(builder: (context) {
                      final r = em(m.id, h);
                      final (_, cor, _) = r == null ? ('', Cores.borda, Icons.circle) : visualReserva(r.status);
                      final indisponivel = r == null && m.status != StatusMaquina.disponivel && _dia == 0;
                      return Padding(
                        padding: const EdgeInsets.all(2),
                        child: Tooltip(
                          message: r == null ? (indisponivel ? m.motivoIndisponivel ?? 'Indisponível' : 'Livre') : '${r.maquinaNome} · Ap ${r.aptoId} (${r.criadaPorNome}) · ${visualReserva(r.status).$1}',
                          child: InkWell(
                            onTap: r == null ? null : () => _detalhe(context, r),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 74,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: r == null ? (indisponivel ? const Color(0xFFEDEFF3) : Colors.white) : Cores.fundoDe(cor),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: r == null ? Cores.borda : cor.withValues(alpha: 0.5)),
                              ),
                              child: r == null
                                  ? (indisponivel ? const Icon(Icons.block, size: 14, color: Cores.textoFraco) : null)
                                  : Text('Ap ${r.aptoId}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: cor)),
                            ),
                          ),
                        ),
                      );
                    }),
                ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Wrap(spacing: 14, children: [
          _Leg(Cores.reservada, 'Agendada'),
          _Leg(Cores.emUso, 'Em uso'),
          _Leg(Cores.livre, 'Concluída'),
          _Leg(Cores.problema, 'Não compareceu / precisa de ação'),
        ]),
      ],
    );
  }

  void _detalhe(BuildContext context, Reserva r) {
    final repo = ref.read(lavanderonRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LinhaReserva(reserva: r, agora: repo.agoraAtual, mostrarApto: true),
            const SizedBox(height: 12),
            for (final h in r.historico) Text('• $h', style: const TextStyle(color: Cores.textoSuave)),
            if (r.status == StatusReserva.agendada || r.status == StatusReserva.precisaAcao) ...[
              const SizedBox(height: 14),
              BotaoAcao(
                rotulo: 'Cancelar reserva (avisa o apartamento)',
                icone: Icons.cancel_rounded,
                cor: Cores.problema,
                onPressed: () async {
                  await repo.cancelarReservaAdmin(r.id, 'Cancelada pelo síndico');
                  if (c.mounted) Navigator.pop(c);
                },
                sucesso: 'Reserva cancelada e Ap ${r.aptoId} avisado.',
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg(this.cor, this.t);
  final Color cor;
  final String t;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: Cores.fundoDe(cor), border: Border.all(color: cor), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]);
}
