import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderon/data/demo/demo_lavanderon_repository.dart';
import 'package:lavanderon/data/demo/relogio_demo.dart';
import 'package:lavanderon/domain/models/models.dart';

void main() {
  test('relógio simulado começa hoje às 18:40 e anda em tempo real', () async {
    final repo = DemoLavanderonRepository();
    final t0 = repo.agoraAtual;
    final agora = DateTime.now();
    expect(t0.year, agora.year);
    expect(t0.month, agora.month);
    expect(t0.day, agora.day);
    expect(t0.hour, 18);
    expect(t0.minute, anyOf(40, 41));

    final horas = <DateTime>[];
    final sub = repo.agora().listen(horas.add);
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    await sub.cancel();
    expect(horas.length, greaterThanOrEqualTo(3)); // valor inicial + 2 pulsos
    expect(horas.last.isAfter(horas.first), isTrue);
    repo.dispose();
  });

  test('stream de máquinas emite o valor atual e as mudanças', () async {
    final repo = DemoLavanderonRepository(
      relogio: RelogioDemo(
        agoraReal: () => DateTime(2026, 1, 1),
        inicioSimulado: DateTime(2026, 11, 26, 18, 40),
      ),
      autoTick: false,
    );
    final emissoes = <List<Maquina>>[];
    final sub = repo.maquinas().listen(emissoes.add);
    await Future<void>.delayed(Duration.zero);
    expect(emissoes.length, 1);
    // Segundo ouvinte também recebe o valor atual na hora.
    expect((await repo.maquinas().first).length, 12);
    await repo.bloquearMaquina('lav6', 'Teste');
    await Future<void>.delayed(Duration.zero);
    expect(emissoes.length, 2);
    expect(emissoes.last.firstWhere((m) => m.id == 'lav6').status,
        StatusMaquina.bloqueadaHoje);
    await sub.cancel();
    repo.dispose();
  });
}
