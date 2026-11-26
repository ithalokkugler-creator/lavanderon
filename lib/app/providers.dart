import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo/demo_lavanderon_repository.dart';
import '../domain/lavanderon_repository.dart';
import '../domain/models/models.dart';

/// PONTO ÚNICO DE TROCA: hoje devolve a demo em memória. Para usar o
/// Firebase, devolva aqui uma `FirebaseLavanderonRepository`.
final lavanderonRepositoryProvider = Provider<LavanderonRepository>((ref) {
  final repo = DemoLavanderonRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final agoraProvider = StreamProvider<DateTime>(
    (ref) => ref.watch(lavanderonRepositoryProvider).agora());

final maquinasProvider = StreamProvider<List<Maquina>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).maquinas());

final noticiasProvider = StreamProvider<List<Noticia>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).noticias());

final roupasRetiradasProvider = StreamProvider<List<RoupaRetirada>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).roupasRetiradas());

final fechamentoProvider = StreamProvider<Fechamento?>(
    (ref) => ref.watch(lavanderonRepositoryProvider).fechamentoAtivo());

final configProvider = StreamProvider<ConfigRegras>(
    (ref) => ref.watch(lavanderonRepositoryProvider).config());

final ocorrenciasProvider = StreamProvider<List<Ocorrencia>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).ocorrencias());

final sugestoesProvider = StreamProvider<List<Sugestao>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).sugestoes());

final apartamentosProvider = StreamProvider<List<Apartamento>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).apartamentos());

final moradoresProvider = StreamProvider<List<Morador>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).moradores());

/// Cada aviso novo no instante em que nasce (de TODOS os apartamentos: a UI
/// filtra pelo apartamento logado para mostrar toasts e alarmes).
final novosAvisosProvider = StreamProvider<Aviso>(
    (ref) => ref.watch(lavanderonRepositoryProvider).novosAvisos());

final reservasDoAptoProvider =
    StreamProvider.family<List<Reserva>, String>((ref, aptoId) =>
        ref.watch(lavanderonRepositoryProvider).reservasDoApto(aptoId));

final avisosProvider = StreamProvider.family<List<Aviso>, String>(
    (ref, aptoId) => ref.watch(lavanderonRepositoryProvider).avisos(aptoId));

final reservasDoDiaProvider = StreamProvider.family<List<Reserva>, DateTime>(
    (ref, dia) => ref.watch(lavanderonRepositoryProvider).reservasDoDia(dia));

final gradeProvider =
    StreamProvider.family<List<SlotGrade>, (DateTime, TipoMaquina)>(
        (ref, args) => ref
            .watch(lavanderonRepositoryProvider)
            .grade(args.$1, args.$2));

final tutoriaisProvider = FutureProvider<List<Tutorial>>(
    (ref) => ref.watch(lavanderonRepositoryProvider).tutoriais());

final estatisticasProvider = FutureProvider.autoDispose<Estatisticas>(
    (ref) => ref.watch(lavanderonRepositoryProvider).estatisticas());

// ------------------------------------------------------------------ Sessão

class Sessao {
  const Sessao({
    this.perfil = Perfil.morador,
    this.morador,
    this.adminNome,
    this.moradorTablet,
  });

  final Perfil perfil;

  /// Morador logado no celular/web.
  final Morador? morador;

  /// Nome do síndico/zelador logado.
  final String? adminNome;

  /// Morador identificado no tablet (some ao encerrar a sessão do tablet).
  final Morador? moradorTablet;

  /// Morador "efetivo" para as ações, conforme o perfil atual.
  Morador? get moradorEfetivo =>
      perfil == Perfil.tablet ? moradorTablet : morador;

  bool get logado => switch (perfil) {
        Perfil.morador => morador != null,
        Perfil.tablet => true,
        Perfil.sindico => adminNome != null,
      };

  Sessao copyWith({
    Perfil? perfil,
    Object? morador = _naoMuda,
    Object? adminNome = _naoMuda,
    Object? moradorTablet = _naoMuda,
  }) =>
      Sessao(
        perfil: perfil ?? this.perfil,
        morador: identical(morador, _naoMuda) ? this.morador : morador as Morador?,
        adminNome: identical(adminNome, _naoMuda)
            ? this.adminNome
            : adminNome as String?,
        moradorTablet: identical(moradorTablet, _naoMuda)
            ? this.moradorTablet
            : moradorTablet as Morador?,
      );
}

const Object _naoMuda = Object();

class SessaoNotifier extends Notifier<Sessao> {
  @override
  Sessao build() => const Sessao();

  void entrarMorador(Morador m) =>
      state = state.copyWith(perfil: Perfil.morador, morador: m);

  /// Sai de tudo e volta para a tela de entrada do morador.
  void sair() => state = const Sessao();

  void entrarSindico(String nome) =>
      state = state.copyWith(perfil: Perfil.sindico, adminNome: nome);

  void modoTablet() =>
      state = state.copyWith(perfil: Perfil.tablet, moradorTablet: null);

  void identificarNoTablet(Morador m) =>
      state = state.copyWith(perfil: Perfil.tablet, moradorTablet: m);

  void encerrarTablet() => state = state.copyWith(moradorTablet: null);

  void trocarPerfil(Perfil p) => state = state.copyWith(perfil: p);
}

final sessaoProvider =
    NotifierProvider<SessaoNotifier, Sessao>(SessaoNotifier.new);
