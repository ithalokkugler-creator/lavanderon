import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/dominio.dart';
import '../ui/telas/entrada_tela.dart';
import '../ui/telas/morador/conteudo_telas.dart';
import '../ui/telas/morador/inicio_tela.dart';
import '../ui/telas/morador/mais_telas.dart';
import '../ui/telas/morador/maquina_tela.dart';
import '../ui/telas/morador/reserva_tela.dart';
import '../ui/telas/morador/reservar_tela.dart';
import '../ui/telas/morador/shell_morador.dart';
import '../ui/telas/sindico/sindico_gestao.dart';
import '../ui/telas/sindico/sindico_operacao.dart';
import '../ui/telas/sindico/sindico_shell.dart';
import '../ui/telas/tablet/tablet_tela.dart';

/// Rotas do Lavanderon. Usa a estratégia de URL com "#" (padrão do Flutter Web),
/// que funciona no GitHub Pages sem configuração de servidor.
final routerProvider = Provider<GoRouter>((ref) {
  final mudou = ValueNotifier(0);
  ref.listen(sessaoProvider, (_, _) => mudou.value++);
  ref.onDispose(mudou.dispose);

  Page<void> semTransicao(Widget w, GoRouterState s) => NoTransitionPage(key: s.pageKey, child: w);

  return GoRouter(
    initialLocation: '/entrar',
    refreshListenable: mudou,
    redirect: (context, state) {
      final s = ref.read(sessaoProvider);
      final p = state.uri.path;
      if (p == '/' || p.isEmpty) return '/entrar';
      if (p.startsWith('/m/') && (s.perfil != Perfil.morador || s.morador == null)) return '/entrar';
      if (p.startsWith('/sindico') && (s.perfil != Perfil.sindico || s.adminNome == null)) return '/entrar';
      if (p.startsWith('/tablet') && s.perfil != Perfil.tablet) return '/entrar';
      return null;
    },
    routes: [
      GoRoute(path: '/entrar', builder: (_, _) => const EntradaTela()),
      GoRoute(path: '/tablet', builder: (_, _) => const TabletTela()),
      ShellRoute(
        builder: (context, state, child) => ShellMorador(local: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/m/inicio', pageBuilder: (_, s) => semTransicao(const InicioTela(), s)),
          GoRoute(
            path: '/m/reservar',
            pageBuilder: (_, s) => semTransicao(
              ReservarTela(key: ValueKey(s.uri.query), tipoInicial: s.uri.queryParameters['tipo'] == 'secadora' ? TipoMaquina.secadora : (s.uri.queryParameters['tipo'] == 'lavadora' ? TipoMaquina.lavadora : null)),
              s,
            ),
          ),
          GoRoute(path: '/m/noticias', pageBuilder: (_, s) => semTransicao(const NoticiasTela(), s)),
          GoRoute(path: '/m/tutoriais', pageBuilder: (_, s) => semTransicao(const TutoriaisTela(), s)),
          GoRoute(path: '/m/mais', pageBuilder: (_, s) => semTransicao(const MaisTela(), s)),
          GoRoute(path: '/m/maquina/:id', builder: (_, s) => MaquinaTela(maquinaId: s.pathParameters['id']!)),
          GoRoute(path: '/m/reserva/:id', builder: (_, s) => ReservaTela(reservaId: s.pathParameters['id']!)),
          GoRoute(path: '/m/noticia/:id', builder: (_, s) => NoticiaTela(id: s.pathParameters['id']!)),
          GoRoute(path: '/m/tutorial/:id', builder: (_, s) => TutorialTela(id: s.pathParameters['id']!)),
          GoRoute(path: '/m/reservas', builder: (_, _) => const MinhasReservasTela()),
          GoRoute(path: '/m/historico', builder: (_, _) => const HistoricoTela()),
          GoRoute(path: '/m/avisos', builder: (_, _) => const AvisosTela()),
          GoRoute(path: '/m/roupas', builder: (_, _) => const RoupasTela()),
          GoRoute(path: '/m/ocorrencias', builder: (_, _) => const OcorrenciasMoradorTela()),
          GoRoute(path: '/m/sugestoes', builder: (_, _) => const SugestoesTela()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ShellSindico(local: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/sindico/painel', pageBuilder: (_, s) => semTransicao(const PainelSindicoTela(), s)),
          GoRoute(path: '/sindico/agenda', pageBuilder: (_, s) => semTransicao(const AgendaSindicoTela(), s)),
          GoRoute(path: '/sindico/maquinas', pageBuilder: (_, s) => semTransicao(const MaquinasSindicoTela(), s)),
          GoRoute(path: '/sindico/ocorrencias', pageBuilder: (_, s) => semTransicao(const OcorrenciasSindicoTela(), s)),
          GoRoute(path: '/sindico/apartamentos', pageBuilder: (_, s) => semTransicao(const ApartamentosSindicoTela(), s)),
          GoRoute(path: '/sindico/comunicados', pageBuilder: (_, s) => semTransicao(const ComunicadosSindicoTela(), s)),
          GoRoute(path: '/sindico/estatisticas', pageBuilder: (_, s) => semTransicao(const EstatisticasSindicoTela(), s)),
          GoRoute(path: '/sindico/config', pageBuilder: (_, s) => semTransicao(const ConfigSindicoTela(), s)),
        ],
      ),
    ],
  );
});
