import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dominio.dart';
import '../tema/tema.dart';
import '../util/fmt.dart';
import 'base.dart';

IconData iconeTipo(TipoMaquina t) => t == TipoMaquina.lavadora ? Icons.local_laundry_service_rounded : Icons.dry_rounded;
String nomeTipo(TipoMaquina t, {bool plural = false}) =>
    t == TipoMaquina.lavadora ? (plural ? 'Lavadoras' : 'Lavadora') : (plural ? 'Secadoras' : 'Secadora');
String verboTipo(TipoMaquina t) => t == TipoMaquina.lavadora ? 'Lavar' : 'Secar';

/// Como uma máquina deve aparecer agora: cor, ícone, rótulo e detalhe.
class VisualMaquina {
  const VisualMaquina(this.cor, this.icone, this.rotulo, this.detalhe, {this.restante});
  final Color cor;
  final IconData icone;
  final String rotulo;
  final String detalhe;
  final Duration? restante;
  bool get disponivel => cor == Cores.livre;
}

VisualMaquina visualMaquina(Maquina m, DateTime agora) {
  switch (m.status) {
    case StatusMaquina.desativada:
      return const VisualMaquina(Cores.indisponivel, Icons.block, 'Desativada', 'Fora de uso');
    case StatusMaquina.manutencao:
      final prev = m.indisponivelAte == null ? 'sem previsão' : 'previsão ${Fmt.dataCurta(m.indisponivelAte!)}';
      return VisualMaquina(Cores.indisponivel, Icons.build_rounded, 'Manutenção', '${m.motivoIndisponivel ?? 'Em manutenção'} · $prev');
    case StatusMaquina.bloqueadaHoje:
      final ate = m.indisponivelAte == null ? '' : ' · até ${Fmt.hora(m.indisponivelAte!)}';
      return VisualMaquina(Cores.problema, Icons.warning_rounded, 'Com problema', '${m.motivoIndisponivel ?? 'Bloqueada'}$ate');
    case StatusMaquina.disponivel:
      break;
  }
  switch (m.situacao) {
    case SituacaoMaquina.livre:
      return VisualMaquina(Cores.livre, Icons.check_circle_rounded, 'Livre',
          m.livreAte == null ? 'Livre pelo resto do dia' : 'Livre até ${Fmt.hora(m.livreAte!)}');
    case SituacaoMaquina.reservada:
      final ini = m.proximaReservaInicio;
      final ap = m.aptoAtual ?? m.proximaReservaApto;
      return VisualMaquina(Cores.reservada, Icons.schedule_rounded, 'Reservada',
          '${ini == null ? '' : '${Fmt.hora(ini)} · '}${ap == null ? '' : 'Ap $ap'}');
    case SituacaoMaquina.emUso:
      final fim = m.previsaoFim;
      final rest = fim?.difference(agora);
      return VisualMaquina(Cores.emUso, Icons.autorenew_rounded, m.roupaDeOutroMorador ? 'Em uso (roupa de outro morador)' : 'Em uso',
          fim == null ? 'Ap ${m.aptoAtual ?? '—'}' : 'Pronta ${Fmt.relativo(fim, agora)}',
          restante: rest);
    case SituacaoMaquina.aguardandoRetirada:
      return VisualMaquina(Cores.pronta, Icons.notifications_active_rounded, 'Pronta',
          m.previsaoFim == null ? 'Aguardando retirada' : 'Aguardando retirada desde ${Fmt.hora(m.previsaoFim!)}');
    case SituacaoMaquina.ocupadaSemRegistro:
      return const VisualMaquina(Cores.semRegistro, Icons.report_rounded, 'Ocupada', 'Uso não registrado');
  }
}

class IconeMaquina extends StatelessWidget {
  const IconeMaquina(this.tipo, {super.key, this.cor = Cores.marca, this.tamanho = 44});
  final TipoMaquina tipo;
  final Color cor;
  final double tamanho;
  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(color: Cores.fundoDe(cor), borderRadius: BorderRadius.circular(tamanho * 0.32)),
        child: Icon(iconeTipo(tipo), color: cor, size: tamanho * 0.56),
      );
}

