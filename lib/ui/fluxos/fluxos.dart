import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio.dart';
import '../estado.dart';
import '../tema/tema.dart';
import '../util/fmt.dart';
import '../widgets/base.dart';
import '../widgets/maquina_widgets.dart';
import 'relatar_paginas.dart';

/// Fluxos compartilhados entre celular, computador e tablet.
/// Abrem folhas e páginas com o Navigator, sem depender das rotas de cada modo.

Future<(String?, int)?> escolherPrograma(BuildContext context, WidgetRef ref, TipoMaquina tipo, {String titulo = 'Quanto tempo o visor da máquina mostra?', String? nota}) async {
  final cfg = await ref.read(lavanderonRepositoryProvider).config().first;
  final programas = cfg.programas[tipo] ?? const <Programa>[];
  if (!context.mounted) return null;
  return showModalBottomSheet<(String?, int)>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _FolhaPrograma(tipo: tipo, programas: programas, titulo: titulo, nota: nota),
  );
}

class _FolhaPrograma extends StatefulWidget {
  const _FolhaPrograma({required this.tipo, required this.programas, required this.titulo, this.nota});
  final TipoMaquina tipo;
  final List<Programa> programas;
  final String titulo;
  final String? nota;
  @override
  State<_FolhaPrograma> createState() => _FolhaProgramaState();
}

class _FolhaProgramaState extends State<_FolhaPrograma> {
  late int _min = widget.programas.length > 1 ? widget.programas[1].minutos : (widget.programas.isEmpty ? 45 : widget.programas.first.minutos);
  late String? _nome = widget.programas.length > 1 ? widget.programas[1].nome : null;
  bool _outro = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.timer_rounded, color: Cores.marca),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.titulo, style: t.titleLarge)),
          ]),
          const SizedBox(height: 6),
          Text(widget.nota ?? 'Vamos avisar quando a roupa estiver pronta. Dá para ajustar depois.', style: const TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in widget.programas)
              _OpcaoPrograma(
                titulo: p.nome,
                minutos: p.minutos,
                selecionado: !_outro && _min == p.minutos && _nome == p.nome,
                onTap: () => setState(() {
                  _outro = false;
                  _min = p.minutos;
                  _nome = p.nome;
                }),
              ),
            _OpcaoPrograma(
              titulo: 'Outro tempo',
              minutos: null,
              selecionado: _outro,
              onTap: () => setState(() {
                _outro = true;
                _nome = null;
              }),
            ),
          ]),
          if (_outro) ...[
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(onPressed: _min > 5 ? () => setState(() => _min -= 5) : null, icon: const Icon(Icons.remove)),
              SizedBox(width: 130, child: Text(Fmt.minutos(_min), textAlign: TextAlign.center, style: t.headlineSmall)),
              IconButton.filledTonal(onPressed: _min < 180 ? () => setState(() => _min += 5) : null, icon: const Icon(Icons.add)),
            ]),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, (_nome, _min)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Começar · ${Fmt.minutos(_min)}'),
          ),
        ]),
      ),
    );
  }
}

class _OpcaoPrograma extends StatelessWidget {
  const _OpcaoPrograma({required this.titulo, required this.minutos, required this.selecionado, required this.onTap});
  final String titulo;
  final int? minutos;
  final bool selecionado;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        child: CartaoBase(
          onTap: onTap,
          raio: 16,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          cor: selecionado ? Cores.marca : Colors.white,
          corBorda: selecionado ? Cores.marca : null,
          child: Column(children: [
            minutos == null
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Icon(Icons.tune_rounded, size: 28, color: selecionado ? Colors.white : Cores.texto))
                : Text('$minutos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: selecionado ? Colors.white : Cores.texto)),
            Text(minutos == null ? titulo : '$titulo · min', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: selecionado ? Colors.white70 : Cores.textoSuave, fontSize: 12.5)),
          ]),
        ),
      );
}

