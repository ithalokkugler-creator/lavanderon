import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio.dart';
import '../estado.dart';
import '../tema/tema.dart';
import '../util/fmt.dart';
import '../widgets/base.dart';
import '../widgets/maquina_widgets.dart';
import 'fluxos.dart';

/// Página de fluxo (empurrada com Navigator) com rodapé de ação fixo.
class PaginaFluxo extends StatelessWidget {
  const PaginaFluxo({super.key, required this.titulo, required this.filhos, this.rodape});
  final String titulo;
  final List<Widget> filhos;
  final Widget? rodape;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [ConteudoLimitado(largura: 720, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos))],
        ),
        bottomNavigationBar: rodape == null
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Cores.borda))),
                  child: ConteudoLimitado(largura: 720, child: rodape!),
                ),
              ),
      );
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(texto, style: Theme.of(context).textTheme.titleMedium));
}

class SeletorMaquina extends ConsumerWidget {
  const SeletorMaquina({super.key, required this.selecionada, required this.onChanged, this.tipo});
  final String? selecionada;
  final ValueChanged<Maquina> onChanged;
  final TipoMaquina? tipo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = [...(ref.watch(maquinasProvider).value ?? const <Maquina>[])]
      ..removeWhere((m) => m.status == StatusMaquina.desativada || (tipo != null && m.tipo != tipo))
      ..sort((a, b) => a.tipo == b.tipo ? a.ordem.compareTo(b.ordem) : a.tipo.index.compareTo(b.tipo.index));
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in lista)
        ChoiceChip(
          avatar: Icon(iconeTipo(m.tipo), size: 18, color: m.id == selecionada ? Colors.white : Cores.marca),
          label: Text(m.nomeCurto),
          selected: m.id == selecionada,
          onSelected: (_) => onChanged(m),
        ),
    ]);
  }
}

Widget _semIdentificacao() => const EstadoVazio(icone: Icons.person_off_rounded, titulo: 'Identifique-se primeiro', texto: 'Entre com seu apartamento e nome para relatar.');

// ───────────────────────── Problema em máquina ─────────────────────────

const _catLavadora = ['Não liga', 'Não enche', 'Não centrifuga', 'Vazando água', 'Porta não abre/fecha', 'Barulho estranho', 'Roupa sai suja', 'Outro'];
const _catSecadora = ['Não liga', 'Não esquenta', 'Não gira', 'Cheiro de queimado', 'Porta não abre/fecha', 'Barulho estranho', 'Outro'];

class RelatarMaquinaPagina extends ConsumerStatefulWidget {
  const RelatarMaquinaPagina({super.key, this.maquinaId});
  final String? maquinaId;
  @override
  ConsumerState<RelatarMaquinaPagina> createState() => _RelatarMaquinaState();
}

