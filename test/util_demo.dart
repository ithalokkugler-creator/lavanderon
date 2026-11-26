import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/data/demo/demo_lavanderon_repository.dart';
import 'package:lavanderon/data/demo/relogio_demo.dart';
import 'package:lavanderon/domain/app_erro.dart';
import 'package:lavanderon/domain/models/models.dart';

/// Quinta-feira 26/11/2026, 18:40. Sem timers: o tempo só anda com
/// `avancarRelogio`.
final inicioTeste = DateTime(2026, 11, 26, 18, 40);

DemoLavanderonRepository novoRepo() => DemoLavanderonRepository(
      relogio: RelogioDemo(
        agoraReal: () => DateTime(2026, 1, 1),
        inicioSimulado: inicioTeste,
      ),
      autoTick: false,
    );

DateTime hoje(int h, [int m = 0]) =>
    DateTime(inicioTeste.year, inicioTeste.month, inicioTeste.day, h, m);

DateTime emDias(int dias, int h, [int m = 0]) => DateTime(
    inicioTeste.year, inicioTeste.month, inicioTeste.day + dias, h, m);

Matcher erro(String codigo) => throwsA(
    isA<AppErro>().having((e) => e.codigo, 'codigo', codigo));

extension RepoTeste on DemoLavanderonRepository {
  Future<Maquina> maq(String id) async =>
      (await maquinas().first).firstWhere((m) => m.id == id);

  Future<Reserva> res(String id) async {
    for (var d = -3; d <= 10; d++) {
      final lista = await reservasDoDia(emDias(d, 12)).first;
      for (final r in lista) {
        if (r.id == id) return r;
      }
    }
    throw StateError('Reserva $id não encontrada');
  }

  /// Morador qualquer do apartamento (a demo só guarda o primeiro nome).
  Future<Morador> moradorDe(String apto) async =>
      (await moradores().first).firstWhere((m) => m.aptoId == apto);

  /// Reserva agendada da máquina em um horário de hoje.
  Future<Reserva> reservaDe(String maquinaId, DateTime inicio) async {
    final dia = await reservasDoDia(inicio).first;
    return dia.firstWhere((r) =>
        r.maquinaId == maquinaId &&
        r.inicio == inicio &&
        r.status != StatusReserva.cancelada);
  }
}