/// Confirma o uso. Com [maquinaId], é o "começar agora" antes do horário,
/// possivelmente em outra máquina livre do mesmo tipo.
Future<bool> fluxoConfirmarUso(BuildContext context, WidgetRef ref, Reserva r, ContextoAcao ctx, {String? maquinaId}) async {
  final p = await escolherPrograma(
    context,
    ref,
    r.tipo,
    titulo: maquinaId == null ? 'Quanto tempo o visor da máquina mostra?' : 'Começar agora: quanto tempo o visor mostra?',
    nota: maquinaId == null
        ? null
        : 'Sua reserva das ${Fmt.hora(r.inicio)} passa a começar agora. Se a roupa ficar pronta antes desse horário, ele fica livre para outros moradores.',
  );
  if (p == null || !context.mounted) return false;
  try {
    final repo = ref.read(lavanderonRepositoryProvider);
    await repo.confirmarUso(reservaId: r.id, quem: ctx.quem, duracaoMin: p.$2, programa: p.$1, origem: ctx.origem, maquinaId: maquinaId);
    final nome = maquinaId == null ? r.maquinaNome : ((await repo.maquinas().first).where((m) => m.id == maquinaId).firstOrNull?.nome ?? r.maquinaNome);
    if (context.mounted) mostrarSucesso(context, 'Uso confirmado na $nome. Cronômetro ligado: ${Fmt.minutos(p.$2)}.');
    return true;
  } catch (e) {
    if (context.mounted) mostrarErro(context, e);
    return false;
  }
}

Future<bool> fluxoUsarAgora(BuildContext context, WidgetRef ref, Maquina m, ContextoAcao ctx) async {
  final p = await escolherPrograma(context, ref, m.tipo, titulo: 'Usar a ${m.nome} agora');
  if (p == null || !context.mounted) return false;
  try {
    await ref.read(lavanderonRepositoryProvider).usarAgora(quem: ctx.quem, maquinaId: m.id, duracaoMin: p.$2, programa: p.$1, origem: ctx.origem);
    if (context.mounted) mostrarSucesso(context, 'Pronto! ${m.nome} é sua. Avisaremos quando a roupa ficar pronta.');
    return true;
  } catch (e) {
    if (context.mounted) mostrarErro(context, e);
    return false;
  }
}

/// Máquinas de um tipo que podem ser usadas neste instante.
List<Maquina> maquinasLivresAgora(List<Maquina> todas, TipoMaquina tipo) =>
    todas.where((m) => m.tipo == tipo && m.status == StatusMaquina.disponivel && m.situacao == SituacaoMaquina.livre).toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));

/// Escolhe uma máquina livre agora (lista de cartões verdes).
Future<Maquina?> escolherMaquinaLivre(BuildContext context, WidgetRef ref, TipoMaquina? tipo) async {
  final todas = await ref.read(lavanderonRepositoryProvider).maquinas().first;
  final lista = tipo == null
      ? [...maquinasLivresAgora(todas, TipoMaquina.lavadora), ...maquinasLivresAgora(todas, TipoMaquina.secadora)]
      : maquinasLivresAgora(todas, tipo);
  if (!context.mounted) return null;
  return showModalBottomSheet<Maquina>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Qual máquina você vai usar?', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Estas estão livres agora. O cronômetro começa assim que você escolher o programa.', style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 14),
          if (lista.isEmpty) const EstadoVazio(icone: Icons.hourglass_empty_rounded, titulo: 'Nenhuma máquina livre agora', texto: 'Reserve um horário na aba Reservar.'),
          for (final m in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CartaoBase(
                onTap: () => Navigator.pop(c, m),
                padding: const EdgeInsets.all(14),
                corBorda: Cores.livre.withValues(alpha: 0.4),
                child: Row(children: [
                  IconeMaquina(m.tipo, cor: Cores.livre, tamanho: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(m.livreAte == null ? 'Livre pelo resto do dia' : 'Livre até ${Fmt.hora(m.livreAte!)}', style: const TextStyle(color: Cores.textoSuave, fontSize: 13)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
        ]),
      ),
    ),
  );
}

