import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/domain/models/models.dart';

import 'util_demo.dart';

void main() {
  group('combo Lavar + Secar (RN-24)', () {
    test('sucesso: duas reservas, mesmo comboId, slots H e H+1', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final (lav, sec) = await repo.reservarCombo(
          quem: maria, inicioLavagem: emDias(3, 10, 20));
      expect(lav.tipo, TipoMaquina.lavadora);
      expect(sec.tipo, TipoMaquina.secadora);
      expect(lav.inicio, emDias(3, 10));
      expect(sec.inicio, emDias(3, 11));
      expect(lav.comboId, isNotNull);
      expect(sec.comboId, lav.comboId);
      expect(lav.historico.last, contains('Combo lavar + secar'));
      final salvas = await repo.res(lav.id);
      expect(salvas.comboId, lav.comboId);
    });

    test('sem secadora livre em H+1: nada é salvo', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      // Ocupa todas as secadoras do slot 11h (cada apto, no máx. 2 por dia).
      final aptos = ['410', '205', '612', '101', '508', '105'];
      var i = 0;
      for (final m in (await repo.maquinas().first)
          .where((m) => m.tipo == TipoMaquina.secadora)) {
        final quem = await repo.moradorDe(aptos[i++]);
        try {
          await repo.reservar(
              quem: quem,
              inicio: emDias(4, 11),
              tipo: TipoMaquina.secadora,
              maquinaId: m.id);
        } catch (_) {}
      }
      expect(await repo.secadorasLivresApos(emDias(4, 10)), 0);
      final antes = (await repo.reservasDoApto('302').first).length;
      await expectLater(
        repo.reservarCombo(quem: maria, inicioLavagem: emDias(4, 10)),
        erro('SLOT_OCUPADO'),
      );
      expect((await repo.reservasDoApto('302').first).length, antes);
    });

    test('limite diário de secagens: nada é salvo', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final lim = (await repo.config().first).limiteDia(TipoMaquina.secadora);
      for (var i = 0; i < lim; i++) {
        await repo.reservar(
            quem: maria, inicio: emDias(5, 3 + i), tipo: TipoMaquina.secadora);
      }
      final antes = (await repo.reservasDoApto('302').first).length;
      await expectLater(
        repo.reservarCombo(quem: maria, inicioLavagem: emDias(5, 12)),
        erro('LIMITE'),
      );
      final depois = await repo.reservasDoApto('302').first;
      expect(depois.length, antes);
      expect(
          depois.any((r) =>
              r.tipo == TipoMaquina.lavadora && r.inicio == emDias(5, 12)),
          isFalse);
    });

    test('ids nulos: escolhe as menos usadas', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final iniLav = emDias(3, 9);
      final lavEsperada = (await repo.alternativas(
              tipo: TipoMaquina.lavadora, inicio: iniLav))
          .first
          .id;
      final secEsperada = (await repo.alternativas(
              tipo: TipoMaquina.secadora, inicio: emDias(3, 10)))
          .first
          .id;
      final (lav, sec) =
          await repo.reservarCombo(quem: maria, inicioLavagem: iniLav);
      expect(lav.maquinaId, lavEsperada);
      expect(sec.maquinaId, secEsperada);
    });

    test('cancelar uma metade mantém a outra', () async {
      final repo = novoRepo();
      final maria = await repo.entrar('302', 'Maria');
      final (lav, sec) =
          await repo.reservarCombo(quem: maria, inicioLavagem: emDias(3, 9));
      await repo.cancelar(lav.id, maria);
      expect((await repo.res(lav.id)).status, StatusReserva.cancelada);
      final s = await repo.res(sec.id);
      expect(s.status, StatusReserva.agendada);
      expect(s.comboId, sec.comboId);
    });

    test('seed tem um combo de exemplo', () async {
      final repo = novoRepo();
      var achou = 0;
      for (var d = 0; d <= 7; d++) {
        achou += (await repo.reservasDoDia(emDias(d, 12)).first)
            .where((r) => r.comboId != null)
            .length;
      }
      expect(achou, 2);
    });
  });
}
