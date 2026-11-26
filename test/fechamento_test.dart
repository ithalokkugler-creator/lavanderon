import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/domain/models/models.dart';

import 'util_demo.dart';

void main() {
  group('fechamento da lavanderia (RN-16)', () {
    test('impacto confere com o total cancelado e mantém quem está em uso',
        () async {
      final repo = novoRepo();
      final previsto = await repo.impactoFechamento(null);
      expect(previsto, greaterThan(20));
      final cancelou =
          await repo.fecharLavanderia('Dedetização das áreas comuns');
      expect(cancelou, previsto);

      final f = await repo.fechamentoAtivo().first;
      expect(f, isNotNull);
      expect(f!.motivo, 'Dedetização das áreas comuns');

      // Reservas em uso continuam; as demais foram canceladas.
      final dia = await repo.reservasDoDia(inicioTeste).first;
      expect(dia.where((r) => r.status == StatusReserva.emUso).length, 4);
      expect(
          dia.where((r) =>
              r.status == StatusReserva.cancelada &&
              r.motivoCancelamento!.contains('Dedetização')),
          isNotEmpty);
      expect(
          dia.where((r) => r.status == StatusReserva.agendada).length, 0);

      // Aviso para quem teve a reserva cancelada.
      final avisos = await repo.avisos('302').first;
      expect(avisos.first.titulo, contains('cancelada'));
    });

    test('fechada: não reserva e a grade marca fechado', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await repo.fecharLavanderia('Obras', ate: emDias(1, 12));
      await expectLater(
        repo.reservar(
            quem: maria, inicio: emDias(1, 5), tipo: TipoMaquina.lavadora),
        erro('FECHADA'),
      );
      final g = await repo.grade(emDias(1, 0), TipoMaquina.lavadora).first;
      expect(g[5].fechado, isTrue);
      expect(g[5].livres, 0);
      expect(g[13].fechado, isFalse);
      // Depois do horário previsto, o fechamento expira sozinho.
      repo.avancarRelogio(const Duration(days: 1));
      expect(await repo.fechamentoAtivo().first, isNull);
      final ok = await repo.reservar(
          quem: maria, inicio: emDias(2, 5), tipo: TipoMaquina.lavadora);
      expect(ok.status, StatusReserva.agendada);
    });

    test('impacto de fechamento com data final conta só o período', () async {
      final repo = novoRepo();
      final ateAmanha = await repo.impactoFechamento(emDias(1, 0));
      final tudo = await repo.impactoFechamento(null);
      expect(ateAmanha, lessThan(tudo));
      expect(ateAmanha, greaterThan(0));
    });

    test('reabrir a lavanderia', () async {
      final repo = novoRepo();
      await repo.fecharLavanderia('Teste');
      expect(await repo.fechamentoAtivo().first, isNotNull);
      await repo.reabrirLavanderia();
      expect(await repo.fechamentoAtivo().first, isNull);
    });

    test('cancelamento pelo síndico', () async {
      final repo = novoRepo();
      final r = await repo.reservaDe('sec6', hoje(19));
      await repo.cancelarReservaAdmin(r.id, 'Manutenção preventiva');
      final depois = await repo.res(r.id);
      expect(depois.status, StatusReserva.cancelada);
      expect(depois.motivoCancelamento, 'Manutenção preventiva');
    });

    test('suspender e reativar apartamento', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      await repo.definirAptoAtivo('302', false);
      await expectLater(
        repo.reservar(
            quem: maria, inicio: emDias(4, 3), tipo: TipoMaquina.lavadora),
        erro('APTO_SUSPENSO'),
      );
      await repo.definirAptoAtivo('302', true);
      final r = await repo.reservar(
          quem: maria, inicio: emDias(4, 3), tipo: TipoMaquina.lavadora);
      expect(r.status, StatusReserva.agendada);
    });
  });
}