/// Cartão de máquina do painel ao vivo.
class CartaoMaquina extends StatelessWidget {
  const CartaoMaquina({super.key, required this.maquina, required this.agora, this.onTap, this.grande = false, this.destaque = false});
  final Maquina maquina;
  final DateTime agora;
  final VoidCallback? onTap;
  final bool grande;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final v = visualMaquina(maquina, agora);
    final t = Theme.of(context).textTheme;
    return CartaoBase(
      onTap: onTap,
      padding: EdgeInsets.all(grande ? 18 : 14),
      corBorda: destaque ? Cores.marca : v.cor.withValues(alpha: 0.28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconeMaquina(maquina.tipo, cor: v.cor, tamanho: grande ? 44 : 38),
          const Spacer(),
          if (v.restante != null && !v.restante!.isNegative)
            AnelCronometro(restante: v.restante!, total: Duration(minutes: maquina.cicloMin), cor: v.cor, tamanho: grande ? 44 : 38)
          else
            Icon(v.icone, color: v.cor, size: grande ? 26 : 22),
        ]),
        SizedBox(height: grande ? 14 : 10),
        Text(maquina.nome, style: (grande ? t.titleMedium : t.titleSmall)?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(v.rotulo, style: TextStyle(color: v.cor, fontWeight: FontWeight.w800, fontSize: grande ? 15 : 13.5)),
        Text(v.detalhe,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Cores.textoSuave, fontSize: grande ? 13.5 : 12.5, fontWeight: FontWeight.w600)),
        if (maquina.alerta != null && maquina.status == StatusMaquina.disponivel) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Cores.reservada),
            const SizedBox(width: 4),
            Expanded(child: Text(maquina.alerta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Cores.reservada, fontWeight: FontWeight.w700))),
          ]),
        ],
      ]),
    );
  }
}

/// Grade responsiva de cartões de máquinas de um tipo.
class GradeMaquinas extends StatelessWidget {
  const GradeMaquinas({super.key, required this.maquinas, required this.agora, required this.onTap, this.colunasMin = 2, this.grande = false});
  final List<Maquina> maquinas;
  final DateTime agora;
  final void Function(Maquina) onTap;
  final int colunasMin;
  final bool grande;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final larguraCartao = grande ? 190.0 : 165.0;
        final cols = math.max(colunasMin, (c.maxWidth / larguraCartao).floor()).clamp(colunasMin, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: grande ? 190 : 168,
          ),
          itemCount: maquinas.length,
          itemBuilder: (_, i) => CartaoMaquina(maquina: maquinas[i], agora: agora, grande: grande, onTap: () => onTap(maquinas[i])),
        );
      });
}

/// Anel de progresso com o tempo restante no centro.
class AnelCronometro extends StatelessWidget {
  const AnelCronometro({super.key, required this.restante, required this.total, required this.cor, this.tamanho = 44, this.grosso = false, this.textoCentral});
  final Duration restante;
  final Duration total;
  final Color cor;
  final double tamanho;
  final bool grosso;
  final Widget? textoCentral;

  @override
  Widget build(BuildContext context) {
    final p = total.inSeconds == 0 ? 0.0 : (1 - restante.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: tamanho,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: p,
            strokeWidth: grosso ? tamanho * 0.07 : 4,
            strokeCap: StrokeCap.round,
            backgroundColor: Cores.fundoDe(cor),
            color: cor,
          ),
        ),
        textoCentral ??
            Text('${math.max(0, restante.inMinutes + (restante.inSeconds % 60 > 0 ? 1 : 0))}′',
                style: TextStyle(fontSize: tamanho * 0.28, fontWeight: FontWeight.w900, color: cor)),
      ]),
    );
  }
}

/// Legenda de cores do painel.
class LegendaStatus extends StatelessWidget {
  const LegendaStatus({super.key});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, runSpacing: 6, children: const [
        _ItemLegenda(Cores.livre, 'Livre'),
        _ItemLegenda(Cores.reservada, 'Reservada'),
        _ItemLegenda(Cores.emUso, 'Em uso'),
        _ItemLegenda(Cores.pronta, 'Pronta'),
        _ItemLegenda(Cores.problema, 'Com problema'),
        _ItemLegenda(Cores.indisponivel, 'Manutenção'),
      ]);
}

class _ItemLegenda extends StatelessWidget {
  const _ItemLegenda(this.cor, this.texto);
  final Color cor;
  final String texto;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12.5, color: Cores.textoSuave, fontWeight: FontWeight.w700)),
      ]);
}

/// Seção com título "Lavadoras"/"Secadoras" + contagem de livres.
class SecaoMaquinas extends StatelessWidget {
  const SecaoMaquinas({super.key, required this.tipo, required this.maquinas, required this.agora, required this.onTap, this.grande = false});
  final TipoMaquina tipo;
  final List<Maquina> maquinas;
  final DateTime agora;
  final void Function(Maquina) onTap;
  final bool grande;
  @override
  Widget build(BuildContext context) {
    final lista = maquinas.where((m) => m.tipo == tipo && m.status != StatusMaquina.desativada).toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    final livres = lista.where((m) => visualMaquina(m, agora).disponivel).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Row(children: [
          Icon(iconeTipo(tipo), color: Cores.marca),
          const SizedBox(width: 8),
          Text(nomeTipo(tipo, plural: true), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 10),
          Selo(cor: livres > 0 ? Cores.livre : Cores.problema, texto: livres == 1 ? '1 livre' : '$livres livres'),
        ]),
      ),
      GradeMaquinas(maquinas: lista, agora: agora, onTap: onTap, grande: grande),
    ]);
  }
}
