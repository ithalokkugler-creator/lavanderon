import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dominio.dart';
import '../../tema/tema.dart';
import '../../widgets/base.dart';
import '../../widgets/logo.dart';

class _Aba {
  const _Aba(this.rota, this.rotulo, this.icone, this.iconeAtivo);
  final String rota, rotulo;
  final IconData icone, iconeAtivo;
}

const _abas = [
  _Aba('/m/inicio', 'Início', Icons.home_outlined, Icons.home_rounded),
  _Aba('/m/reservar', 'Reservar', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  _Aba('/m/noticias', 'Notícias', Icons.campaign_outlined, Icons.campaign_rounded),
  _Aba('/m/tutoriais', 'Tutoriais', Icons.menu_book_outlined, Icons.menu_book_rounded),
  _Aba('/m/mais', 'Mais', Icons.grid_view_outlined, Icons.grid_view_rounded),
];

/// Moldura do morador: barra inferior no celular, menu lateral no tablet/computador.
class ShellMorador extends ConsumerWidget {
  const ShellMorador({super.key, required this.child, required this.local});
  final Widget child;
  final String local;

  int get _indice {
    for (var i = 0; i < _abas.length; i++) {
      if (local.startsWith(_abas[i].rota)) return i;
    }
    if (local.startsWith('/m/noticia')) return 2;
    if (local.startsWith('/m/tutorial')) return 3;
    if (local.startsWith('/m/maquina') || local.startsWith('/m/reserva/')) return 0;
    return 4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final largura = MediaQuery.sizeOf(context).width;
    final sessao = ref.watch(sessaoProvider);
    final m = sessao.morador;
    final naoLidas = m == null ? 0 : (ref.watch(noticiasProvider).value ?? const []).where((n) => !n.lida).length;
    final i = _indice;

    if (largura < Medidas.breakTablet) {
      return Scaffold(
        body: child,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Cores.borda))),
          child: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (n) => context.go(_abas[n].rota),
            destinations: [
              for (var k = 0; k < _abas.length; k++)
                NavigationDestination(
                  icon: Contador(k == 2 ? naoLidas : 0, child: Icon(_abas[k].icone)),
                  selectedIcon: Icon(_abas[k].iconeAtivo),
                  label: _abas[k].rotulo,
                ),
            ],
          ),
        ),
      );
    }

    final extendido = largura >= Medidas.breakDesktop;
    return Scaffold(
      body: Row(children: [
        Container(
          width: extendido ? 248 : 88,
          decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Cores.borda))),
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: 22),
              extendido ? const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: Align(alignment: Alignment.centerLeft, child: LogoLavanderon(altura: 26, comAssinatura: true))) : const PortaLogo(tamanho: 40),
              const SizedBox(height: 26),
              for (var k = 0; k < _abas.length; k++)
                _ItemMenu(
                  aba: _abas[k],
                  ativo: k == i,
                  extendido: extendido,
                  contador: k == 2 ? naoLidas : 0,
                  onTap: () => context.go(_abas[k].rota),
                ),
              const Spacer(),
              if (m != null)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: extendido
                      ? CartaoBase(
                          padding: const EdgeInsets.all(12),
                          cor: Cores.fundo,
                          child: Row(children: [
                            CircleAvatar(backgroundColor: Cores.marca, child: Text(m.nome.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('Apartamento ${m.aptoId}', style: const TextStyle(color: Cores.textoSuave, fontSize: 12.5)),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Sair',
                              icon: const Icon(Icons.logout_rounded, size: 20),
                              onPressed: () {
                                ref.read(sessaoProvider.notifier).sair();
                                context.go('/entrar');
                              },
                            ),
                          ]),
                        )
                      : CircleAvatar(backgroundColor: Cores.marca, child: Text(m.nome.characters.first, style: const TextStyle(color: Colors.white))),
                ),
            ]),
          ),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.aba, required this.ativo, required this.extendido, required this.contador, required this.onTap});
  final _Aba aba;
  final bool ativo, extendido;
  final int contador;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cor = ativo ? Cores.marca : Cores.textoSuave;
    final icone = Contador(contador, child: Icon(ativo ? aba.iconeAtivo : aba.icone, color: cor));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: ativo ? Cores.fundoDe(Cores.marca) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: extendido ? 14 : 0, vertical: 12),
            child: extendido
                ? Row(children: [icone, const SizedBox(width: 14), Text(aba.rotulo, style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 15))])
                : Column(children: [icone, const SizedBox(height: 4), Text(aba.rotulo, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 11.5))]),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho padrão das páginas internas do morador.
class PaginaMorador extends StatelessWidget {
  const PaginaMorador({super.key, required this.titulo, required this.filhos, this.acoes, this.voltar = false, this.subtitulo, this.fab});
  final String titulo;
  final String? subtitulo;
  final List<Widget> filhos;
  final List<Widget>? acoes;
  final bool voltar;
  final Widget? fab;
  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= Medidas.breakTablet;
    return Scaffold(
      floatingActionButton: fab,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: voltar ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.canPop() ? context.pop() : context.go('/m/inicio')) : null,
        toolbarHeight: largo ? 76 : 60,
        titleSpacing: voltar ? 0 : (largo ? 32 : 20),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: largo ? Theme.of(context).textTheme.headlineSmall : null),
          if (subtitulo != null) Text(subtitulo!, style: const TextStyle(fontSize: 13, color: Cores.textoSuave, fontWeight: FontWeight.w600)),
        ]),
        actions: [...?acoes, const SizedBox(width: 8)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(largo ? 32 : 16, 4, largo ? 32 : 16, 96),
        children: [ConteudoLimitado(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos))],
      ),
    );
  }
}
