import 'package:collection/collection.dart';

import '../../core/formatos.dart';
import '../../domain/app_erro.dart';
import '../../domain/models/models.dart';
import 'estado_demo.dart';
import 'regras_problemas.dart';

/// Ações do síndico: máquinas, ocorrências, apartamentos, comunicados e
/// fechamento da lavanderia (RN-16, RN-18, RN-19, RN-29).
class RegrasAdmin {
  RegrasAdmin(this.e, this.problemas);
  final EstadoDemo e;
  final RegrasProblemas problemas;

  // ---------------------------------------------------------------- Máquinas

  void bloquearMaquina(String maquinaId, String motivo) {
    problemas.bloquear(maquinaId, motivo, problemas.bloqueioAte(e.agora));
  }

  void liberarMaquina(String maquinaId) {
    final m = e.maquinaBase(maquinaId);
    e.maquinas[maquinaId] = m.copyWith(
      status: StatusMaquina.disponivel,
      motivoIndisponivel: null,
      indisponivelAte: null,
    );
  }

  void colocarManutencao(String maquinaId, String motivo, DateTime? previsao) {
    final m = e.maquinaBase(maquinaId);
    e.maquinas[maquinaId] = m.copyWith(
      status: StatusMaquina.manutencao,
      motivoIndisponivel: motivo,
      indisponivelAte: previsao,
    );
    problemas.tratarReservasAfetadas(maquinaId, previsao);
  }

  void voltarCirculacao(String maquinaId) => liberarMaquina(maquinaId);

  // -------------------------------------------------------------- Ocorrências

  void atualizarOcorrencia(String id, StatusOcorrencia status,
      {String? resposta}) {
    final o = e.ocorrencia(id);
    e.salvarOcorrencia(o.copyWith(
      status: status,
      resposta: resposta ?? o.resposta,
    ));
    if (status == StatusOcorrencia.resolvida &&
        o.bloqueouMaquina &&
        o.maquinaId != null) {
      final m = e.maquinas[o.maquinaId!];
      if (m != null && m.status == StatusMaquina.bloqueadaHoje) {
        liberarMaquina(m.id);
      }
    }
    if (o.relatorApto != null) {
      final rotulo = switch (status) {
        StatusOcorrencia.aberta => 'aberta',
        StatusOcorrencia.emAndamento => 'em andamento',
        StatusOcorrencia.resolvida => 'resolvida',
        StatusOcorrencia.descartada => 'encerrada',
      };
      e.avisar(
        o.relatorApto!,
        'Sua ocorrência está $rotulo',
        '"${o.categoria}"${o.maquinaNome != null ? ' (${o.maquinaNome})' : ''}.${resposta != null && resposta.trim().isNotEmpty ? ' Resposta do síndico: $resposta' : ''}',
        CategoriaAviso.ocorrencia,
      );
    }
  }

  void enviarAvisoConduta(String ocorrenciaId) {
    final o = e.ocorrencia(ocorrenciaId);
    final apto = o.aptoProvavel;
    if (apto == null) {
      throw const AppErro('NAO_PERMITIDO',
          'Essa ocorrência não tem um apartamento identificado.');
    }
    final onde = o.maquinaNome != null ? ' (${o.maquinaNome})' : '';
    e.avisar(
      apto,
      'Aviso de conduta',
      switch (o.tipo) {
        TipoOcorrencia.roupaRetirada =>
          'Uma roupa de outro morador foi retirada antes do prazo$onde. O síndico foi informado e pede mais atenção às regras da lavanderia.',
        _ =>
          'Houve um problema de uso em horário reservado$onde ligado ao seu apartamento. O síndico foi informado e pede mais atenção aos horários.',
      },
      CategoriaAviso.conduta,
    );
    e.salvarOcorrencia(o.copyWith(avisoCondutaEnviado: true));
  }

  void responderAvisoConduta(String ocorrenciaId, String texto) {
    final o = e.ocorrencia(ocorrenciaId);
    e.salvarOcorrencia(o.copyWith(respostaApto: texto.trim()));
    e.avisar(
      'sindico',
      'Resposta a um aviso de conduta',
      'O Ap ${o.aptoProvavel ?? '?'} respondeu sobre "${o.categoria}": ${texto.trim()}',
      CategoriaAviso.conduta,
    );
  }

  // ------------------------------------------------------------ Apartamentos

  void definirAptoAtivo(String aptoId, bool ativo) {
    final i = e.apartamentos.indexWhere((a) => a.id == aptoId);
    if (i < 0) {
      throw const AppErro('APTO_INEXISTENTE', 'Apartamento não encontrado.');
    }
    e.apartamentos[i] = e.apartamentos[i].copyWith(ativo: ativo);
    e.avisar(
      aptoId,
      ativo ? 'Acesso liberado' : 'Acesso suspenso',
      ativo
          ? 'O acesso do seu apartamento à lavanderia foi reativado.'
          : 'O acesso do seu apartamento à lavanderia foi suspenso. Fale com o síndico.',
      CategoriaAviso.sindico,
    );
  }

  // --------------------------------------------------------------- Comunicados

