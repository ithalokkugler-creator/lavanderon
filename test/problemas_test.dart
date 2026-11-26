import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/domain/models/models.dart';

import 'util_demo.dart';

void main() {
  group('problema em máquina (RN-12/13)', () {
    test('reserva afetada é realocada para máquina equivalente livre',
        () async {
      final repo = novoRepo();
      final ana = await repo.entrar('105', 'Ana');
      final r = await repo.reservaDe('sec6', hoje(19));
      await repo.relatarProblemaMaquina(
        quem: ana,
        maquinaId: 'sec6',
        categoria: 'Não esquenta',
        impedeUso: true,
      );
      final m = await repo.maq('sec6');
      expect(m.status, StatusMaquina.bloqueadaHoje);
      expect(m.indisponivelAte, hoje(23, 59));
      final depois = await repo.res(r.id);
      expect(depois.status, StatusReserva.agendada);
      expect(depois.maquinaId, anyOf('sec1', 'sec3'));
      final avisos = await repo.avisos('105').first;
      expect(avisos.any((a) => a.corpo.contains('Movemos sua reserva')), isTrue);
      final ocs = await repo.ocorrencias().first;
      expect(ocs.first.categoria, 'Não esquenta');
      expect(ocs.first.bloqueouMaquina, isTrue);
    });

    test('sem alternativa: precisa de ação e cancela sem penalidade',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      // Tira as lavadoras livres das 19:00 (Lav 2 e Lav 6).
      await repo.bloquearMaquina('lav2', 'Teste');
      await repo.bloquearMaquina('lav6', 'Teste');
      final r = await repo.reservaDe('lav4', hoje(19));
      await repo.relatarProblemaMaquina(
        quem: maria,
        maquinaId: 'lav4',
        categoria: 'Vazando água',
        impedeUso: true,
      );
      final precisa = await repo.res(r.id);
      expect(precisa.status, StatusReserva.precisaAcao);
      expect(precisa.mensagemAcao, contains('Lavadora 4'));
      final avisos = await repo.avisos('302').first;
      expect(avisos.any((a) => a.titulo == 'Sua reserva precisa de ação'),
          isTrue);
      // Sem ação até o início: cancelada, sem penalidade.
      repo.avancarRelogio(const Duration(minutes: 20)); // 19:00
      final fim = await repo.res(r.id);
      expect(fim.status, StatusReserva.cancelada);
      expect(fim.motivoCancelamento, contains('sem penalidade'));
    });

    test('precisa de ação: trocar de máquina resolve', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await repo.bloquearMaquina('lav2', 'Teste');
      await repo.bloquearMaquina('lav6', 'Teste');
      final r = await repo.reservaDe('lav4', hoje(19));
      await repo.relatarProblemaMaquina(
          quem: maria,
          maquinaId: 'lav4',
          categoria: 'Barulho estranho',
          impedeUso: true);
      await repo.liberarMaquina('lav2');
      final nova = await repo.trocarMaquina(
          reservaId: r.id, novaMaquinaId: 'lav2', quem: maria);
      expect(nova.status, StatusReserva.agendada);
      expect(nova.mensagemAcao, isNull);
    });

    test('relato que não impede o uso só mostra alerta', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await repo.relatarProblemaMaquina(
        quem: maria,
        maquinaId: 'lav6',
        categoria: 'Barulho estranho',
        impedeUso: false,
      );
      final m = await repo.maq('lav6');
      expect(m.status, StatusMaquina.disponivel);
      expect(m.alerta, 'Barulho estranho');
    });

    test('relato duplicado soma confirmações', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final antes = (await repo.ocorrencias().first).length;
      await repo.relatarProblemaMaquina(
        quem: maria,
        maquinaId: 'lav5',
        categoria: 'Não centrifuga',
        impedeUso: true,
      );
      final ocs = await repo.ocorrencias().first;
      expect(ocs.length, antes);
      expect(ocs.firstWhere((o) => o.maquinaId == 'lav5').confirmacoes, 3);
    });

    test('relato à noite bloqueia até 08:00 do dia seguinte', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      repo.avancarRelogio(const Duration(minutes: 90)); // 20:10
      await repo.relatarProblemaMaquina(
        quem: maria,
        maquinaId: 'lav6',
        categoria: 'Não liga',
        impedeUso: true,
      );
      expect((await repo.maq('lav6')).indisponivelAte, emDias(1, 8));
      repo.avancarRelogio(const Duration(hours: 12)); // 08:10
      expect((await repo.maq('lav6')).status, StatusMaquina.disponivel);
    });

    test('bloqueio do dia termina às 23:59 e a máquina volta sozinha',
        () async {
      final repo = novoRepo();
      expect((await repo.maq('lav5')).status, StatusMaquina.bloqueadaHoje);
      repo.avancarRelogio(const Duration(hours: 5, minutes: 30)); // 00:10
      expect((await repo.maq('lav5')).status, StatusMaquina.disponivel);
    });

    test('manutenção também realoca e a máquina só volta manualmente',
        () async {
      final repo = novoRepo();
      await repo.colocarManutencao('sec3', 'Troca de rolamento', null);
      repo.avancarRelogio(const Duration(days: 2));
      expect((await repo.maq('sec3')).status, StatusMaquina.manutencao);
      await repo.voltarCirculacao('sec3');
      expect((await repo.maq('sec3')).status, StatusMaquina.disponivel);
    });
  });

  group('máquina ocupada (6.7)', () {
    test('troca na hora, marca a máquina e avisa o apto anterior', () async {
      final repo = novoRepo();
      // Quem reservou a Lavadora 3 às 19:00; a Lav 3 ainda tem a roupa do 410.
      final r = await repo.reservaDe('lav3', hoje(19));
      final quem = await repo.moradorDe(r.aptoId);
      repo.avancarRelogio(const Duration(minutes: 20)); // 19:00
      final nova = await repo.maquinaOcupada(
        reservaId: r.id,
        quem: quem,
        destinoMaquinaId: 'lav2',
      );
      expect(nova.maquinaId, 'lav2');
      expect(nova.status, StatusReserva.emUso);
      expect(nova.cronometro, isNotNull);
      final original = await repo.maq('lav3');
      expect(original.situacao, isNot(SituacaoMaquina.livre));
      final ocs = await repo.ocorrencias().first;
      final oc = ocs.firstWhere((o) => o.tipo == TipoOcorrencia.usoIndevido &&
          o.maquinaId == 'lav3' &&
          o.criadaEm == hoje(19));
      expect(oc.deducaoConfiavel, isTrue);
      expect(oc.aptoProvavel, '410');
      expect(oc.avisoCondutaEnviado, isTrue);
      final avisos = await repo.avisos('410').first;
      expect(avisos.any((a) => a.corpo.endsWith('O síndico foi informado.')),
          isTrue);
    });

    test('máquina original fica "ocupada (uso não registrado)" até agora+ciclo',
        () async {
      final repo = novoRepo();
      // Lavadora 4 (Maria) só tem a reserva dela; ninguém usou antes.
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      repo.avancarRelogio(const Duration(minutes: 20)); // 19:00
      await repo.maquinaOcupada(
          reservaId: r.id, quem: maria, destinoMaquinaId: 'lav2');
      final m = await repo.maq('lav4');
      expect(m.situacao, SituacaoMaquina.ocupadaSemRegistro);
      expect(m.previsaoFim, hoje(19, 45));
      final oc = (await repo.ocorrencias().first)
          .firstWhere((o) => o.maquinaId == 'lav4' && o.criadaEm == hoje(19));
      expect(oc.deducaoConfiavel, isFalse);
      expect(oc.avisoCondutaEnviado, isFalse);
      repo.avancarRelogio(const Duration(minutes: 50)); // 19:50
      expect((await repo.maq('lav4')).situacao,
          isNot(SituacaoMaquina.ocupadaSemRegistro));
    });
  });

  group('roupa na máquina (RN-15/28)', () {
    test('antes do prazo exige confirmação e vira ocorrência de conduta',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final info = await repo.infoRoupaMaquina('lav3');
      expect(info.donoApto, '410');
      expect(info.fimCiclo, hoje(18, 34));
      expect(info.prazoRetirada, hoje(18, 44));
      expect(info.prazoPassou, isFalse);
      expect(info.temRoupa, isTrue);

      await expectLater(
        repo.roupaNaMaquina(quem: maria, maquinaId: 'lav3', retirei: true),
        erro('NAO_PERMITIDO'),
      );
      final roupa = await repo.roupaNaMaquina(
        quem: maria,
        maquinaId: 'lav3',
        retirei: true,
        local: LocalRoupa.balcao,
        forcarAntecipada: true,
      );
      expect(roupa!.antecipada, isTrue);
      expect(roupa.donoApto, '410');
      expect((await repo.maq('lav3')).situacao, isNot(SituacaoMaquina.aguardandoRetirada));
      final ocs = await repo.ocorrencias().first;
      expect(
          ocs.any((o) =>
              o.tipo == TipoOcorrencia.roupaRetirada &&
              o.relatorApto == '302' &&
              o.avisoCondutaEnviado),
          isTrue);
      final deMaria = await repo.avisos('302').first;
      expect(deMaria.any((a) => a.corpo.contains('O síndico foi informado.')),
          isTrue);
      final deCarlos = await repo.avisos('410').first;
      expect(deCarlos.any((a) => a.corpo.contains('foram retiradas da Lavadora 3')),
          isTrue);
    });

    test('depois do prazo é retirada normal, sem ocorrência', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      repo.avancarRelogio(const Duration(minutes: 10)); // 18:50
      final antes = (await repo.ocorrencias().first).length;
      final info = await repo.infoRoupaMaquina('lav3');
      expect(info.prazoPassou, isTrue);
      final roupa = await repo.roupaNaMaquina(
        quem: maria,
        maquinaId: 'lav3',
        retirei: true,
        local: LocalRoupa.cesto,
      );
      expect(roupa!.antecipada, isFalse);
      expect(roupa.local, LocalRoupa.cesto);
      expect((await repo.ocorrencias().first).length, antes);
      expect((await repo.maq('lav3')).situacao, isNot(SituacaoMaquina.aguardandoRetirada));
      final lista = await repo.roupasRetiradas().first;
      expect(lista.any((r) => r.id == roupa.id), isTrue);
      await repo.roupaRecolhida(roupa.id, maria);
      expect((await repo.roupasRetiradas().first).any((r) => r.id == roupa.id),
          isFalse);
    });

    test('só avisar o dono manda o aviso e não retira nada', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.roupaNaMaquina(
          quem: maria, maquinaId: 'lav3', retirei: false);
      expect(r, isNull);
      expect((await repo.maq('lav3')).situacao,
          SituacaoMaquina.aguardandoRetirada);
      final avisos = await repo.avisos('410').first;
      expect(avisos.any((a) => a.titulo.contains('Há roupas suas')), isTrue);
    });

    test('dono relata retirada antes do prazo: ocorrência de conduta',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final carlos = await repo.entrar('410', 'Carlos');
      await repo.roupaNaMaquina(
        quem: maria,
        maquinaId: 'lav3',
        retirei: true,
        forcarAntecipada: true,
      );
      final antes = (await repo.ocorrencias().first).length;
      await repo.minhaRoupaFoiRetirada(
        quem: carlos,
        maquinaId: 'lav3',
        ondeEncontrou: LocalRoupa.balcao,
        comentario: 'Estava molhada',
      );
      final ocs = await repo.ocorrencias().first;
      expect(ocs.length, antes + 1);
      expect(ocs.first.tipo, TipoOcorrencia.roupaRetirada);
    });
  });

  group('lavanderia, sugestões e comunicados', () {
    test('problema na lavanderia vira ocorrência', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await repo.relatarProblemaLavanderia(
          quem: maria, categoria: 'Piso molhado', urgente: true);
      final mine = await repo.ocorrencias(relatorApto: '302').first;
      expect(mine.single.urgente, isTrue);
      expect(mine.single.tipo, TipoOcorrencia.lavanderia);
    });

    test('votar é um toggle', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final antes = (await repo.sugestoes().first).firstWhere((s) => s.id == 's5');
      await repo.votarSugestao('s5', maria);
      var s = (await repo.sugestoes().first).firstWhere((s) => s.id == 's5');
      expect(s.votos, antes.votos + 1);
      expect(s.votadaPorMim, isTrue);
      await repo.votarSugestao('s5', maria);
      s = (await repo.sugestoes().first).firstWhere((s) => s.id == 's5');
      expect(s.votos, antes.votos);
      expect(s.votadaPorMim, isFalse);
    });

    test('avisos e notícias lidas', () async {
      final repo = novoRepo();
      final avisos = await repo.avisos('302').first;
      final naoLido = avisos.firstWhere((a) => !a.lido);
      await repo.marcarAvisoLido(naoLido.id);
      expect((await repo.avisos('302').first).where((a) => !a.lido).length, 2);
      await repo.marcarNoticiaLida('n1');
      final n = (await repo.noticias().first).firstWhere((n) => n.id == 'n1');
      expect(n.lida, isTrue);
    });

    test('publicar comunicado urgente aparece fixado e avisa os apartamentos',
        () async {
      final repo = novoRepo();
      await repo.publicarNoticia(
        titulo: 'Água cortada',
        corpo: 'Amanhã não haverá água das 10h às 14h.',
        prioridade: PrioridadeNoticia.urgente,
      );
      final lista = await repo.noticias().first;
      expect(lista.length, 5);
      expect(lista.any((n) => n.titulo == 'Água cortada'), isTrue);
      expect((await repo.avisos('302').first).first.titulo, 'Água cortada');
    });
  });
}