class _RelatarMaquinaState extends ConsumerState<RelatarMaquinaPagina> {
  late String? _maq = widget.maquinaId;
  String? _cat;
  bool? _impede;
  bool _foto = false;
  final _desc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contextoAcaoProvider);
    final maquinas = ref.watch(maquinasProvider).value ?? const <Maquina>[];
    final m = maquinas.where((x) => x.id == _maq).firstOrNull;
    final cats = m == null ? const <String>[] : (m.tipo == TipoMaquina.lavadora ? _catLavadora : _catSecadora);
    final pronto = ctx != null && m != null && _cat != null && _impede != null;

    return PaginaFluxo(
      titulo: 'Problema em máquina',
      filhos: ctx == null
          ? [_semIdentificacao()]
          : [
              const _Rotulo('Qual máquina?'),
              SeletorMaquina(selecionada: _maq, onChanged: (x) => setState(() {
                    _maq = x.id;
                    _cat = null;
                  })),
              if (m != null) ...[
                const _Rotulo('O que está acontecendo?'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in cats) ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                ]),
                const _Rotulo('A máquina ainda pode ser usada?'),
                Row(children: [
                  Expanded(child: _Escolha(texto: 'Não, está parada ou é perigoso', icone: Icons.block_rounded, cor: Cores.problema, selecionado: _impede == true, onTap: () => setState(() => _impede = true))),
                  const SizedBox(width: 10),
                  Expanded(child: _Escolha(texto: 'Sim, mas tem algo errado', icone: Icons.info_outline_rounded, cor: Cores.reservada, selecionado: _impede == false, onTap: () => setState(() => _impede = false))),
                ]),
                if (_impede == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: FaixaAlerta(
                      cor: Cores.problema,
                      icone: Icons.lock_clock_rounded,
                      titulo: 'A máquina será bloqueada até o fim do dia',
                      texto: 'Quem tinha reserva nela será movido para outra máquina ou avisado para escolher outro horário. À noite, o bloqueio vai até as 08:00.',
                    ),
                  ),
                if (_cat == 'Porta não abre/fecha' || _cat == 'Vazando água' || _cat == 'Cheiro de queimado')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: FaixaAlerta(cor: Cores.reservada, icone: Icons.health_and_safety_rounded, titulo: 'Por segurança', texto: 'Não force a porta nem mexa na parte elétrica. O zelador será avisado.'),
                  ),
                const _Rotulo('Detalhes (opcional)'),
                TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex.: parou no meio da centrifugação e fez um barulho alto')),
                const SizedBox(height: 12),
                _FotoDemo(ativa: _foto, onTap: () => setState(() => _foto = !_foto)),
              ],
            ],
      rodape: ctx == null
          ? null
          : BotaoAcao(
              rotulo: 'Enviar relato',
              icone: Icons.send_rounded,
              onPressed: !pronto
                  ? null
                  : () async {
                      await ref.read(lavanderonRepositoryProvider).relatarProblemaMaquina(
                          quem: ctx.quem, maquinaId: m.id, categoria: _cat!, impedeUso: _impede!, descricao: _desc.text.isEmpty ? null : _desc.text, origem: ctx.origem);
                      if (!context.mounted) return;
                      mostrarSucesso(context, _impede! ? 'Obrigado! ${m.nome} bloqueada e síndico avisado.' : 'Obrigado! O síndico foi avisado.');
                      Navigator.pop(context);
                    },
            ),
    );
  }
}

class _Escolha extends StatelessWidget {
  const _Escolha({required this.texto, required this.icone, required this.cor, required this.selecionado, required this.onTap});
  final String texto;
  final IconData icone;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CartaoBase(
        onTap: onTap,
        raio: 16,
        padding: const EdgeInsets.all(14),
        cor: selecionado ? Cores.fundoDe(cor) : Colors.white,
        corBorda: selecionado ? cor : null,
        child: Row(children: [
          Icon(icone, color: cor),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (selecionado) Icon(Icons.check_circle, color: cor),
        ]),
      );
}

class _FotoDemo extends StatelessWidget {
  const _FotoDemo({required this.ativa, required this.onTap});
  final bool ativa;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CartaoBase(
        onTap: onTap,
        raio: 16,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ativa ? Cores.fundoDe(Cores.agua) : Cores.fundo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Cores.borda),
            ),
            child: Icon(ativa ? Icons.image_rounded : Icons.add_a_photo_rounded, color: ativa ? Cores.agua : Cores.textoSuave),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(ativa ? 'foto_1.jpg anexada (demonstração)' : 'Adicionar foto (opcional, até 3)',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Cores.textoSuave)),
          ),
          if (ativa) const Icon(Icons.close_rounded, color: Cores.textoSuave),
        ]),
      );
}

// ───────────────────────── Problema na lavanderia ─────────────────────────

const _catLavanderia = ['Iluminação', 'Limpeza ou piso molhado', 'Vazamento ou encanamento', 'Tomada ou parte elétrica', 'Porta ou fechadura', 'Ventilação ou mofo', 'Balcão, cestos ou varal', 'Tablet com defeito', 'Outro'];

class RelatarLavanderiaPagina extends ConsumerStatefulWidget {
  const RelatarLavanderiaPagina({super.key});
  @override
  ConsumerState<RelatarLavanderiaPagina> createState() => _RelatarLavanderiaState();
}

