import 'maquina.dart';

enum PrioridadeNoticia { informativo, importante, urgente }

class Noticia {
  const Noticia({
    required this.id,
    required this.titulo,
    required this.resumo,
    required this.corpo,
    this.prioridade = PrioridadeNoticia.informativo,
    required this.publicadaEm,
    this.fixada = false,
    this.autor = 'Síndico',
    this.leituras = 0,
    this.lida = false,
  });

  final String id;
  final String titulo;
  final String resumo;

  /// Parágrafos separados por linha em branco; linhas "- " são itens de lista
  /// e linhas "## " são subtítulos.
  final String corpo;
  final PrioridadeNoticia prioridade;
  final DateTime publicadaEm;
  final bool fixada;
  final String autor;
  final int leituras;
  final bool lida;

  Noticia copyWith({
    String? titulo,
    String? resumo,
    String? corpo,
    PrioridadeNoticia? prioridade,
    bool? fixada,
    int? leituras,
    bool? lida,
  }) =>
      Noticia(
        id: id,
        titulo: titulo ?? this.titulo,
        resumo: resumo ?? this.resumo,
        corpo: corpo ?? this.corpo,
        prioridade: prioridade ?? this.prioridade,
        publicadaEm: publicadaEm,
        fixada: fixada ?? this.fixada,
        autor: autor,
        leituras: leituras ?? this.leituras,
        lida: lida ?? this.lida,
      );
}

class PassoTutorial {
  const PassoTutorial({required this.titulo, required this.texto, this.dica});
  final String titulo;
  final String texto;
  final String? dica;
}

class Tutorial {
  const Tutorial({
    required this.id,
    required this.titulo,
    required this.resumo,
    required this.categoria,
    this.tipoMaquina,
    required this.minutos,
    required this.passos,
  });

  final String id;
  final String titulo;
  final String resumo;
  final String categoria;
  final TipoMaquina? tipoMaquina;

  /// Tempo estimado de leitura.
  final int minutos;
  final List<PassoTutorial> passos;
}

enum StatusSugestao {
  recebida('Recebida'),
  emAvaliacao('Em avaliação'),
  planejada('Planejada'),
  implementada('Implementada'),
  recusada('Recusada');

  const StatusSugestao(this.rotulo);
  final String rotulo;
}

class Sugestao {
  const Sugestao({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.categoria,
    this.status = StatusSugestao.recebida,
    this.votos = 0,
    this.votadaPorMim = false,
    this.resposta,
    required this.aptoAutor,
    required this.criadaEm,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String categoria;
  final StatusSugestao status;
  final int votos;
  final bool votadaPorMim;
  final String? resposta;
  final String aptoAutor;
  final DateTime criadaEm;

  Sugestao copyWith({
    StatusSugestao? status,
    int? votos,
    bool? votadaPorMim,
    String? resposta,
  }) =>
      Sugestao(
        id: id,
        titulo: titulo,
        descricao: descricao,
        categoria: categoria,
        status: status ?? this.status,
        votos: votos ?? this.votos,
        votadaPorMim: votadaPorMim ?? this.votadaPorMim,
        resposta: resposta ?? this.resposta,
        aptoAutor: aptoAutor,
        criadaEm: criadaEm,
      );
}