  void publicarNoticia({
    required String titulo,
    required String corpo,
    required PrioridadeNoticia prioridade,
    bool fixada = false,
  }) {
    final primeiro = corpo
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^(##\s+|-\s+)'), '').trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => titulo);
    final resumo =
        primeiro.length > 120 ? '${primeiro.substring(0, 117)}...' : primeiro;
    final n = Noticia(
      id: e.novoId('n'),
      titulo: titulo,
      resumo: resumo,
      corpo: corpo,
      prioridade: prioridade,
      publicadaEm: e.agora,
      fixada: fixada,
    );
    e.noticias.add(n);
    if (prioridade != PrioridadeNoticia.informativo) {
      for (final a in e.apartamentos.where((a) => a.existe)) {
        e.avisar(a.id, titulo, resumo, CategoriaAviso.sindico);
      }
    }
  }

  // --------------------------------------------------------------- Fechamento

  bool _afetaFechamento(Reserva r, DateTime agora, DateTime? ate) =>
      (r.status == StatusReserva.agendada ||
          r.status == StatusReserva.precisaAcao) &&
      r.fim.isAfter(agora) &&
      (ate == null || r.inicio.isBefore(ate));

  int impactoFechamento(DateTime? ate) {
    final agora = e.agora;
    return e.reservas.values.where((r) => _afetaFechamento(r, agora, ate)).length;
  }

  int fecharLavanderia(String motivo, {DateTime? ate}) {
    final agora = e.agora;
    for (var i = 0; i < e.fechamentos.length; i++) {
      if (e.fechamentos[i].ativo) {
        e.fechamentos[i] = e.fechamentos[i].copyWith(ativo: false, fim: agora);
      }
    }
    e.fechamentos.add(Fechamento(
      id: e.novoId('f'),
      motivo: motivo,
      inicio: agora,
      fim: ate,
    ));
    final alvo = e.reservas.values
        .where((r) => _afetaFechamento(r, agora, ate))
        .toList();
    for (final r in alvo) {
      e.salvarReserva(r.copyWith(
        status: StatusReserva.cancelada,
        motivoCancelamento: 'Lavanderia fechada: $motivo',
        historico: [
          ...r.historico,
          e.linha('Cancelada: lavanderia fechada ($motivo), sem penalidade'),
        ],
      ));
      e.avisar(
        r.aptoId,
        'Reserva cancelada: lavanderia fechada',
        'Sua reserva das ${hora(r.inicio)} (${dataCurta(r.inicio)}) na ${r.maquinaNome} foi cancelada porque a lavanderia estará fechada: $motivo. Sem penalidade.',
        CategoriaAviso.reserva,
        rota: '/reserva/${r.id}',
      );
    }
    return alvo.length;
  }

  void reabrirLavanderia() {
    final agora = e.agora;
    for (var i = 0; i < e.fechamentos.length; i++) {
      final f = e.fechamentos[i];
      if (f.ativo) {
        e.fechamentos[i] = f.copyWith(ativo: false, fim: agora);
      }
    }
  }

  void cancelarReservaAdmin(String reservaId, String motivo) {
    final r = e.reserva(reservaId);
    if (r.status != StatusReserva.agendada &&
        r.status != StatusReserva.precisaAcao) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não pode mais ser cancelada.');
    }
    e.salvarReserva(r.copyWith(
      status: StatusReserva.cancelada,
      motivoCancelamento: motivo,
      historico: [
        ...r.historico,
        e.linha('Cancelada pelo síndico: $motivo'),
      ],
    ));
    e.avisar(
      r.aptoId,
      'Reserva cancelada pelo síndico',
      'Sua reserva das ${hora(r.inicio)} (${dataCurta(r.inicio)}) na ${r.maquinaNome} foi cancelada: $motivo.',
      CategoriaAviso.reserva,
      rota: '/reserva/${r.id}',
    );
  }

  // ------------------------------------------------------------ Sugestões etc.

  void criarSugestao({
    required Morador quem,
    required String titulo,
    required String descricao,
    required String categoria,
  }) {
    e.sugestoes.add(Sugestao(
      id: e.novoId('s'),
      titulo: titulo,
      descricao: descricao,
      categoria: categoria,
      aptoAutor: quem.aptoId,
      criadaEm: e.agora,
    ));
  }

  void votarSugestao(String id, Morador quem) {
    final i = e.sugestoes.indexWhere((s) => s.id == id);
    if (i < 0) {
      throw const AppErro('NAO_ENCONTRADO', 'Sugestão não encontrada.');
    }
    final votantes = e.votos.putIfAbsent(id, () => <String>{});
    final s = e.sugestoes[i];
    if (votantes.remove(quem.id)) {
      e.sugestoes[i] = s.copyWith(votos: (s.votos - 1).clamp(0, 1 << 30));
    } else {
      votantes.add(quem.id);
      e.sugestoes[i] = s.copyWith(votos: s.votos + 1);
    }
    e.moradorAtualId = quem.id;
  }

  void marcarAvisoLido(String avisoId) {
    final i = e.avisos.indexWhere((a) => a.id == avisoId);
    if (i >= 0) e.avisos[i] = e.avisos[i].copyWith(lido: true);
  }

  void marcarNoticiaLida(String id) {
    final i = e.noticias.indexWhere((n) => n.id == id);
    if (i < 0) return;
    final n = e.noticias[i];
    if (n.lida) return;
    e.noticias[i] = n.copyWith(lida: true, leituras: n.leituras + 1);
  }

  /// Ordem de exibição das notícias: fixadas primeiro, depois mais novas.
  List<Noticia> noticiasOrdenadas() => e.noticias.toList()
    ..sort((a, b) {
      if (a.fixada != b.fixada) return a.fixada ? -1 : 1;
      return b.publicadaEm.compareTo(a.publicadaEm);
    });

  Maquina? maquinaPorNome(String nome) =>
      e.maquinas.values.firstWhereOrNull((m) => m.nome == nome);
}
