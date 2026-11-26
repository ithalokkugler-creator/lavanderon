import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio.dart';
import '../../tema/tema.dart';
import '../../widgets/base.dart';

/// Identificação rápida no tablet: andar → final → primeiro nome (seção 7.5).
Future<Morador?> mostrarIdentificacaoTablet(BuildContext context) => showDialog<Morador>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const Dialog(insetPadding: EdgeInsets.all(24), child: _Identificacao()),
    );

class _Identificacao extends ConsumerStatefulWidget {
  const _Identificacao();
  @override
  ConsumerState<_Identificacao> createState() => _IdentificacaoState();
}

class _IdentificacaoState extends ConsumerState<_Identificacao> {
  int? _andar;
  String? _apto;
  final _nome = TextEditingController();
  String? _erro;
  bool _ocupado = false;

  Future<void> _entrar() async {
    if (_apto == null || _nome.text.trim().isEmpty) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final m = await ref.read(lavanderonRepositoryProvider).entrar(_apto!, _nome.text);
      if (mounted) Navigator.pop(context, m);
    } on AppErro catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aptos = ref.watch(apartamentosProvider).value ?? const <Apartamento>[];
    final t = Theme.of(context).textTheme;
    final passo = _andar == null ? 1 : (_apto == null ? 2 : 3);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (passo > 1)
              IconButton(
                onPressed: () => setState(() {
                  if (passo == 3) {
                    _apto = null;
                  } else {
                    _andar = null;
                  }
                  _erro = null;
                }),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            Expanded(
              child: Text(switch (passo) { 1 => 'Qual o seu andar?', 2 => 'Qual o final do apartamento?', _ => 'Apartamento $_apto: seu primeiro nome' }, style: t.headlineSmall),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 6),
          Text('Passo $passo de 3 · nada fica salvo neste tablet', style: const TextStyle(color: Cores.textoSuave, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          if (passo == 1)
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                for (var a = 1; a <= 6; a++)
                  _Tecla(texto: '$aº', sub: 'andar', onTap: () => setState(() => _andar = a)),
              ],
            ),
          if (passo == 2)
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                for (var f = 1; f <= 20; f++)
                  Builder(builder: (_) {
                    final id = '$_andar${f.toString().padLeft(2, '0')}';
                    final ap = aptos.where((x) => x.id == id).firstOrNull;
                    final existe = ap?.existe ?? true;
                    return _Tecla(
                      texto: id,
                      sub: !existe ? 'não existe' : (ap?.ativo == false ? 'suspenso' : null),
                      habilitado: existe,
                      onTap: () => setState(() => _apto = id),
                    );
                  }),
              ],
            ),
          if (passo == 3) ...[
            TextField(
              controller: _nome,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _entrar(),
              decoration: InputDecoration(hintText: 'Ex.: Maria', errorText: _erro),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: _ocupado ? null : _entrar,
                icon: _ocupado ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.login_rounded),
                label: const Text('Continuar', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Demonstração: 302 Maria · 410 Carlos · 105 Ana', textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}

class _Tecla extends StatelessWidget {
  const _Tecla({required this.texto, required this.onTap, this.sub, this.habilitado = true});
  final String texto;
  final String? sub;
  final VoidCallback onTap;
  final bool habilitado;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: habilitado ? 1 : 0.35,
        child: CartaoBase(
          onTap: habilitado ? onTap : null,
          raio: 16,
          padding: EdgeInsets.zero,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(texto, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (sub != null) Text(sub!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sub == 'suspenso' ? Cores.problema : Cores.textoSuave)),
            ]),
          ),
        ),
      );
}
