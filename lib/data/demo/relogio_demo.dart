/// Relógio simulado da demo.
///
/// Começa HOJE às 18:40 (hora local) e anda em tempo real (1 s = 1 s), mais o
/// deslocamento somado por [avancar]. Todas as regras de negócio usam este
/// relógio, nunca `DateTime.now()` diretamente (RN-21).
class RelogioDemo {
  RelogioDemo({DateTime Function()? agoraReal, DateTime? inicioSimulado})
      : _agoraReal = agoraReal ?? DateTime.now {
    final real = _agoraReal();
    inicio = inicioSimulado ??
        DateTime(real.year, real.month, real.day, 18, 40);
    _realNoInicio = real;
  }

  final DateTime Function() _agoraReal;

  /// Instante simulado em que a demo começa (dia de hoje, 18:40).
  late final DateTime inicio;
  late DateTime _realNoInicio;
  Duration _deslocamento = Duration.zero;

  DateTime agora() =>
      inicio.add(_agoraReal().difference(_realNoInicio) + _deslocamento);

  void avancar(Duration d) => _deslocamento += d;

  /// Volta ao início (18:40 de "hoje" original).
  void reiniciar() {
    _realNoInicio = _agoraReal();
    _deslocamento = Duration.zero;
  }
}
