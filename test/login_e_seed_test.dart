import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/core/formatos.dart';
import 'package:lavanderon/core/texto.dart';
import 'package:lavanderon/domain/models/models.dart';

import 'util_demo.dart';

void main() {
  group('normalização e login', () {
    test('normalizarTexto tira acentos, caixa e espaços', () {
      expect(normalizarTexto('  JOÃO   Pedro '), 'joao pedro');
      expect(normalizarTexto('Lúcia'), 'lucia');
    });

    test('entra com acento, caixa e espaços diferentes', () async {
      final repo = novoRepo();
      expect((await repo.entrar(' 302 ', '  JOAO ')).nome, 'João');
      expect((await repo.entrar('302', 'maria')).aptoId, '302');
      expect((await repo.entrar('101', 'LUCIA')).nome, 'Lúcia');
    });

    test('apartamentos inválidos ou inexistentes', () async {
      final repo = novoRepo();
      await expectLater(repo.entrar('999', 'Maria'), erro('APTO_INEXISTENTE'));
      await expectLater(repo.entrar('121', 'Maria'), erro('APTO_INEXISTENTE'));
      await expectLater(repo.entrar('100', 'Maria'), erro('APTO_INEXISTENTE'));
      // Formato válido, mas esse número não existe no prédio.
      await expectLater(repo.entrar('119', 'Maria'), erro('APTO_INEXISTENTE'));
      await expectLater(repo.entrar('abc', 'Maria'), erro('APTO_INEXISTENTE'));
    });

    test('nome errado e bloqueio após 10 tentativas (RN-20)', () async {
      final repo = novoRepo();
      await expectLater(repo.entrar('302', 'Zeca'), erro('LOGIN_INVALIDO'));
      for (var i = 0; i < 9; i++) {
        await expectLater(repo.entrar('302', 'x$i'), erro('LOGIN_INVALIDO'));
      }
      await expectLater(repo.entrar('302', 'Maria'), erro('MUITAS_TENTATIVAS'));
      repo.avancarRelogio(const Duration(minutes: 16));
      expect((await repo.entrar('302', 'Maria')).nome, 'Maria');
    });

    test('apartamento suspenso entra, mas não reserva (RN-19)', () async {
      final repo = novoRepo();
      final rafael = await repo.entrar('508', 'Rafael');
      await expectLater(
        repo.reservar(
            quem: rafael, inicio: emDias(3, 4), tipo: TipoMaquina.lavadora),
        erro('APTO_SUSPENSO'),
      );
    });
  });

  group('seed Vision às 18:40', () {
    test('apartamentos e moradores', () async {
      final repo = novoRepo();
      final aptos = await repo.apartamentos().first;
      expect(aptos.length, 120);
      expect(aptos.where((a) => a.existe).length, 108);
      expect(aptos.where((a) => a.existe && !a.ativo).length, 6);
      expect(aptos.firstWhere((a) => a.id == '508').ativo, isFalse);
      expect(aptos.firstWhere((a) => a.id == '302').moradoresNomes,
          ['Maria', 'João']);
      expect(aptos.firstWhere((a) => a.id == '119').existe, isFalse);
    });

    test('situação das máquinas', () async {
      final repo = novoRepo();
      final ms = await repo.maquinas().first;
      expect(ms.length, 12);
      Maquina m(String id) => ms.firstWhere((x) => x.id == id);

      expect(m('lav1').situacao, SituacaoMaquina.emUso);
      expect(m('lav1').aptoAtual, '205');
      expect(m('lav1').previsaoFim, hoje(18, 52));
      expect(m('lav2').situacao, SituacaoMaquina.livre);
      expect(m('lav2').livreAte, hoje(20));
      expect(m('lav3').situacao, SituacaoMaquina.aguardandoRetirada);
      expect(m('lav3').aptoAtual, '410');
      expect(m('lav4').situacao, SituacaoMaquina.reservada);
      expect(m('lav4').proximaReservaApto, '302');
      expect(m('lav4').livreAte, hoje(19));
      expect(m('lav5').status, StatusMaquina.bloqueadaHoje);
      expect(m('lav5').motivoIndisponivel, 'Não centrifuga');
      expect(m('lav6').situacao, SituacaoMaquina.livre);
      expect(m('sec1').situacao, SituacaoMaquina.livre);
      expect(m('sec2').situacao, SituacaoMaquina.emUso);
      expect(m('sec2').previsaoFim, hoje(19, 14));
      expect(m('sec3').situacao, SituacaoMaquina.livre);
      expect(m('sec4').situacao, SituacaoMaquina.emUso);
      expect(m('sec4').aptoAtual, '612');
      expect(m('sec4').previsaoFim, hoje(18, 45));
      expect(m('sec5').status, StatusMaquina.manutencao);
      expect(m('sec5').motivoIndisponivel, 'Troca da correia');
      expect(m('sec6').situacao, SituacaoMaquina.reservada);
      expect(m('sec6').proximaReservaApto, '105');
    });

    test('grade tem 24 horários e noite quase cheia', () async {
      final repo = novoRepo();
      final g = await repo.grade(inicioTeste, TipoMaquina.lavadora).first;
      expect(g.length, 24);
      expect(g[18].passado, isFalse);
      expect(g[17].passado, isTrue);
      expect(g[19].total, 6);
      expect(g[19].livres, 2); // Lav 2 e Lav 6
      expect(g[20].livres, 1); // só a Lav 4 (Lav 5 está bloqueada)
      final sec = await repo.grade(inicioTeste, TipoMaquina.secadora).first;
      expect(sec[19].livres, 2); // Sec 1 e Sec 3
      expect(sec[3].maquinas.firstWhere((s) => s.maquinaId == 'sec5').livre,
          isFalse);
    });

    test('conteúdo inicial', () async {
      final repo = novoRepo();
      final noticias = await repo.noticias().first;
      expect(noticias.length, 4);
      expect(noticias.first.prioridade, PrioridadeNoticia.urgente);
      expect(noticias.first.fixada, isTrue);
      final tuts = await repo.tutoriais();
      expect(tuts.length, 10);
      expect(tuts.every((t) => t.passos.length >= 3 && t.passos.length <= 6),
          isTrue);
      expect((await repo.sugestoes().first).length, 5);
      final avisos = await repo.avisos('302').first;
      expect(avisos.length, 6);
      expect(avisos.where((a) => !a.lido).length, 3);
      final roupas = await repo.roupasRetiradas().first;
      expect(roupas.length, 1);
      expect(roupas.single.maquinaNome, 'Lavadora 6');
      expect(roupas.single.donoApto, '205');
      final ocs = await repo.ocorrencias().first;
      expect(ocs.length, greaterThanOrEqualTo(4));
      final minhas = await repo.reservasDoApto('302').first;
      expect(minhas.length, greaterThanOrEqualTo(10));
    });

    test('estatísticas', () async {
      final repo = novoRepo();
      final s = await repo.estatisticas();
      expect(s.reservas30d.length, 30);
      expect(s.mapaCalor.length, 7);
      expect(s.mapaCalor.first.length, 24);
      expect(s.usoPorMaquina30d.length, 12);
      expect(s.taxaComparecimento30d, inInclusiveRange(0.8, 1.0));
      expect(s.topAptos, isNotEmpty);
    });

    test('restaurar volta ao seed', () async {
      final repo = novoRepo();
      repo.avancarRelogio(const Duration(hours: 3));
      expect(repo.agoraAtual, hoje(21, 40));
      repo.restaurar();
      expect(repo.agoraAtual, hoje(18, 40));
      expect((await repo.maq('lav1')).situacao, SituacaoMaquina.emUso);
    });
  });

  group('formatos', () {
    test('hora, data, relativo e duração', () {
      expect(hora(DateTime(2026, 11, 26, 8, 5)), '08:05');
      expect(dataCurta(inicioTeste), 'qui, 26/11');
      expect(relativo(hoje(18, 34), inicioTeste), 'há 6 min');
      expect(relativo(hoje(18, 52), inicioTeste), 'em 12 min');
      expect(relativo(inicioTeste, inicioTeste), 'agora');
      expect(duracao(const Duration(minutes: 32, seconds: 15)), '32:15');
    });

    test('Reserva.podeConfirmar segue a janela de check-in', () async {
      final repo = novoRepo();
      final r = await repo.reservaDe('lav4', hoje(19));
      expect(r.podeConfirmar(hoje(18, 49)), isFalse);
      expect(r.podeConfirmar(hoje(18, 50)), isTrue);
      expect(r.podeConfirmar(hoje(19, 15)), isTrue);
      expect(r.podeConfirmar(hoje(19, 16)), isFalse);
      expect(r.podeCancelar(hoje(18, 40)), isTrue);
    });
  });
}
