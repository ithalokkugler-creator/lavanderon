import 'package:flutter/material.dart';

import '../dominio.dart';
import '../tema/tema.dart';

/// Limita a largura do conteúdo em telas grandes e centraliza.
class ConteudoLimitado extends StatelessWidget {
  const ConteudoLimitado({super.key, required this.child, this.largura = Medidas.larguraMaxConteudo});
  final Widget child;
  final double largura;
  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: largura), child: child));
}

class CartaoBase extends StatelessWidget {
  const CartaoBase({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.cor, this.corBorda, this.raio = Medidas.raio});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? cor;
  final Color? corBorda;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(raio),
      side: BorderSide(color: corBorda ?? Cores.borda, width: corBorda == null ? 1 : 1.5),
    );
    return Material(
      color: cor ?? Colors.white,
      shape: forma,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class TituloSecao extends StatelessWidget {
  const TituloSecao(this.titulo, {super.key, this.subtitulo, this.acao, this.onAcao});
  final String titulo;
  final String? subtitulo;
  final String? acao;
  final VoidCallback? onAcao;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: t.titleLarge),
              if (subtitulo != null) Text(subtitulo!, style: t.bodyMedium?.copyWith(color: Cores.textoSuave)),
            ]),
          ),
          if (acao != null) TextButton(onPressed: onAcao, child: Text(acao!)),
        ],
      ),
    );
  }
}

/// Selo de status: cor + ícone + texto.
class Selo extends StatelessWidget {
  const Selo({super.key, required this.cor, required this.texto, this.icone, this.forte = false});
  final Color cor;
  final String texto;
  final IconData? icone;
  final bool forte;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: forte ? cor : Cores.fundoDe(cor), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[Icon(icone, size: 15, color: forte ? Colors.white : cor), const SizedBox(width: 5)],
          Text(texto,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: forte ? Colors.white : cor, letterSpacing: 0.2)),
        ]),
      );
}

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.icone, required this.titulo, this.texto, this.acao, this.onAcao});
  final IconData icone;
  final String titulo;
  final String? texto;
  final String? acao;
  final VoidCallback? onAcao;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: Cores.fundoDe(Cores.marca), shape: BoxShape.circle),
            child: Icon(icone, size: 34, color: Cores.marca),
          ),
          const SizedBox(height: 14),
          Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (texto != null) ...[
            const SizedBox(height: 6),
            Text(texto!, textAlign: TextAlign.center, style: const TextStyle(color: Cores.textoSuave)),
          ],
          if (acao != null) ...[const SizedBox(height: 16), FilledButton(onPressed: onAcao, child: Text(acao!))],
        ]),
      );
}

/// Faixa de alerta no topo das telas (fechada, reserva afetada, roupas retiradas...).
class FaixaAlerta extends StatelessWidget {
  const FaixaAlerta({super.key, required this.cor, required this.icone, required this.titulo, this.texto, this.acao, this.onTap});
  final Color cor;
  final IconData icone;
  final String titulo;
  final String? texto;
  final String? acao;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => CartaoBase(
        cor: Cores.fundoDe(cor),
        corBorda: cor.withValues(alpha: 0.35),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        onTap: onTap,
        raio: 16,
        child: Row(children: [
          Icon(icone, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w800, color: cor)),
              if (texto != null) Text(texto!, style: const TextStyle(color: Cores.texto, fontSize: 13.5)),
            ]),
          ),
          if (acao != null) Text(acao!, style: TextStyle(color: cor, fontWeight: FontWeight.w800)),
          if (onTap != null) Icon(Icons.chevron_right, color: cor),
        ]),
      );
}

/// Botão que executa uma ação assíncrona, mostra carregamento, bloqueia toque duplo
/// e traduz [AppErro] em mensagem amigável.
class BotaoAcao extends StatefulWidget {
  const BotaoAcao({super.key, required this.rotulo, required this.onPressed, this.icone, this.estilo = EstiloBotao.cheio, this.cor, this.expandir = true, this.sucesso});
  final String rotulo;
  final Future<void> Function()? onPressed;
  final IconData? icone;
  final EstiloBotao estilo;
  final Color? cor;
  final bool expandir;
  final String? sucesso;
  @override
  State<BotaoAcao> createState() => _BotaoAcaoState();
}

enum EstiloBotao { cheio, contorno, texto }

class _BotaoAcaoState extends State<BotaoAcao> {
  bool _ocupado = false;

  Future<void> _executar() async {
    if (_ocupado || widget.onPressed == null) return;
    setState(() => _ocupado = true);
    try {
      await widget.onPressed!();
      if (mounted && widget.sucesso != null) mostrarSucesso(context, widget.sucesso!);
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filho = _ocupado
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icone != null) ...[Icon(widget.icone, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(widget.rotulo, overflow: TextOverflow.ellipsis)),
          ]);
    final onP = widget.onPressed == null ? null : _executar;
    final Widget b = switch (widget.estilo) {
      EstiloBotao.cheio => FilledButton(
          onPressed: onP,
          style: widget.cor == null ? null : FilledButton.styleFrom(backgroundColor: widget.cor),
          child: filho),
      EstiloBotao.contorno => OutlinedButton(
          onPressed: onP,
          style: widget.cor == null ? null : OutlinedButton.styleFrom(foregroundColor: widget.cor, side: BorderSide(color: widget.cor!.withValues(alpha: 0.5), width: 1.5)),
          child: _ocupado ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : filho),
      EstiloBotao.texto => TextButton(onPressed: onP, child: filho),
    };
    return widget.expandir ? SizedBox(width: double.infinity, child: b) : b;
  }
}

void mostrarSucesso(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: Color(0xFF7CE38B)), const SizedBox(width: 10), Expanded(child: Text(msg))]),
    ));
}

void mostrarErro(BuildContext context, Object e) {
  final msg = e is AppErro ? e.mensagem : 'Algo deu errado. Tente de novo.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: Cores.problema,
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(msg))]),
    ));
}

Future<bool> confirmar(BuildContext context, {required String titulo, required String texto, String sim = 'Confirmar', String nao = 'Voltar', bool perigo = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(nao)),
        FilledButton(
          style: perigo ? FilledButton.styleFrom(backgroundColor: Cores.problema) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(sim),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Contador vermelho (avisos não lidos etc.).
class Contador extends StatelessWidget {
  const Contador(this.n, {super.key, required this.child});
  final int n;
  final Widget child;
  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: n > 0,
        backgroundColor: Cores.problema,
        label: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
        child: child,
      );
}

/// Linha "rótulo: valor" usada em detalhes.
class LinhaInfo extends StatelessWidget {
  const LinhaInfo(this.icone, this.texto, {super.key, this.cor});
  final IconData icone;
  final String texto;
  final Color? cor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icone, size: 18, color: cor ?? Cores.textoSuave),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: cor ?? Cores.texto, fontWeight: FontWeight.w600))),
        ]),
      );
}