class _RelatarLavanderiaState extends ConsumerState<RelatarLavanderiaPagina> {
  String? _cat;
  bool _urgente = false;
  bool _foto = false;
  final _desc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contextoAcaoProvider);
    return PaginaFluxo(
      titulo: 'Problema na lavanderia',
      filhos: ctx == null
          ? [_semIdentificacao()]
          : [
              const _Rotulo('O que aconteceu?'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _catLavanderia) ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
              ]),
              const SizedBox(height: 16),
              CartaoBase(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _urgente,
                  onChanged: (v) => setState(() => _urgente = v),
                  title: const Text('É urgente', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Risco à segurança: fio exposto, alagamento… O síndico e o zelador recebem na hora.'),
                ),
              ),
              const _Rotulo('Detalhes (opcional)'),
              TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex.: lâmpada perto das secadoras piscando')),
              const SizedBox(height: 12),
              _FotoDemo(ativa: _foto, onTap: () => setState(() => _foto = !_foto)),
              const SizedBox(height: 8),
              const Text('Não fotografe pessoas.', style: TextStyle(color: Cores.textoFraco, fontSize: 12.5)),
            ],
      rodape: ctx == null
          ? null
          : BotaoAcao(
              rotulo: 'Enviar relato',
              icone: Icons.send_rounded,
              onPressed: _cat == null
                  ? null
                  : () async {
                      await ref.read(lavanderonRepositoryProvider).relatarProblemaLavanderia(quem: ctx.quem, categoria: _cat!, urgente: _urgente, descricao: _desc.text.isEmpty ? null : _desc.text);
                      if (!context.mounted) return;
                      mostrarSucesso(context, 'Obrigado! Acompanhe em Minhas ocorrências.');
                      Navigator.pop(context);
                    },
            ),
    );
  }
}

// ───────────────────────── Roupa na máquina (6.10 A) ─────────────────────────

String nomeLocal(LocalRoupa l) => switch (l) {
      LocalRoupa.balcao => 'Balcão',
      LocalRoupa.cesto => 'Cesto',
      LocalRoupa.secadora => 'Secadora',
      LocalRoupa.outro => 'Outro lugar',
    };

IconData iconeLocal(LocalRoupa l) => switch (l) {
      LocalRoupa.balcao => Icons.table_restaurant_rounded,
      LocalRoupa.cesto => Icons.shopping_basket_rounded,
      LocalRoupa.secadora => Icons.dry_rounded,
      LocalRoupa.outro => Icons.place_rounded,
    };

class RoupaNaMaquinaPagina extends ConsumerStatefulWidget {
  const RoupaNaMaquinaPagina({super.key, this.maquinaId});
  final String? maquinaId;
  @override
  ConsumerState<RoupaNaMaquinaPagina> createState() => _RoupaNaMaquinaState();
}

class _RoupaNaMaquinaState extends ConsumerState<RoupaNaMaquinaPagina> {
  late String? _maq = widget.maquinaId;
  Future<InfoRoupaMaquina>? _info;
  bool? _retirei;
  LocalRoupa _local = LocalRoupa.balcao;
  String? _secadoraId;
  final _outro = TextEditingController();
  bool _foto = false;

  @override
  void initState() {
    super.initState();
    if (_maq != null) _info = ref.read(lavanderonRepositoryProvider).infoRoupaMaquina(_maq!);
  }

