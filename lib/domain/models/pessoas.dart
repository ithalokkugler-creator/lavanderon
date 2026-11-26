enum Perfil { morador, tablet, sindico }

class Apartamento {
  const Apartamento({
    required this.id,
    required this.andar,
    this.existe = true,
    this.ativo = true,
    this.moradoresNomes = const [],
  });

  final String id;
  final int andar;

  /// Nem todo número 101–620 existe (ex.: 119, 120).
  final bool existe;

  /// `false` = suspenso (não paga): só consulta o app (RN-19).
  final bool ativo;
  final List<String> moradoresNomes;

  Apartamento copyWith({
    bool? existe,
    bool? ativo,
    List<String>? moradoresNomes,
  }) =>
      Apartamento(
        id: id,
        andar: andar,
        existe: existe ?? this.existe,
        ativo: ativo ?? this.ativo,
        moradoresNomes: moradoresNomes ?? this.moradoresNomes,
      );
}

class Morador {
  const Morador({
    required this.id,
    required this.aptoId,
    required this.nome,
    this.ativo = true,
  });

  final String id;
  final String aptoId;
  final String nome;
  final bool ativo;

  Morador copyWith({String? nome, bool? ativo}) => Morador(
        id: id,
        aptoId: aptoId,
        nome: nome ?? this.nome,
        ativo: ativo ?? this.ativo,
      );
}
