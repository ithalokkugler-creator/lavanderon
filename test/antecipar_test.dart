import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/domain/models/models.dart';

import 'util_demo.dart';

void main() {
  group('check-in antecipado (RN-06)', () {
    test('Maria às 18:40: começa antes do horário das 19:00', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      expect((await repo.maq('lav4')).situacao, SituacaoMaquina.reservada);
      expect(await repo.maquinaParaAntecipar(r.id), 'lav4');

      await repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 45);
      final depois = await repo.res(r.id);
      expect(depois.status, StatusReserva.emUso);
      expect(depois.maquinaId, 'lav4');
      expect(depois.inicio, hoje(18));
      expect(depois.fim, hoje(20)); // 18:00 + 19:00 (RN-05: 2 slots)
      expect(depois.checkinEm, hoje(18, 40));
      expect(depois.cronometro!.terminaEm, hoje(19, 25));
      expect(depois.historico.any((l) => l.contains(
          'Uso confirmado antes do horário (reserva era 19:00 na Lavadora 4)')),
          isTrue);
      final m = await repo.maq('lav4');
      expect(m.situacao, SituacaoMaquina.emUso);
      expect(m.aptoAtual, '302');
      expect(m.previsaoFim, hoje(19, 25));
      // Sem reserva duplicada: continua 1 reserva da Maria nessa máquina às 18/19.
      final dia = await repo.reservasDoDia(inicioTeste).first;
      expect(
          dia.where((x) => x.aptoId == '302' && x.maquinaId == 'lav4').length,
          1);
    });

    test('programa curto libera o horário original das 19:00', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      await repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 15);
      final depois = await repo.res(r.id);
      expect(depois.inicio, hoje(18));
      expect(depois.fim, hoje(19));
      final g = await repo.grade(inicioTeste, TipoMaquina.lavadora).first;
      expect(g[19].maquinas.firstWhere((s) => s.maquinaId == 'lav4').livre,
          isTrue);
      expect(g[18].maquinas.firstWhere((s) => s.maquinaId == 'lav4').livre,
          isFalse);
    });

    test('máquina própria ocupada: sugere outra livre e move a reserva',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final ana = await repo.moradorDe('101');
      final r = await repo.reservaDe('lav4', hoje(19));
      await repo.usarAgora(
          quem: ana, maquinaId: 'lav4', duracaoMin: 15); // ocupa a Lav 4
      final outra = await repo.maquinaParaAntecipar(r.id);
      expect(outra, isNotNull);
      expect(outra, isNot('lav4'));
      expect(['lav2', 'lav6'], contains(outra));

      await repo.confirmarUso(
          reservaId: r.id, quem: maria, duracaoMin: 15, maquinaId: outra);
      final depois = await repo.res(r.id);
      expect(depois.maquinaId, outra);
      expect(depois.status, StatusReserva.emUso);
      expect(depois.inicio, hoje(18));
      expect((await repo.maq(outra!)).situacao, SituacaoMaquina.emUso);
      // O horário das 19:00 da Lav 4 voltou para a grade.
      final g = await repo.grade(inicioTeste, TipoMaquina.lavadora).first;
      expect(g[19].maquinas.firstWhere((s) => s.maquinaId == 'lav4').livre,
          isTrue);
    });

    test('nenhuma lavadora livre: retorna null e confirmarUso falha',
        () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final r = await repo.reservaDe('lav4', hoje(19));
      final ana = await repo.moradorDe('101');
      final bia = await repo.moradorDe('105');
      final gil = await repo.moradorDe('201');
      await repo.usarAgora(quem: ana, maquinaId: 'lav4', duracaoMin: 15);
      await repo.usarAgora(quem: bia, maquinaId: 'lav2', duracaoMin: 15);
      await repo.usarAgora(quem: gil, maquinaId: 'lav6', duracaoMin: 15);
      // lav1 em uso, lav3 aguardando retirada, lav5 bloqueada.
      expect(await repo.maquinaParaAntecipar(r.id), isNull);
      await expectLater(
        repo.confirmarUso(reservaId: r.id, quem: maria, duracaoMin: 45),
        erro('MAQUINA_INDISPONIVEL'),
      );
      expect((await repo.res(r.id)).status, StatusReserva.agendada);
    });

    test('horário seguinte de outro apartamento: CRONOMETRO_EXCEDE', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final carlos = await repo.entrar('410', 'Carlos');
      final r = await repo.reservaDe('lav4', hoje(19));
      await repo.reservar(
        quem: carlos,
        inicio: hoje(19),
        tipo: TipoMaquina.lavadora,
        maquinaId: 'lav2',
      );
      await expectLater(
        repo.confirmarUso(
            reservaId: r.id, quem: maria, duracaoMin: 45, maquinaId: 'lav2'),
        erro('CRONOMETRO_EXCEDE'),
      );
      // Nada mudou na reserva.
      final igual = await repo.res(r.id);
      expect(igual.status, StatusReserva.agendada);
      expect(igual.maquinaId, 'lav4');
      expect(igual.inicio, hoje(19));
    });
  });
}
