import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dominio.dart';

/// Quem está agindo e de onde. As telas de reserva e relato são as mesmas
/// no celular e no tablet; só muda a origem registrada.
class ContextoAcao {
  const ContextoAcao(this.quem, this.origem);
  final Morador quem;
  final OrigemAcao origem;
  String get aptoId => quem.aptoId;
}

final contextoAcaoProvider = Provider<ContextoAcao?>((ref) {
  final s = ref.watch(sessaoProvider);
  if (s.perfil == Perfil.tablet) {
    final m = s.moradorTablet;
    return m == null ? null : ContextoAcao(m, OrigemAcao.tablet);
  }
  final m = s.morador;
  return m == null ? null : ContextoAcao(m, OrigemAcao.app);
});

/// Apartamento do morador atual está ativo (paga a mensalidade)?
final aptoAtivoProvider = Provider<bool>((ref) {
  final ctx = ref.watch(contextoAcaoProvider);
  if (ctx == null) return false;
  final aptos = ref.watch(apartamentosProvider).value ?? const [];
  for (final a in aptos) {
    if (a.id == ctx.aptoId) return a.ativo;
  }
  return true;
});

/// Como a demonstração é exibida numa tela grande (projetor/computador).
enum ModoTela { livre, celular, tablet }

class ModoTelaNotifier extends Notifier<ModoTela> {
  @override
  ModoTela build() => ModoTela.livre;
  void definir(ModoTela m) => state = m;
}

final modoTelaProvider = NotifierProvider<ModoTelaNotifier, ModoTela>(ModoTelaNotifier.new);

/// Painel de demonstração aberto/fechado.
class PainelDemoAberto extends Notifier<bool> {
  @override
  bool build() => false;
  void definir(bool v) => state = v;
  void alternar() => state = !state;
}

final painelDemoProvider = NotifierProvider<PainelDemoAberto, bool>(PainelDemoAberto.new);