Future<bool> fluxoCancelar(BuildContext context, WidgetRef ref, Reserva r, ContextoAcao ctx) async {
  final ok = await confirmar(context,
      titulo: 'Cancelar reserva?',
      texto: '${r.maquinaNome}, ${Fmt.intervalo(r.inicio, r.fim, ref.read(lavanderonRepositoryProvider).agoraAtual)}. O horário fica livre para outros moradores.',
      sim: 'Cancelar reserva',
      perigo: true);
  if (!ok || !context.mounted) return false;
  try {
    final repo = ref.read(lavanderonRepositoryProvider);
    // Combo (RN-24): pergunta se cancela também a outra metade.
    Reserva? par;
    if (r.comboId != null) {
      par = (await repo.reservasDoApto(r.aptoId).first)
          .where((x) => x.comboId == r.comboId && x.id != r.id && (x.status == StatusReserva.agendada || x.status == StatusReserva.precisaAcao))
          .firstOrNull;
    }
    var ambas = false;
    if (par != null && context.mounted) {
      ambas = await confirmar(context,
          titulo: 'Cancelar também a ${par.tipo == TipoMaquina.secadora ? 'secagem' : 'lavagem'}?',
          texto: 'Esta reserva faz parte de um combo com a ${par.maquinaNome} às ${Fmt.hora(par.inicio)}.',
          sim: 'Cancelar as duas',
          nao: 'Só esta');
    }
    await repo.cancelar(r.id, ctx.quem);
    if (ambas && par != null) await repo.cancelar(par.id, ctx.quem);
    if (context.mounted) mostrarSucesso(context, ambas ? 'Lavagem e secagem canceladas.' : 'Reserva cancelada.');
    return true;
  } catch (e) {
    if (context.mounted) mostrarErro(context, e);
    return false;
  }
}

Future<bool> fluxoFinalizar(BuildContext context, WidgetRef ref, Reserva r, ContextoAcao ctx) async {
  try {
    await ref.read(lavanderonRepositoryProvider).finalizar(r.id, ctx.quem);
    if (context.mounted) mostrarSucesso(context, '${r.maquinaNome} liberada. Obrigado!');
    return true;
  } catch (e) {
    if (context.mounted) mostrarErro(context, e);
    return false;
  }
}

/// Escolhe outra máquina livre do mesmo tipo e horário.
Future<Maquina?> escolherAlternativa(BuildContext context, WidgetRef ref, Reserva r, {required String titulo, String? texto}) async {
  final repo = ref.read(lavanderonRepositoryProvider);
  final lista = await repo.alternativas(tipo: r.tipo, inicio: r.inicio, excetoMaquinaId: r.maquinaId);
  if (!context.mounted) return null;
  return showModalBottomSheet<Maquina>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo, style: Theme.of(c).textTheme.titleLarge),
          if (texto != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(texto, style: const TextStyle(color: Cores.textoSuave))),
          const SizedBox(height: 16),
          if (lista.isEmpty)
            const EstadoVazio(icone: Icons.event_busy_rounded, titulo: 'Nenhuma máquina livre nesse horário', texto: 'Tente outro horário na aba Reservar.')
          else
            for (final (i, m) in lista.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CartaoBase(
                  onTap: () => Navigator.pop(c, m),
                  padding: const EdgeInsets.all(14),
                  corBorda: i == 0 ? Cores.livre : null,
                  child: Row(children: [
                    IconeMaquina(m.tipo, cor: Cores.livre, tamanho: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    if (i == 0) const Selo(cor: Cores.livre, texto: 'Sugerida', icone: Icons.auto_awesome),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
        ]),
      ),
    ),
  );
}

Future<bool> fluxoTrocar(BuildContext context, WidgetRef ref, Reserva r, ContextoAcao ctx) async {
  final m = await escolherAlternativa(context, ref, r, titulo: 'Trocar de máquina', texto: 'Mesmo horário, outra máquina livre.');
  if (m == null || !context.mounted) return false;
  try {
    await ref.read(lavanderonRepositoryProvider).trocarMaquina(reservaId: r.id, novaMaquinaId: m.id, quem: ctx.quem);
    if (context.mounted) mostrarSucesso(context, 'Reserva movida para a ${m.nome}.');
    return true;
  } catch (e) {
    if (context.mounted) mostrarErro(context, e);
    return false;
  }
}

