import 'package:collection/collection.dart';

import '../../core/formatos.dart';
import '../../core/texto.dart';
import '../../domain/app_erro.dart';
import '../../domain/models/models.dart';
import 'derivacao.dart';
import 'estado_demo.dart';
import 'regras_reserva.dart';

/// Problemas em máquinas e na lavanderia, "máquina ocupada" e roupa na
/// máquina: RN-12 a RN-15, RN-28 e RN-29.
class RegrasProblemas {
  RegrasProblemas(this.e, this.d, this.reservas);
  final EstadoDemo e;
  final Derivacao d;
  final RegrasReserva reservas;

  // -------------------------------------------------------------- Bloqueios

  (int, int) _hm(String s) {
    final p = s.split(':');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  /// RN-12: até 23:59 do dia, ou até 08:00 para relatos a partir das 20:00.
  DateTime bloqueioAte(DateTime agora) {
    final (hDe, mDe) = _hm(e.config.bloqueioNoturnoDe);
    final (hAte, mAte) = _hm(e.config.bloqueioNoturnoAte);
    final minutos = agora.hour * 60 + agora.minute;
    final noturnoDe = hDe * 60 + mDe;
    final noturnoAte = hAte * 60 + mAte;
    final dia = inicioDoDia(agora);
    if (minutos < noturnoAte) {
      return dia.add(Duration(hours: hAte, minutes: mAte));
    }
    if (minutos >= noturnoDe) {
      return dia.add(Duration(days: 1, hours: hAte, minutes: mAte));
    }
    return DateTime(agora.year, agora.month, agora.day, 23, 59);
  }

  /// RN-13: realoca (ou marca "precisa de ação") as reservas agendadas da
  /// máquina que caem no período de indisponibilidade. `ate == null` afeta
  /// todas as futuras. Devolve quantas reservas foram afetadas.
  int tratarReservasAfetadas(String maquinaId, DateTime? ate) {
    final base = e.maquinaBase(maquinaId);
    final agora = e.agora;
    final afetadas = e.reservas.values
        .where((r) =>
            r.maquinaId == maquinaId &&
            r.status == StatusReserva.agendada &&
            r.fim.isAfter(agora) &&
            (ate == null || r.inicio.isBefore(ate)))
        .sortedBy<DateTime>((r) => r.inicio)
        .toList();
    for (final r in afetadas) {
      final alt = d
          .alternativas(r.tipo, r.inicio,
              excetoMaquinaId: maquinaId, excetoReserva: r.id)
          .firstOrNull;
      if (alt != null) {
        e.salvarReserva(r.copyWith(
          maquinaId: alt.id,
          maquinaNome: alt.nome,
          historico: [
            ...r.historico,
            e.linha(
                'Reserva movida da ${base.nome} para a ${alt.nome} (problema na máquina)'),
          ],
        ));
        e.avisar(
          r.aptoId,
          'Sua reserva foi movida para a ${alt.nome}',
          'A ${base.nome} teve um problema. Movemos sua reserva das ${hora(r.inicio)} para a ${alt.nome}, mesmo horário. Toque para trocar.',
          CategoriaAviso.reserva,
          rota: '/reserva/${r.id}',
        );
      } else {
        e.salvarReserva(r.copyWith(
          status: StatusReserva.precisaAcao,
          mensagemAcao:
              'A ${base.nome} teve um problema. Escolha outra máquina ou horário.',
          historico: [
            ...r.historico,
            e.linha('Precisa de ação: ${base.nome} indisponível e sem máquina equivalente livre'),
          ],
        ));
        e.avisar(
          r.aptoId,
          'Sua reserva precisa de ação',
          'A ${base.nome} teve um problema. Escolha outra máquina ou horário. Se nada for feito até as ${hora(r.inicio)}, a reserva será cancelada sem penalidade.',
          CategoriaAviso.reserva,
          rota: '/reserva/${r.id}',
        );
      }
    }
    return afetadas.length;
  }

  void bloquear(String maquinaId, String motivo, DateTime ate) {
    final m = e.maquinaBase(maquinaId);
    e.maquinas[maquinaId] = m.copyWith(
      status: StatusMaquina.bloqueadaHoje,
      motivoIndisponivel: motivo,
      indisponivelAte: ate,
    );
    tratarReservasAfetadas(maquinaId, ate);
  }

  // ------------------------------------------------------- Problema máquina

  void relatarProblemaMaquina({
    required Morador? quem,
    required String maquinaId,
    required String categoria,
    required bool impedeUso,
    String? descricao,
    OrigemAcao origem = OrigemAcao.app,
  }) {
    final m = e.maquinaBase(maquinaId);
    final agora = e.agora;
    final cat = normalizarTexto(categoria);

    final dup = e.ocorrencias.firstWhereOrNull((o) =>
        o.tipo == TipoOcorrencia.maquina &&
        o.maquinaId == maquinaId &&
        o.aberta &&
        mesmoDia(o.criadaEm, agora) &&
        normalizarTexto(o.categoria) == cat);

    if (dup != null) {
      final escalar = impedeUso && !dup.bloqueouMaquina;
      e.salvarOcorrencia(dup.copyWith(
        confirmacoes: dup.confirmacoes + 1,
        bloqueouMaquina: escalar ? true : null,
      ));
      if (escalar) bloquear(maquinaId, categoria, bloqueioAte(agora));
      return;
    }

    final o = Ocorrencia(
      id: e.novoId('o'),
      tipo: TipoOcorrencia.maquina,
      categoria: categoria,
      maquinaId: maquinaId,
      maquinaNome: m.nome,
      descricao: descricao,
      relatorApto: quem?.aptoId,
      relatorNome: quem?.nome ?? 'Síndico',
      origem: origem,
      criadaEm: agora,
      bloqueouMaquina: impedeUso,
      urgente: impedeUso,
    );
    e.ocorrencias.add(o);

    if (impedeUso) {
      bloquear(maquinaId, categoria, bloqueioAte(agora));
    }

    // O relator estava usando a máquina: a reserva dele é interrompida.
    if (quem != null) {
      final emUso = e.reservas.values.firstWhereOrNull((r) =>
          r.maquinaId == maquinaId &&
          r.aptoId == quem.aptoId &&
          r.status == StatusReserva.emUso);
      if (emUso != null) {
        e.salvarReserva(emUso.copyWith(
          status: StatusReserva.interrompida,
          historico: [
            ...emUso.historico,
            e.linha('Uso interrompido: problema relatado ("$categoria")'),
          ],
        ));
        e.aguardando.remove(maquinaId);
        final cuidado = (normalizarTexto(categoria).contains('porta') ||
                normalizarTexto(categoria).contains('vaz'))
            ? ' Não force a porta; avise o zelador.'
            : '';
        e.avisar(
          quem.aptoId,
          'Seu uso foi interrompido',
          'Registramos o problema na ${m.nome}. Você pode mover sua reserva para outra máquina livre agora.$cuidado',
          CategoriaAviso.ocorrencia,
          rota: '/reserva/${emUso.id}',
        );
      }
    }
  }

  void relatarProblemaLavanderia({
    required Morador quem,
    required String categoria,
    required bool urgente,
    String? descricao,
  }) {
    e.ocorrencias.add(Ocorrencia(
      id: e.novoId('o'),
      tipo: TipoOcorrencia.lavanderia,
      categoria: categoria,
      descricao: descricao,
      relatorApto: quem.aptoId,
      relatorNome: quem.nome,
      criadaEm: e.agora,
      urgente: urgente,
    ));
  }

  // -------------------------------------------------------- Máquina ocupada

  Reserva maquinaOcupada({
    required String reservaId,
    required Morador quem,
    required String destinoMaquinaId,
  }) {
    final r = e.reserva(reservaId);
    if (r.aptoId != quem.aptoId) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva é de outro apartamento.');
    }
    reservas.exigirAptoAtivo(quem, OrigemAcao.app);
    if (r.status != StatusReserva.agendada) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Essa reserva não pode mais ser alterada.');
    }
    final agora = e.agora;
    final de = r.inicio.subtract(Duration(minutes: e.config.checkinAntesMin));
    if (agora.isBefore(de)) {
      throw AppErro('FORA_JANELA_CHECKIN',
          'Você pode confirmar o uso a partir das ${hora(de)}.');
    }
    if (agora.isAfter(r.inicio.add(Duration(minutes: e.config.toleranciaMin)))) {
      throw const AppErro('FORA_JANELA_CHECKIN',
          'O prazo para confirmar esse horário já passou.');
    }
    final origem = e.maquinaBase(r.maquinaId);
    final destino = e.maquinaBase(destinoMaquinaId);
    if (destino.id == origem.id || destino.tipo != origem.tipo) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Escolha outra máquina do mesmo tipo.');
    }
    if (e.indisponivelNoPeriodo(destino, agora, r.fim)) {
      throw AppErro('MAQUINA_INDISPONIVEL',
          'A ${destino.nome} está indisponível. Veja as outras opções.');
    }
    if (!d.livreNoSlot(destino, r.inicio, r.fim, exceto: r.id)) {
      throw AppErro('SLOT_OCUPADO',
          'A ${destino.nome} não está livre agora. Escolha outra.');
    }

    // Dedução (6.7).
    final anterior = e.reservas.values
        .where((x) =>
            x.id != r.id &&
            x.maquinaId == origem.id &&
            x.checkinEm != null &&
            x.finalizadaEm == null &&
            x.inicio.isBefore(r.inicio) &&
            agora.difference(x.checkinEm!) < const Duration(hours: 5) &&
            (x.status == StatusReserva.emUso ||
                x.status == StatusReserva.concluida))
        .sortedBy<DateTime>((x) => x.inicio)
        .lastOrNull;

    String deducao;
    String? aptoProvavel;
    var confiavel = false;
    var avisoEnviado = false;
    if (anterior != null) {
      deducao =
          'Atraso: a reserva anterior da ${origem.nome} (Ap ${anterior.aptoId}, ${hora(anterior.inicio)}) fez check-in e não finalizou o uso.';
      aptoProvavel = anterior.aptoId;
      confiavel = true;
    } else {
      final errada = e.reservas.values.firstWhereOrNull((x) =>
          x.id != r.id &&
          x.aptoId != r.aptoId &&
          x.maquinaId != origem.id &&
          x.tipo == origem.tipo &&
          x.usoImediato &&
          x.status == StatusReserva.emUso &&
          x.checkinEm != null &&
          agora.difference(x.checkinEm!) < const Duration(minutes: 20));
      if (errada != null) {
        deducao =
            'Possível check-in na máquina errada: o Ap ${errada.aptoId} confirmou uso na ${errada.maquinaNome} há ${agora.difference(errada.checkinEm!).inMinutes} min.';
        aptoProvavel = errada.aptoId;
      } else {
        deducao = 'Uso sem reserva: autor desconhecido.';
      }
    }

    final oc = Ocorrencia(
      id: e.novoId('o'),
      tipo: TipoOcorrencia.usoIndevido,
      categoria: 'Máquina ocupada (uso não registrado)',
      maquinaId: origem.id,
      maquinaNome: origem.nome,
      descricao:
          'Ap ${quem.aptoId} encontrou a ${origem.nome} ocupada no horário reservado e trocou para a ${destino.nome}.',
      relatorApto: quem.aptoId,
      relatorNome: quem.nome,
      criadaEm: agora,
      deducao: deducao,
      aptoProvavel: aptoProvavel,
      deducaoConfiavel: confiavel,
    );
    if (confiavel && anterior != null) {
      e.avisar(
        anterior.aptoId,
        'Aviso de conduta',
        'Seu ciclo na ${origem.nome} passou do seu horário e o próximo morador precisou trocar de máquina. O síndico foi informado.',
        CategoriaAviso.conduta,
        rota: '/reserva/${anterior.id}',
      );
      avisoEnviado = true;
    }
    e.ocorrencias.add(oc.copyWith(avisoCondutaEnviado: avisoEnviado));

    e.ocupadaAte[origem.id] = agora.add(Duration(minutes: origem.cicloMin));

    // Move a reserva e já faz o check-in com o ciclo padrão da máquina nova.
    final movida = r.copyWith(
      maquinaId: destino.id,
      maquinaNome: destino.nome,
      historico: [
        ...r.historico,
        e.linha(
            'Máquina ocupada: reserva movida da ${origem.nome} para a ${destino.nome}'),
      ],
    );
    reservas.aplicarCheckin(
        movida, destino.cicloMin, null, OrigemAcao.app, quem.nome,
        tolerante: true);
    return e.reserva(r.id);
  }

  // --------------------------------------------------------- Roupa esquecida

  Reserva? _donoDaRoupa(String maquinaId) {
    final ag = e.aguardando[maquinaId];
    if (ag != null) return e.reservas[ag.reservaId];
    final ult = e.ultimoUsoConfirmado(maquinaId);
    if (ult != null &&
        e.agora.difference(ult.checkinEm!) < const Duration(hours: 4)) {
      return ult;
    }
    return null;
  }

  String _textoLocal(LocalRoupa local, String? texto) {
    final t = texto?.trim();
    switch (local) {
      case LocalRoupa.balcao:
        return (t == null || t.isEmpty) ? 'Balcão da lavanderia' : t;
      case LocalRoupa.cesto:
        return (t == null || t.isEmpty) ? 'Cesto' : t;
      case LocalRoupa.secadora:
        return (t == null || t.isEmpty) ? 'Secadora' : t;
      case LocalRoupa.outro:
        return (t == null || t.isEmpty) ? 'Outro lugar' : t;
    }
  }

  String _localNaFrase(RoupaRetirada r) => switch (r.local) {
        LocalRoupa.balcao => 'no balcão da lavanderia',
        LocalRoupa.cesto => 'no cesto',
        LocalRoupa.secadora => 'na ${r.localTexto}',
        LocalRoupa.outro => 'em: ${r.localTexto}',
      };

  RoupaRetirada? roupaNaMaquina({
    required Morador quem,
    required String maquinaId,
    required bool retirei,
    LocalRoupa? local,
    String? localTexto,
    bool forcarAntecipada = false,
  }) {
    final m = e.maquinaBase(maquinaId);
    final agora = e.agora;
    final info = d.infoRoupa(maquinaId);
    final dono = _donoDaRoupa(maquinaId);
    final donoApto = info.donoApto ?? (info.temRoupa ? null : dono?.aptoId);

    if (!retirei) {
      if (donoApto != null) {
        final fim = info.fimCiclo;
        e.avisar(
          donoApto,
          'Há roupas suas na ${m.nome}',
          fim != null
              ? 'Alguém avisou que há roupas suas na ${m.nome}. Seu ciclo terminou ${relativo(fim, agora)}. Retire assim que puder.'
              : 'Alguém avisou que há roupas suas na ${m.nome}. Retire assim que puder.',
          CategoriaAviso.roupa,
        );
      } else {
        e.ocorrencias.add(Ocorrencia(
          id: e.novoId('o'),
          tipo: TipoOcorrencia.roupaEsquecida,
          categoria: 'Roupa esquecida (dono desconhecido)',
          maquinaId: m.id,
          maquinaNome: m.nome,
          relatorApto: quem.aptoId,
          relatorNome: quem.nome,
          criadaEm: agora,
        ));
      }
      return null;
    }

    if (info.maquina.situacao == SituacaoMaquina.emUso) {
      throw AppErro('NAO_PERMITIDO',
          'O ciclo da ${m.nome} ainda está em andamento. Não retire a roupa agora.');
    }

    // O próprio dono só está dando baixa na sua roupa.
    if (donoApto != null && donoApto == quem.aptoId) {
      final ag = e.aguardando[maquinaId];
      final res = ag != null ? e.reservas[ag.reservaId] : dono;
      if (res != null && res.status == StatusReserva.emUso) {
        e.salvarReserva(res.copyWith(
          status: StatusReserva.concluida,
          finalizadaEm: agora,
          historico: [...res.historico, e.linha('Roupa retirada por ${quem.nome}')],
        ));
      } else if (res != null && res.finalizadaEm == null) {
        e.salvarReserva(res.copyWith(
          finalizadaEm: agora,
          historico: [...res.historico, e.linha('Roupa retirada por ${quem.nome}')],
        ));
      }
      e.aguardando.remove(maquinaId);
      return null;
    }

    final antecipada = donoApto != null && !info.prazoPassou;
    if (antecipada && !forcarAntecipada) {
      throw AppErro('NAO_PERMITIDO',
          'O prazo do dono vai até ${hora(info.prazoRetirada!)}. Retirar antes do prazo é considerado mau uso, e o síndico será informado.');
    }

    final loc = local ?? LocalRoupa.balcao;
    final texto = _textoLocal(loc, localTexto);
    String? secId;
    if (loc == LocalRoupa.secadora) {
      final alvo = normalizarTexto(texto);
      secId = e.maquinas.values
          .firstWhereOrNull((x) =>
              x.tipo == TipoMaquina.secadora &&
              (normalizarTexto(x.nome) == alvo ||
                  normalizarTexto(x.nomeCurto) == alvo))
          ?.id;
    }

    final roupa = RoupaRetirada(
      id: e.novoId('rt'),
      maquinaId: m.id,
      maquinaNome: m.nome,
      local: loc,
      localTexto: texto,
      desde: agora,
      donoConhecido: donoApto != null,
      donoApto: donoApto,
      antecipada: antecipada,
      localMaquinaId: secId,
    );
    e.roupas.add(roupa);

    // A roupa saiu da máquina: ela fica livre.
    final res = dono;
    if (res != null && res.status == StatusReserva.emUso) {
      e.salvarReserva(res.copyWith(
        status: StatusReserva.concluida,
        historico: [
          ...res.historico,
          e.linha('Roupa retirada por outro morador e deixada: ${_localNaFrase(roupa)}'),
        ],
      ));
    }
    e.aguardando.remove(maquinaId);
    e.ocupadaAte.remove(maquinaId);

    if (donoApto != null) {
      e.avisar(
        donoApto,
        'Suas roupas foram retiradas',
        'Suas roupas foram retiradas da ${m.nome} às ${hora(agora)} e estão ${_localNaFrase(roupa)}.',
        CategoriaAviso.roupa,
      );
    }

    final secadoraAlheia = loc == LocalRoupa.secadora && donoApto != null;
    if (antecipada || secadoraAlheia) {
      e.ocorrencias.add(Ocorrencia(
        id: e.novoId('o'),
        tipo: TipoOcorrencia.roupaRetirada,
        categoria: antecipada
            ? 'Roupa retirada antes do prazo'
            : 'Roupa de outro morador colocada na secadora',
        maquinaId: m.id,
        maquinaNome: m.nome,
        descricao: 'Deixada: ${_localNaFrase(roupa)}.',
        relatorApto: quem.aptoId,
        relatorNome: quem.nome,
        criadaEm: agora,
        deducao: antecipada
            ? 'O Ap ${quem.aptoId} retirou a roupa do Ap $donoApto às ${hora(agora)}, antes do prazo (${hora(info.prazoRetirada!)}).'
            : 'O Ap ${quem.aptoId} colocou a roupa do Ap $donoApto numa secadora.',
        aptoProvavel: quem.aptoId,
        deducaoConfiavel: true,
        avisoCondutaEnviado: true,
      ));
      e.avisar(
        quem.aptoId,
        'Aviso de conduta',
        antecipada
            ? 'Você retirou a roupa da ${m.nome} antes do prazo do dono. O síndico foi informado.'
            : 'Colocar a roupa de outro morador na secadora não é permitido. O síndico foi informado.',
        CategoriaAviso.conduta,
      );
    }
    return roupa;
  }

  void minhaRoupaFoiRetirada({
    required Morador quem,
    required String maquinaId,
    required LocalRoupa ondeEncontrou,
    String? comentario,
  }) {
    final m = e.maquinaBase(maquinaId);
    final agora = e.agora;
    final minha = e.reservas.values
        .where((r) =>
            r.maquinaId == maquinaId &&
            r.aptoId == quem.aptoId &&
            r.checkinEm != null)
        .sortedBy<DateTime>((r) => r.checkinEm!)
        .lastOrNull;
    if (minha == null) {
      throw const AppErro(
          'NAO_PERMITIDO', 'Não encontramos um uso seu nessa máquina.');
    }
    final fimCiclo = minha.cronometro?.terminaEm ?? minha.fim;
    final prazo = fimCiclo.add(Duration(minutes: e.config.prazoRetiradaMin));

    // Registro da retirada, se alguém já informou.
    final registro = e.roupas
        .where((r) => r.maquinaId == maquinaId && !r.desde.isBefore(minha.checkinEm!))
        .sortedBy<DateTime>((r) => r.desde)
        .lastOrNull;
    final quando = registro?.desde ?? agora;

    if (!quando.isBefore(prazo)) {
      e.avisar(
        quem.aptoId,
        'Sua roupa foi retirada depois do prazo',
        'Pela regra do condomínio, outro morador pode retirar a roupa esquecida depois de ${hora(prazo)}.${registro != null ? ' Ela foi deixada ${_localNaFrase(registro)}.' : ' Você encontrou: ${ondeEncontrou.rotulo.toLowerCase()}.'}',
        CategoriaAviso.roupa,
      );
      return;
    }

    // Retirada antes do prazo: ocorrência de conduta (RN-28/29).
    final seguinte = e.reservas.values
        .where((r) =>
            r.id != minha.id &&
            r.maquinaId == maquinaId &&
            r.checkinEm != null &&
            r.checkinEm!.isAfter(minha.checkinEm!))
        .sortedBy<DateTime>((r) => r.checkinEm!)
        .firstOrNull;
    final provavel = registro != null ? null : seguinte?.aptoId;
    final confiavel = provavel != null;
    e.ocorrencias.add(Ocorrencia(
      id: e.novoId('o'),
      tipo: TipoOcorrencia.roupaRetirada,
      categoria: 'Roupa retirada antes do prazo (relato do dono)',
      maquinaId: m.id,
      maquinaNome: m.nome,
      descricao:
          'O Ap ${quem.aptoId} encontrou a roupa: ${ondeEncontrou.rotulo.toLowerCase()}.${comentario != null && comentario.trim().isNotEmpty ? ' Comentário: ${comentario.trim()}' : ''}',
      relatorApto: quem.aptoId,
      relatorNome: quem.nome,
      criadaEm: agora,
      deducao: confiavel
          ? 'Provável autor: Ap $provavel, que confirmou uso na ${m.nome} às ${hora(seguinte!.checkinEm!)}, antes do prazo do dono (${hora(prazo)}).'
          : 'Autor desconhecido. Prazo do dono: ${hora(prazo)}.',
      aptoProvavel: provavel,
      deducaoConfiavel: confiavel,
      avisoCondutaEnviado: confiavel,
    ));
    if (confiavel) {
      e.avisar(
        provavel,
        'Aviso de conduta',
        'A roupa de outro morador foi retirada da ${m.nome} antes do prazo. O síndico foi informado.',
        CategoriaAviso.conduta,
      );
    }
    e.avisar(
      quem.aptoId,
      'Relato registrado',
      'Registramos que sua roupa foi retirada da ${m.nome} antes do prazo. O síndico foi informado.',
      CategoriaAviso.ocorrencia,
    );
  }

  void roupaRecolhida(String roupaId, Morador quem) {
    final i = e.roupas.indexWhere((r) => r.id == roupaId);
    if (i < 0) {
      throw const AppErro('NAO_ENCONTRADO', 'Registro de roupa não encontrado.');
    }
    e.roupas[i] = e.roupas[i].copyWith(recolhidaEm: e.agora);
  }
}
