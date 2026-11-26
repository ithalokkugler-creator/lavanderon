import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/domain/models/models.dart';

import 'util_demo.dart';

void main() {
  group('reservar', () {
    test('mesmo horário na mesma máquina: SLOT_OCUPADO', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final carlos = await repo.entrar('410', 'Carlos');
      final r = await repo.reservar(
        quem: maria,
        inicio: emDias(1, 5),
        tipo: TipoMaquina.lavadora,
        maquinaId: 'lav2',
      );
      expect(r.status, StatusReserva.agendada);
      expect(r.aptoId, '302');
      await expectLater(
        repo.reservar(
          quem: carlos,
          inicio: emDias(1, 5),
          tipo: TipoMaquina.lavadora,
          maquinaId: 'lav2',
        ),
        erro('SLOT_OCUPADO'),
      );
      // Sem máquina específica, o app escolhe outra livre.
      final outra = await repo.reservar(
        quem: carlos,
        inicio: emDias(1, 5),
        tipo: TipoMaquina.lavadora,
      );
      expect(outra.maquinaId, isNot('lav2'));
    });

    test('limite de 2 lavagens por dia (RN-04)', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      for (final h in [3, 4]) {
        await repo.reservar(
            quem: maria, inicio: emDias(3, h), tipo: TipoMaquina.lavadora);
      }
      await expectLater(
        repo.reservar(
            quem: maria, inicio: emDias(3, 5), tipo: TipoMaquina.lavadora),
        erro('LIMITE'),
      );
      // Secadora tem limite próprio.
      final sec = await repo.reservar(
          quem: maria, inicio: emDias(3, 5), tipo: TipoMaquina.secadora);
      expect(sec.tipo, TipoMaquina.secadora);
    });

    test('lavagens já feitas hoje contam no limite', () async {
      final repo = novoRepo();
      final pedro = await repo.entrar('205', 'Pedro');
      await expectLater(
        repo.reservar(
            quem: pedro, inicio: hoje(23), tipo: TipoMaquina.lavadora),
        erro('LIMITE'),
      );
    });

    test('máximo de 6 reservas futuras ativas', () async {
      final repo = novoRepo();
      final ana = await repo.entrar('105', 'Ana'); // já tem 1 futura
      var dia = 3;
      var feitas = 1;
      while (feitas < 6) {
        for (final h in [3, 4]) {
          if (feitas >= 6) break;
          await repo.reservar(
              quem: ana, inicio: emDias(dia, h), tipo: TipoMaquina.lavadora);
          feitas++;
        }
        dia++;
      }
      await expectLater(
        repo.reservar(
            quem: ana, inicio: emDias(6, 3), tipo: TipoMaquina.secadora),
        erro('LIMITE'),
      );
    });

    test('horário passado, atual e além da antecedência', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await expectLater(
        repo.reservar(
            quem: maria, inicio: hoje(18), tipo: TipoMaquina.lavadora),
        erro('HORARIO_INVALIDO'),
      );
      await expectLater(
        repo.reservar(
            quem: maria, inicio: emDias(9, 8), tipo: TipoMaquina.lavadora),
        erro('HORARIO_INVALIDO'),
      );
    });

    test('máquina em manutenção ou bloqueada: MAQUINA_INDISPONIVEL', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await expectLater(
        repo.reservar(
          quem: maria,
          inicio: emDias(2, 9),
          tipo: TipoMaquina.secadora,
          maquinaId: 'sec5',
        ),
        erro('MAQUINA_INDISPONIVEL'),
      );
      await expectLater(
        repo.reservar(
          quem: maria,
          inicio: hoje(23),
          tipo: TipoMaquina.lavadora,
          maquinaId: 'lav5',
        ),
        erro('MAQUINA_INDISPONIVEL'),
      );
    });

    test('cancelar libera o horário e o limite', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservar(
        quem: maria,
        inicio: emDias(2, 3),
        tipo: TipoMaquina.lavadora,
        maquinaId: 'lav1',
      );
      await repo.cancelar(r.id, maria);
      expect((await repo.res(r.id)).status, StatusReserva.cancelada);
      final carlos = await repo.entrar('410', 'Carlos');
      final outra = await repo.reservar(
        quem: carlos,
        inicio: emDias(2, 3),
        tipo: TipoMaquina.lavadora,
        maquinaId: 'lav1',
      );
      expect(outra.maquinaId, 'lav1');
      // Outro apartamento não cancela reserva alheia.
      await expectLater(repo.cancelar(outra.id, maria), erro('NAO_PERMITIDO'));
    });

    test('trocar de máquina mantém o horário', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      final nova = await repo.trocarMaquina(
          reservaId: r.id, novaMaquinaId: 'lav2', quem: maria);
      expect(nova.maquinaId, 'lav2');
      expect(nova.inicio, hoje(19));
      expect((await repo.maq('lav4')).situacao, SituacaoMaquina.livre);
      await expectLater(
        repo.trocarMaquina(
            reservaId: r.id, novaMaquinaId: 'lav1', quem: maria),
        erro('SLOT_OCUPADO'),
      );
    });
  });

  group('check-in (RN-06) e não comparecimento (RN-07)', () {
    test('janela: 10 min antes até 15 min depois', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      await expectLater(
        repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 45),
        erro('FORA_JANELA_CHECKIN'),
      );
      try {
        await repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 45);
      } catch (e) {
        expect(e.toString(), contains('18:50'));
      }
      repo.avancarRelogio(const Duration(minutes: 10)); // 18:50
      await repo.confirmarUso(
          reservaId: r.id, quem: maria, duracaoMin: 45, programa: 'Normal');
      final depois = await repo.res(r.id);
      expect(depois.status, StatusReserva.emUso);
      expect(depois.checkinEm, hoje(18, 50));
      expect(depois.cronometro!.terminaEm, hoje(19, 35));
      final m = await repo.maq('lav4');
      expect(m.situacao, SituacaoMaquina.emUso);
      expect(m.aptoAtual, '302');
    });

    test('sem check-in: vira naoCompareceu aos 15 min e avisa', () async {
      final repo = novoRepo();
      final avisosNovos = <String>[];
      final sub = repo.novosAvisos().listen((a) => avisosNovos.add(a.titulo));
      repo.avancarRelogio(const Duration(minutes: 20)); // 19:00
      final antes = await repo.reservaDe('lav4', hoje(19));
      expect(antes.status, StatusReserva.agendada);
      repo.avancarRelogio(const Duration(minutes: 15)); // 19:15
      final maria = await repo.entrar('302', 'Maria');
      final r = (await repo.reservasDoApto('302').first)
          .firstWhere((x) => x.id == antes.id);
      expect(r.status, StatusReserva.naoCompareceu);
      final avisos = await repo.avisos('302').first;
      expect(avisos.any((a) => a.titulo == 'Reserva não utilizada'), isTrue);
      expect(avisos.any((a) => a.titulo == 'Sua reserva começa em 15 min'),
          isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(avisosNovos, contains('Reserva não utilizada'));
      // Agora a Lavadora 4 está livre e não dá mais para confirmar.
      expect((await repo.maq('lav4')).situacao, SituacaoMaquina.livre);
      await expectLater(
        repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 45),
        erro('NAO_PERMITIDO'),
      );
      await sub.cancel();
    });

    test('3 não comparecimentos em 30 dias avisam o síndico (RN-10)', () async {
      final repo = novoRepo();
      // A Maria tem 3 reservas futuras (hoje 19:00 e amanhã 10:00 e 11:00).
      repo.avancarRelogio(const Duration(days: 1, hours: 1)); // amanhã 19:40
      final avisos = await repo.avisos('302').first;
      final conduta = avisos.where((a) => a.titulo == 'Aviso de conduta');
      expect(conduta.length, 1);
      expect(conduta.single.corpo, contains('3 não comparecimentos'));
      final sindico = await repo.avisos('sindico').first;
      expect(sindico.any((a) => a.corpo.contains('Ap 302')), isTrue);
    });
  });

  group('cronômetro (RN-27)', () {
    test('estende para o horário seguinte quando livre', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      repo.avancarRelogio(const Duration(minutes: 10)); // 18:50
      await repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 90);
      final depois = await repo.res(r.id);
      expect(depois.cronometro!.terminaEm, hoje(20, 20));
      expect(depois.fim, hoje(21)); // estendida até as 21:00
      // A Lavadora 4 passa a estar ocupada também no horário das 20:00.
      final g = await repo.grade(inicioTeste, TipoMaquina.lavadora).first;
      expect(g[20].maquinas.firstWhere((s) => s.maquinaId == 'lav4').livre,
          isFalse);
    });

    test('horário seguinte ocupado: CRONOMETRO_EXCEDE', () async {
      final repo = novoRepo();
      final carlos = await repo.entrar('410', 'Carlos');
      // Lavadora 2 está livre às 19:00, mas reservada às 20:00.
      final r = await repo.reservar(
        quem: carlos,
        inicio: hoje(19),
        tipo: TipoMaquina.lavadora,
        maquinaId: 'lav2',
      );
      repo.avancarRelogio(const Duration(minutes: 20)); // 19:00
      await expectLater(
        repo.confirmarUso(reservaId: r.id, quem: carlos, duracaoMin: 75),
        erro('CRONOMETRO_EXCEDE'),
      );
      // Um programa que cabe no horário funciona.
      await repo.confirmarUso(reservaId: r.id, quem: carlos, duracaoMin: 45);
      expect((await repo.res(r.id)).fim, hoje(20));
    });

    test('ajustar +5 min estende ou recusa conforme o horário seguinte',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      repo.avancarRelogio(const Duration(minutes: 20)); // 19:00
      await repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 58);
      expect((await repo.res(r.id)).fim, hoje(20));
      await repo.ajustarCronometro(r.id, 5);
      final depois = await repo.res(r.id);
      expect(depois.cronometro!.terminaEm, hoje(20, 3));
      expect(depois.fim, hoje(21));
    });

    test('Usar agora: liga o cronômetro, ocupa o horário e respeita o limite',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.usarAgora(
          quem: maria, maquinaId: 'lav2', duracaoMin: 45, programa: 'Normal');
      expect(r.status, StatusReserva.emUso);
      expect(r.usoImediato, isTrue);
      expect(r.inicio, hoje(18));
      expect(r.cronometro!.terminaEm, hoje(19, 25));
      expect(r.fim, hoje(20)); // passou das 19:00, pegou o horário seguinte
      expect((await repo.maq('lav2')).situacao, SituacaoMaquina.emUso);
      // Máquina já em uso.
      final carlos = await repo.entrar('410', 'Carlos');
      await expectLater(
        repo.usarAgora(quem: carlos, maquinaId: 'lav2', duracaoMin: 30),
        erro('SLOT_OCUPADO'),
      );
      // Ap 205 já fez 2 lavagens hoje.
      final pedro = await repo.entrar('205', 'Pedro');
      await expectLater(
        repo.usarAgora(quem: pedro, maquinaId: 'lav6', duracaoMin: 30),
        erro('LIMITE'),
      );
    });

    test('roupa pronta: avisos 5 min antes, no fim e após o prazo', () async {
      final repo = novoRepo();
      final titulos = <String>[];
      final sub = repo
          .novosAvisos()
          .where((a) => a.aptoId == '205')
          .listen((a) => titulos.add(a.titulo));
      repo.avancarRelogio(const Duration(minutes: 8)); // 18:48
      await Future<void>.delayed(Duration.zero);
      expect(titulos, contains('Sua roupa fica pronta em 5 min'));
      repo.avancarRelogio(const Duration(minutes: 5)); // 18:53
      await Future<void>.delayed(Duration.zero);
      expect(titulos, contains('Sua roupa está pronta!'));
      expect((await repo.maq('lav1')).situacao,
          SituacaoMaquina.aguardandoRetirada);
      repo.avancarRelogio(const Duration(minutes: 10)); // 19:03
      await Future<void>.delayed(Duration.zero);
      expect(titulos.any((t) => t.contains('esperando')), isTrue);
      await sub.cancel();
    });

    test('fim do horário: em uso vira concluída e a roupa continua lá',
        () async {
      final repo = novoRepo();
      repo.avancarRelogio(const Duration(minutes: 30)); // 19:10
      final r = (await repo.reservasDoApto('205').first)
          .firstWhere((x) => x.maquinaId == 'lav1');
      expect(r.status, StatusReserva.concluida);
      expect(r.finalizadaEm, isNull); // ninguém finalizou
      expect((await repo.maq('lav1')).situacao,
          SituacaoMaquina.aguardandoRetirada);
      final pedro = await repo.entrar('205', 'Pedro');
      await repo.finalizar(r.id, pedro);
      expect((await repo.maq('lav1')).situacao,
          isNot(SituacaoMaquina.aguardandoRetirada));
    });
  });
}
