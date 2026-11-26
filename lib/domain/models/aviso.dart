enum CategoriaAviso { reserva, cronometro, roupa, conduta, ocorrencia, sistema, sindico }

class Aviso {
  const Aviso({
    required this.id,
    required this.aptoId,
    required this.titulo,
    required this.corpo,
    required this.categoria,
    required this.criadoEm,
    this.lido = false,
    this.rota,
  });

  final String id;
  final String aptoId;
  final String titulo;
  final String corpo;
  final CategoriaAviso categoria;
  final DateTime criadoEm;
  final bool lido;

  /// Rota para abrir ao tocar, ex.: "/reserva/r12".
  final String? rota;

  Aviso copyWith({bool? lido}) => Aviso(
        id: id,
        aptoId: aptoId,
        titulo: titulo,
        corpo: corpo,
        categoria: categoria,
        criadoEm: criadoEm,
        lido: lido ?? this.lido,
        rota: rota,
      );
}
