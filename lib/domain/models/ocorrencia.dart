import 'maquina.dart';
import 'reserva.dart';
import 'unset.dart';

enum TipoOcorrencia { maquina, lavanderia, usoIndevido, roupaEsquecida, roupaRetirada }

enum StatusOcorrencia { aberta, emAndamento, resolvida, descartada }

class Ocorrencia {
  const Ocorrencia({
    required this.id,
    required this.tipo,
    required this.categoria,
    this.maquinaId,
    this.maquinaNome,
    this.descricao,
    this.relatorApto,
    required this.relatorNome,
    this.origem = OrigemAcao.app,
    required this.criadaEm,
    this.status = StatusOcorrencia.aberta,
    this.bloqueouMaquina = false,
    this.urgente = false,
    this.confirmacoes = 1,
    this.deducao,
    this.aptoProvavel,
    this.deducaoConfiavel = false,
    this.avisoCondutaEnviado = false,
    this.resposta,
    this.respostaApto,
  });

  final String id;
  final TipoOcorrencia tipo;

  /// Rótulo legível ("Não centrifuga").
  final String categoria;
  final String? maquinaId;
  final String? maquinaNome;
  final String? descricao;
  final String? relatorApto;
  final String relatorNome;
  final OrigemAcao origem;
  final DateTime criadaEm;
  final StatusOcorrencia status;
  final bool bloqueouMaquina;
  final bool urgente;
  final int confirmacoes;

  /// Texto da dedução automática (só o síndico vê).
  final String? deducao;
  final String? aptoProvavel;
  final bool deducaoConfiavel;
  final bool avisoCondutaEnviado;

  /// Resposta do síndico.
  final String? resposta;

  /// Versão do apartamento notificado (RN-29).
  final String? respostaApto;

  bool get aberta =>
      status == StatusOcorrencia.aberta ||
      status == StatusOcorrencia.emAndamento;

  Ocorrencia copyWith({
    String? categoria,
    Object? descricao = kUnset,
    StatusOcorrencia? status,
    bool? bloqueouMaquina,
    bool? urgente,
    int? confirmacoes,
    Object? deducao = kUnset,
    Object? aptoProvavel = kUnset,
    bool? deducaoConfiavel,
    bool? avisoCondutaEnviado,
    Object? resposta = kUnset,
    Object? respostaApto = kUnset,
  }) =>
      Ocorrencia(
        id: id,
        tipo: tipo,
        categoria: categoria ?? this.categoria,
        maquinaId: maquinaId,
        maquinaNome: maquinaNome,
        descricao: escolher<String>(descricao, this.descricao),
        relatorApto: relatorApto,
        relatorNome: relatorNome,
        origem: origem,
        criadaEm: criadaEm,
        status: status ?? this.status,
        bloqueouMaquina: bloqueouMaquina ?? this.bloqueouMaquina,
        urgente: urgente ?? this.urgente,
        confirmacoes: confirmacoes ?? this.confirmacoes,
        deducao: escolher<String>(deducao, this.deducao),
        aptoProvavel: escolher<String>(aptoProvavel, this.aptoProvavel),
        deducaoConfiavel: deducaoConfiavel ?? this.deducaoConfiavel,
        avisoCondutaEnviado: avisoCondutaEnviado ?? this.avisoCondutaEnviado,
        resposta: escolher<String>(resposta, this.resposta),
        respostaApto: escolher<String>(respostaApto, this.respostaApto),
      );
}

enum LocalRoupa {
  balcao('Balcão'),
  cesto('Cesto'),
  secadora('Secadora'),
  outro('Outro lugar');

  const LocalRoupa(this.rotulo);
  final String rotulo;
}

class RoupaRetirada {
  const RoupaRetirada({
    required this.id,
    required this.maquinaId,
    required this.maquinaNome,
    required this.local,
    required this.localTexto,
    required this.desde,
    this.donoConhecido = false,
    this.donoApto,
    this.recolhidaEm,
    this.antecipada = false,
    this.localMaquinaId,
  });

  final String id;
  final String maquinaId;
  final String maquinaNome;
  final LocalRoupa local;

  /// Texto pronto para exibir: "Balcão da lavanderia", "Secadora 2"...
  final String localTexto;
  final DateTime desde;
  final bool donoConhecido;

  /// A UI só mostra este apartamento para o próprio dono ou para o síndico.
  final String? donoApto;
  final DateTime? recolhidaEm;
  final bool antecipada;

  /// ADIÇÃO: quando `local == secadora`, id da secadora que recebeu a roupa.
  final String? localMaquinaId;

  bool get recolhida => recolhidaEm != null;

  RoupaRetirada copyWith({
    Object? recolhidaEm = kUnset,
  }) =>
      RoupaRetirada(
        id: id,
        maquinaId: maquinaId,
        maquinaNome: maquinaNome,
        local: local,
        localTexto: localTexto,
        desde: desde,
        donoConhecido: donoConhecido,
        donoApto: donoApto,
        recolhidaEm: escolher<DateTime>(recolhidaEm, this.recolhidaEm),
        antecipada: antecipada,
        localMaquinaId: localMaquinaId,
      );
}

class InfoRoupaMaquina {
  const InfoRoupaMaquina({
    required this.maquina,
    this.donoApto,
    this.fimCiclo,
    this.prazoRetirada,
    this.prazoPassou = false,
    this.temRoupa = false,
  });

  final Maquina maquina;

  /// Dono provável (última reserva com uso confirmado). Só o apartamento
  /// dono ou o síndico devem ver este valor.
  final String? donoApto;
  final DateTime? fimCiclo;
  final DateTime? prazoRetirada;
  final bool prazoPassou;
  final bool temRoupa;
}