  void _selecionar(Maquina m) => setState(() {
        _maq = m.id;
        _retirei = null;
        _info = ref.read(lavanderonRepositoryProvider).infoRoupaMaquina(m.id);
      });

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contextoAcaoProvider);
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    return FutureBuilder<InfoRoupaMaquina>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data;
        final prazoPassou = info?.prazoPassou ?? false;
        return PaginaFluxo(
          titulo: 'Roupa na máquina',
          filhos: ctx == null
              ? [_semIdentificacao()]
              : [
                  const CartaoBase(
                    cor: Color(0xFFF0FAFB),
                    padding: EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.lightbulb_rounded, color: Cores.pronta),
                      SizedBox(width: 12),
                      Expanded(child: Text('Encontrou roupa esquecida? Espere o prazo, retire com cuidado, deixe no balcão e registre aqui. O dono será avisado.')),
                    ]),
                  ),
                  const _Rotulo('Em qual máquina?'),
                  SeletorMaquina(selecionada: _maq, onChanged: _selecionar),
                  if (snap.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  if (info != null) ...[
                    const SizedBox(height: 16),
                    _SituacaoPrazo(info: info, agora: agora),
                    const _Rotulo('O que você quer fazer?'),
                    _Escolha(texto: 'Só avisar o dono', icone: Icons.notifications_rounded, cor: Cores.marca, selecionado: _retirei == false, onTap: () => setState(() => _retirei = false)),
                    const SizedBox(height: 10),
                    _Escolha(
                      texto: prazoPassou ? 'Retirei a roupa' : 'Retirei a roupa (antes do prazo)',
                      icone: Icons.back_hand_rounded,
                      cor: prazoPassou ? Cores.pronta : Cores.problema,
                      selecionado: _retirei == true,
                      onTap: () => setState(() => _retirei = true),
                    ),
                    if (_retirei == true) ...[
                      if (!prazoPassou)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: FaixaAlerta(cor: Cores.problema, icone: Icons.gavel_rounded, titulo: 'Ainda está no prazo do dono', texto: 'Retirar antes do prazo é considerado mau uso, e o síndico será informado.'),
                        ),
                      const _Rotulo('Onde a roupa ficou?'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final l in LocalRoupa.values)
                          ChoiceChip(
                            avatar: Icon(iconeLocal(l), size: 18, color: _local == l ? Colors.white : Cores.marca),
                            label: Text(l == LocalRoupa.balcao ? 'Balcão (recomendado)' : nomeLocal(l)),
                            selected: _local == l,
                            onSelected: (_) => setState(() => _local = l),
                          ),
                      ]),
                      if (_local == LocalRoupa.secadora) ...[
                        const SizedBox(height: 12),
                        SeletorMaquina(tipo: TipoMaquina.secadora, selecionada: _secadoraId, onChanged: (s) => setState(() => _secadoraId = s.id)),
                        const SizedBox(height: 12),
                        const FaixaAlerta(cor: Cores.reservada, icone: Icons.warning_amber_rounded, titulo: 'Algumas peças não podem ir à secadora', texto: 'O dono será avisado de onde está a roupa, e o síndico também.'),
                      ],
                      if (_local == LocalRoupa.outro) ...[
                        const SizedBox(height: 12),
                        TextField(controller: _outro, decoration: const InputDecoration(labelText: 'Onde?', hintText: 'Ex.: prateleira ao lado da pia')),
                      ],
                      const SizedBox(height: 12),
                      _FotoDemo(ativa: _foto, onTap: () => setState(() => _foto = !_foto)),
                    ],
                  ],
                ],
          rodape: ctx == null || info == null
              ? null
              : BotaoAcao(
                  rotulo: _retirei == true ? 'Registrar retirada' : 'Avisar o dono',
                  icone: Icons.send_rounded,
                  onPressed: _retirei == null || (_retirei == true && _local == LocalRoupa.secadora && _secadoraId == null)
                      ? null
                      : () => _enviar(ctx, info),
                ),
        );
      },
    );
  }

  Future<void> _enviar(ContextoAcao ctx, InfoRoupaMaquina info) async {
    var forcar = false;
    if (_retirei == true && !info.prazoPassou) {
      forcar = await confirmar(context,
          titulo: 'Retirar antes do prazo?',
          texto: 'O dono ainda tem tempo para buscar a roupa. Se você continuar, o dono será avisado e o síndico será informado.',
          sim: 'Retirar mesmo assim',
          perigo: true);
      if (!forcar) return;
    }
    final secadoras = (ref.read(maquinasProvider).value ?? const <Maquina>[]).where((m) => m.id == _secadoraId);
    final texto = switch (_local) {
      LocalRoupa.secadora => secadoras.isEmpty ? 'Secadora' : secadoras.first.nome,
      LocalRoupa.outro => _outro.text.isEmpty ? 'Outro lugar' : _outro.text,
      _ => nomeLocal(_local),
    };
    final repo = ref.read(lavanderonRepositoryProvider);
    await repo.roupaNaMaquina(quem: ctx.quem, maquinaId: info.maquina.id, retirei: _retirei!, local: _retirei! ? _local : null, localTexto: _retirei! ? texto : null, forcarAntecipada: forcar);
    if (!mounted) return;
    if (_retirei == false) {
      mostrarSucesso(context, info.donoApto == null ? 'Registro feito. O síndico vai identificar o dono.' : 'Aviso enviado ao dono.');
      Navigator.pop(context);
      return;
    }
    final usar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Cores.livre, size: 40),
        title: const Text('Retirada registrada'),
        content: Text('${info.donoApto == null ? 'A roupa aparece em "Roupas retiradas" até o dono buscar.' : 'O Ap ${info.donoApto} foi avisado de que a roupa está em: $texto.'}\n\nQuer usar a ${info.maquina.nome} agora?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Usar agora')),
        ],
      ),
    );
    if (!mounted) return;
    if (usar == true) {
      final maq = (ref.read(maquinasProvider).value ?? const <Maquina>[]).firstWhere((m) => m.id == info.maquina.id, orElse: () => info.maquina);
      await fluxoUsarAgora(context, ref, maq, ctx);
    }
    if (mounted) Navigator.pop(context);
  }
}