/// Seção 6.7: cheguei e a máquina reservada estava ocupada.
Future<bool> fluxoMaquinaOcupada(BuildContext context, WidgetRef ref, Reserva r, ContextoAcao ctx) async {
  final escolha = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('A ${r.maquinaNome} está ocupada?', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('O que você encontrou?', style: TextStyle(color: Cores.textoSuave)),
          const SizedBox(height: 16),
          _OpcaoGrande(
            icone: Icons.autorenew_rounded,
            cor: Cores.emUso,
            titulo: 'Está funcionando com roupa de alguém',
            texto: 'Você troca de máquina na hora e o uso indevido fica registrado.',
            onTap: () => Navigator.pop(c, 'funcionando'),
          ),
          const SizedBox(height: 10),
          _OpcaoGrande(
            icone: Icons.checkroom_rounded,
            cor: Cores.pronta,
            titulo: 'Parada, com roupa de alguém dentro',
            texto: 'Se o prazo do dono já passou, você pode retirar a roupa e usar a sua máquina.',
            onTap: () => Navigator.pop(c, 'parada'),
          ),
        ]),
      ),
    ),
  );
  if (escolha == null || !context.mounted) return false;
  if (escolha == 'parada') {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoupaNaMaquinaPagina(maquinaId: r.maquinaId)));
    return true;
  }
  final m = await escolherAlternativa(context, ref, r,
      titulo: 'Trocar para uma máquina livre', texto: 'Sua reserva muda de máquina, mantém o horário e o uso já fica confirmado.');
  if (m == null || !context.mounted) return false;
  try {
    await ref.read(lavanderonRepositoryProvider).maquinaOcupada(reservaId: r.id, quem: ctx.quem, destinoMaquinaId: m.id);
    if (context.mounted) mostrarSucesso(context, 'Pronto! Você está na ${m.nome}. O uso indevido da ${r.maquinaNome} foi registrado.');
    return true;
  } catch (e) {
    if (context.mounted) mostrarErro(context, e);
    return false;
  }
}

class _OpcaoGrande extends StatelessWidget {
  const _OpcaoGrande({required this.icone, required this.cor, required this.titulo, required this.texto, required this.onTap});
  final IconData icone;
  final Color cor;
  final String titulo, texto;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CartaoBase(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Cores.fundoDe(cor), borderRadius: BorderRadius.circular(14)),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(texto, style: const TextStyle(color: Cores.textoSuave, fontSize: 13.5)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      );
}

/// Menu "Relatar": problema em máquina, na lavanderia, roupa na máquina, minha roupa foi retirada.
Future<void> abrirRelatar(BuildContext context, {String? maquinaId}) => showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        void ir(Widget p) {
          Navigator.pop(c);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => p));
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Relatar', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 14),
              _OpcaoGrande(icone: Icons.build_circle_rounded, cor: Cores.problema, titulo: 'Problema em uma máquina', texto: 'Não liga, vaza, não centrifuga, porta…', onTap: () => ir(RelatarMaquinaPagina(maquinaId: maquinaId))),
              const SizedBox(height: 10),
              _OpcaoGrande(icone: Icons.checkroom_rounded, cor: Cores.pronta, titulo: 'Roupa de alguém na máquina', texto: 'Avisar o dono ou registrar que você retirou', onTap: () => ir(RoupaNaMaquinaPagina(maquinaId: maquinaId))),
              const SizedBox(height: 10),
              _OpcaoGrande(icone: Icons.inventory_2_rounded, cor: Cores.semRegistro, titulo: 'Minha roupa foi retirada', texto: 'Encontrei minha roupa fora da máquina', onTap: () => ir(MinhaRoupaRetiradaPagina(maquinaId: maquinaId))),
              const SizedBox(height: 10),
              _OpcaoGrande(icone: Icons.home_repair_service_rounded, cor: Cores.reservada, titulo: 'Problema na lavanderia', texto: 'Luz, vazamento, limpeza, tomada, porta…', onTap: () => ir(const RelatarLavanderiaPagina())),
            ]),
          ),
        );
      },
    );
