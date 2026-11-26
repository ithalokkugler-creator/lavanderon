/// Erro de regra de negócio. `codigo` segue a seção 14.6 do plano
/// (SLOT_OCUPADO, LIMITE, FECHADA, ...); `mensagem` já está em português,
/// pronta para exibir ao morador.
class AppErro implements Exception {
  const AppErro(this.codigo, this.mensagem);

  final String codigo;
  final String mensagem;

  @override
  String toString() => 'AppErro($codigo): $mensagem';
}