class _SituacaoPrazo extends StatelessWidget {
  const _SituacaoPrazo({required this.info, required this.agora});
  final InfoRoupaMaquina info;
  final DateTime agora;
  @override
  Widget build(BuildContext context) {
    final fim = info.fimCiclo, prazo = info.prazoRetirada;
    final cor = info.prazoPassou ? Cores.pronta : Cores.reservada;
    return CartaoBase(
      corBorda: cor.withValues(alpha: 0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconeMaquina(info.maquina.tipo, cor: cor),
          const SizedBox(width: 12),
          Expanded(child: Text(info.maquina.nome, style: Theme.of(context).textTheme.titleMedium)),
          Selo(cor: cor, texto: info.prazoPassou ? 'Prazo passou' : 'No prazo do dono', icone: info.prazoPassou ? Icons.check_rounded : Icons.hourglass_top_rounded),
        ]),
        const SizedBox(height: 10),
        if (fim != null) LinhaInfo(Icons.flag_rounded, 'Ciclo terminou às ${Fmt.hora(fim)} (${Fmt.relativo(fim, agora)})'),
        if (prazo != null) LinhaInfo(Icons.hourglass_bottom_rounded, info.prazoPassou ? 'Prazo para o dono retirar acabou às ${Fmt.hora(prazo)}' : 'O dono pode retirar até ${Fmt.hora(prazo)}'),
        LinhaInfo(Icons.person_search_rounded, info.donoApto == null ? 'Dono desconhecido (ninguém confirmou uso)' : 'Último uso confirmado: Ap ${info.donoApto}'),
      ]),
    );
  }
}

// ───────────────────────── Minha roupa foi retirada (6.10 B) ─────────────────────────

class MinhaRoupaRetiradaPagina extends ConsumerStatefulWidget {
  const MinhaRoupaRetiradaPagina({super.key, this.maquinaId});
  final String? maquinaId;
  @override
  ConsumerState<MinhaRoupaRetiradaPagina> createState() => _MinhaRoupaState();
}

class _MinhaRoupaState extends ConsumerState<MinhaRoupaRetiradaPagina> {
  late String? _maq = widget.maquinaId;
  LocalRoupa? _onde;
  final _coment = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contextoAcaoProvider);
    return PaginaFluxo(
      titulo: 'Minha roupa foi retirada',
      filhos: ctx == null
          ? [_semIdentificacao()]
          : [
              const Text('Vamos conferir os horários. Se a roupa foi retirada antes do seu prazo, o síndico é informado.', style: TextStyle(color: Cores.textoSuave)),
              const _Rotulo('De qual máquina?'),
              SeletorMaquina(selecionada: _maq, onChanged: (m) => setState(() => _maq = m.id)),
              const _Rotulo('Onde você encontrou?'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in LocalRoupa.values)
                  ChoiceChip(
                    avatar: Icon(iconeLocal(l), size: 18, color: _onde == l ? Colors.white : Cores.marca),
                    label: Text(nomeLocal(l)),
                    selected: _onde == l,
                    onSelected: (_) => setState(() => _onde = l),
                  ),
              ]),
              const _Rotulo('Comentário (opcional)'),
              TextField(controller: _coment, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex.: estava molhada em cima do balcão')),
            ],
      rodape: ctx == null
          ? null
          : BotaoAcao(
              rotulo: 'Enviar',
              icone: Icons.send_rounded,
              onPressed: _maq == null || _onde == null
                  ? null
                  : () async {
                      await ref.read(lavanderonRepositoryProvider).minhaRoupaFoiRetirada(quem: ctx.quem, maquinaId: _maq!, ondeEncontrou: _onde!, comentario: _coment.text.isEmpty ? null : _coment.text);
                      if (!context.mounted) return;
                      mostrarSucesso(context, 'Registrado. Veja a resposta em Avisos.');
                      Navigator.pop(context);
                    },
            ),
    );
  }
}
