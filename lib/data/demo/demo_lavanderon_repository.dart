import 'dart:async';

import 'package:collection/collection.dart';

import '../../core/formatos.dart';
import '../../core/texto.dart';
import '../../domain/app_erro.dart';
import '../../domain/lavanderon_repository.dart';
import '../../domain/models/models.dart';
import 'derivacao.dart';
import 'estado_demo.dart';
import 'regras_admin.dart';
import 'regras_problemas.dart';
import 'regras_reserva.dart';
import 'relogio_demo.dart';
import 'seed_vision.dart';
import 'tick.dart';

/// Stream "vivo": cada ouvinte recebe o valor atual na hora e depois um novo
/// valor a cada gatilho. É um stream broadcast (vários ouvintes).
class _StreamViva<T> extends Stream<T> {
  _StreamViva(this._calc, this._gatilho);
  final T Function() _calc;
  final Stream<void> _gatilho;

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    late StreamController<T> c;
    StreamSubscription<void>? sub;
    void emitir() {
      if (c.isClosed) return;
      try {
        c.add(_calc());
      } catch (erro, pilha) {
        c.addError(erro, pilha);
      }
    }

    c = StreamController<T>(
      onListen: () {
        emitir();
        sub = _gatilho.listen((_) => emitir());
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

/// Implementação em memória do repositório, com dados fictícios do
/// Condomínio Vision e relógio simulado.
class DemoLavanderonRepository implements LavanderonRepository {
  /// [autoTick] liga o relógio de 1 s (desligue nos testes e use
  /// [avancarRelogio]). [relogio] permite fixar a hora nos testes.
  DemoLavanderonRepository({RelogioDemo? relogio, bool autoTick = true})
      : _estado = EstadoDemo(relogio ?? RelogioDemo()) {
    _d = Derivacao(_estado);
    _reservas = RegrasReserva(_estado, _d);
    _problemas = RegrasProblemas(_estado, _d, _reservas);
    _admin = RegrasAdmin(_estado, _problemas);
    _tick = Tick(_estado, _d);
    popularSeedVision(_estado);
    _assinatura = _d.assinatura();
    if (autoTick) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _pulso());
    }
  }

  final EstadoDemo _estado;
  late final Derivacao _d;
  late final RegrasReserva _reservas;
  late final RegrasProblemas _problemas;
  late final RegrasAdmin _admin;
  late final Tick _tick;
  Timer? _timer;
  String _assinatura = '';

  EstadoDemo get _e => _estado;

  void dispose() {
    _timer?.cancel();
    _estado.fechar();
  }

  // ---------------------------------------------------------------- Relógio

  /// Roda a rotina de cada minuto simulado ainda não processado.
  bool _processar() {
    final alvo = _e.relogio.agora();
    var mudou = false;
    while (true) {
      final prox = _e.ultimoTick.add(const Duration(minutes: 1));
      if (prox.isAfter(alvo)) break;
      _e.ultimoTick = prox;
      _e.agoraForcado = prox;
      try {
        if (_tick.executar()) mudou = true;
        if (prox.minute == 0) mudou = true;
      } finally {
        _e.agoraForcado = null;
      }
    }
    return mudou;
  }

  void _pulso() {
    final mudou = _processar();
    final ass = _d.assinatura();
    if (mudou || ass != _assinatura) {
      _assinatura = ass;
      _e.notificar();
    }
    if (!_e.segundos.isClosed) _e.segundos.add(null);
  }

  @override
  void avancarRelogio(Duration d) {
    _e.relogio.avancar(d);
    _processar();
    _assinatura = _d.assinatura();
    _e.notificar();
    if (!_e.segundos.isClosed) _e.segundos.add(null);
  }

  @override
  void restaurar() {
    _e.limpar();
    _e.relogio.reiniciar();
    popularSeedVision(_e);
    _assinatura = _d.assinatura();
    _e.notificar();
    if (!_e.segundos.isClosed) _e.segundos.add(null);
  }

  Future<T> _acao<T>(T Function() f) async {
    _processar();
    final r = f();
    _assinatura = _d.assinatura();
    _e.notificar();
    return r;
  }

  Stream<T> _viva<T>(T Function() calc) =>
      _StreamViva<T>(() {
        _processar();
        return calc();
      }, _e.mudancas.stream);

  // ---------------------------------------------------------------- Leitura

  @override
  Stream<DateTime> agora() => _StreamViva<DateTime>(() => _e.agora, _e.segundos.stream);

  @override
  DateTime get agoraAtual => _e.agora;

  @override
  Stream<List<Maquina>> maquinas() => _viva(() => List.unmodifiable(_d.maquinas()));

  @override
  Stream<List<Reserva>> reservasDoApto(String aptoId) => _viva(() =>
      List.unmodifiable(_e.reservas.values
          .where((r) => r.aptoId == aptoId)
          .sortedBy<DateTime>((r) => r.inicio)
          .reversed));

  @override
  Stream<List<Reserva>> reservasDoDia(DateTime dia) => _viva(() {
        final d0 = inicioDoDia(dia);
        final d1 = d0.add(const Duration(days: 1));
        return List.unmodifiable(_e.reservas.values
            .where((r) => r.inicio.isBefore(d1) && r.fim.isAfter(d0))
            .sortedBy<DateTime>((r) => r.inicio));
      });

  @override
  Stream<List<SlotGrade>> grade(DateTime dia, TipoMaquina tipo) =>
      _viva(() => List.unmodifiable(_d.grade(dia, tipo)));

  @override
  Stream<List<Ocorrencia>> ocorrencias({String? relatorApto}) =>
      _viva(() => List.unmodifiable(_e.ocorrencias
          .where((o) => relatorApto == null || o.relatorApto == relatorApto)
          .sortedBy<DateTime>((o) => o.criadaEm)
          .reversed));

  @override
  Stream<List<RoupaRetirada>> roupasRetiradas() =>
      _viva(() => List.unmodifiable(_e.roupas
          .where((r) => !r.recolhida)
          .sortedBy<DateTime>((r) => r.desde)
          .reversed));

  @override
  Stream<List<Noticia>> noticias() =>
      _viva(() => List.unmodifiable(_admin.noticiasOrdenadas()));

  @override
  Future<List<Tutorial>> tutoriais() async => List.unmodifiable(_e.tutoriais);

  @override
  Stream<List<Sugestao>> sugestoes() => _viva(() {
        final eu = _e.moradorAtualId;
        final lista = _e.sugestoes
            .map((s) => s.copyWith(
                votadaPorMim: eu != null && (_e.votos[s.id]?.contains(eu) ?? false)))
            .toList()
          ..sort((a, b) => b.votos.compareTo(a.votos));
        return List<Sugestao>.unmodifiable(lista);
      });

  @override
  Stream<List<Aviso>> avisos(String aptoId) => _viva(() => List.unmodifiable(
      _e.avisos
          .where((a) => a.aptoId == aptoId)
          .sortedBy<DateTime>((a) => a.criadoEm)
          .reversed));

  @override
  Stream<Aviso> novosAvisos() => _e.novosAvisos.stream;

  @override
  Stream<List<Apartamento>> apartamentos() =>
      _viva(() => List.unmodifiable(_e.apartamentos));

  @override
  Stream<List<Morador>> moradores() => _viva(() => List.unmodifiable(_e.moradores));

  @override
  Stream<Fechamento?> fechamentoAtivo() => _viva(() {
        final agora = _e.agora;
        return _e.fechamentos.firstWhereOrNull((f) =>
            f.ativo &&
            !f.inicio.isAfter(agora) &&
            (f.fim == null || f.fim!.isAfter(agora)));
      });

  @override
  Stream<ConfigRegras> config() => _viva(() => _e.config);

  @override
  Future<Estatisticas> estatisticas() async {
    _processar();
    return _d.estatisticas();
  }

  @override
  Future<InfoRoupaMaquina> infoRoupaMaquina(String maquinaId) async {
    _processar();
    return _d.infoRoupa(maquinaId);
  }

  @override
  Future<List<Maquina>> alternativas({
    required TipoMaquina tipo,
    required DateTime inicio,
    String? excetoMaquinaId,
  }) async {
    _processar();
    return _d.alternativas(tipo, inicio, excetoMaquinaId: excetoMaquinaId);
  }

  // ------------------------------------------------------------ Entrar

  /// Valida o formato Vision: 101–620, final de 01 a 20. Devolve o id.
  String _validarApto(String entrada) {
    final digitos = entrada.replaceAll(RegExp(r'\D'), '');
    const erro = AppErro('APTO_INEXISTENTE',
        'Esse número não existe no prédio (101 a 120, 201 a 220 … 601 a 620).');
    if (digitos.length != 3) throw erro;
    final n = int.parse(digitos);
    final andar = n ~/ 100;
    final fim = n % 100;
    if (andar < 1 || andar > 6 || fim < 1 || fim > 20) throw erro;
    final a = _e.apartamentos.firstWhereOrNull((a) => a.id == digitos);
    if (a == null || !a.existe) throw erro;
    return digitos;
  }

  @override
  Future<Morador> entrar(String apto, String nome) async {
    _processar();
    final id = _validarApto(apto);
    final agora = _e.agora;
    final bloqueio = _e.bloqueioLogin[id];
    if (bloqueio != null && bloqueio.isAfter(agora)) {
      throw const AppErro('MUITAS_TENTATIVAS',
          'Muitas tentativas. Tente de novo em 15 minutos.');
    }
    final alvo = normalizarTexto(nome);
    final achado = alvo.isEmpty
        ? null
        : _e.moradores.firstWhereOrNull((m) {
            if (m.aptoId != id || !m.ativo) return false;
            final mn = normalizarTexto(m.nome);
            return mn == alvo || mn == alvo.split(' ').first;
          });
    if (achado == null) {
      final lista = (_e.tentativasLogin[id] ?? [])
          .where((t) => agora.difference(t) < const Duration(minutes: 15))
          .toList()
        ..add(agora);
      _e.tentativasLogin[id] = lista;
      if (lista.length >= 10) {
        _e.bloqueioLogin[id] = agora.add(const Duration(minutes: 15));
        _e.tentativasLogin.remove(id);
      }
      throw const AppErro(
          'LOGIN_INVALIDO', 'Não encontramos esse nome nesse apartamento.');
    }
    _e.tentativasLogin.remove(id);
    _e.moradorAtualId = achado.id;
    return achado;
  }

  @override
  Future<void> pedirAcesso(String apto, String nome, String? obs) =>
      _acao(() {
        final id = _validarApto(apto);
        if (nome.trim().isEmpty) {
          throw const AppErro('LOGIN_INVALIDO', 'Informe o seu nome.');
        }
        _e.pedidos.add(PedidoAcesso(id, nome.trim(), obs, _e.agora));
        _e.avisar(
          'sindico',
          'Pedido de acesso',
          '${nome.trim()} (Ap $id) pediu acesso ao Lavanderon.${obs != null && obs.trim().isNotEmpty ? ' Obs.: ${obs.trim()}' : ''}',
          CategoriaAviso.sistema,
        );
      });

  // ------------------------------------------------------ Ações: morador

  @override
  Future<Reserva> reservar({
    required Morador quem,
    required DateTime inicio,
    required TipoMaquina tipo,
    String? maquinaId,
    OrigemAcao origem = OrigemAcao.app,
  }) =>
      _acao(() {
        _e.moradorAtualId = quem.id;
        return _reservas.reservar(
            quem: quem,
            inicio: inicio,
            tipo: tipo,
            maquinaId: maquinaId,
            origem: origem);
      });

  @override
  Future<Reserva> usarAgora({
    required Morador quem,
    required String maquinaId,
    required int duracaoMin,
    String? programa,
    OrigemAcao origem = OrigemAcao.app,
  }) =>
      _acao(() => _reservas.usarAgora(
          quem: quem,
          maquinaId: maquinaId,
          duracaoMin: duracaoMin,
          programa: programa,
          origem: origem));

  @override
  Future<void> confirmarUso({
    required String reservaId,
    required Morador quem,
    required int duracaoMin,
    String? programa,
    OrigemAcao origem = OrigemAcao.app,
  }) =>
      _acao(() => _reservas.confirmarUso(
          reservaId: reservaId,
          quem: quem,
          duracaoMin: duracaoMin,
          programa: programa,
          origem: origem));

  @override
  Future<void> ajustarCronometro(String reservaId, int deltaMin) =>
      _acao(() => _reservas.ajustarCronometro(reservaId, deltaMin));

  @override
  Future<void> finalizar(String reservaId, Morador quem) =>
      _acao(() => _reservas.finalizar(reservaId, quem));

  @override
  Future<void> cancelar(String reservaId, Morador quem) =>
      _acao(() => _reservas.cancelar(reservaId, quem));

  @override
  Future<Reserva> trocarMaquina({
    required String reservaId,
    required String novaMaquinaId,
    required Morador quem,
  }) =>
      _acao(() => _reservas.trocarMaquina(
          reservaId: reservaId, novaMaquinaId: novaMaquinaId, quem: quem));

  @override
  Future<Reserva> maquinaOcupada({
    required String reservaId,
    required Morador quem,
    required String destinoMaquinaId,
  }) =>
      _acao(() => _problemas.maquinaOcupada(
          reservaId: reservaId, quem: quem, destinoMaquinaId: destinoMaquinaId));

  @override
  Future<void> relatarProblemaMaquina({
    required Morador? quem,
    required String maquinaId,
    required String categoria,
    required bool impedeUso,
    String? descricao,
    OrigemAcao origem = OrigemAcao.app,
  }) =>
      _acao(() => _problemas.relatarProblemaMaquina(
          quem: quem,
          maquinaId: maquinaId,
          categoria: categoria,
          impedeUso: impedeUso,
          descricao: descricao,
          origem: origem));

  @override
  Future<void> relatarProblemaLavanderia({
    required Morador quem,
    required String categoria,
    required bool urgente,
    String? descricao,
  }) =>
      _acao(() => _problemas.relatarProblemaLavanderia(
          quem: quem,
          categoria: categoria,
          urgente: urgente,
          descricao: descricao));

  @override
  Future<RoupaRetirada?> roupaNaMaquina({
    required Morador quem,
    required String maquinaId,
    required bool retirei,
    LocalRoupa? local,
    String? localTexto,
    bool forcarAntecipada = false,
  }) =>
      _acao(() => _problemas.roupaNaMaquina(
          quem: quem,
          maquinaId: maquinaId,
          retirei: retirei,
          local: local,
          localTexto: localTexto,
          forcarAntecipada: forcarAntecipada));

  @override
  Future<void> minhaRoupaFoiRetirada({
    required Morador quem,
    required String maquinaId,
    required LocalRoupa ondeEncontrou,
    String? comentario,
  }) =>
      _acao(() => _problemas.minhaRoupaFoiRetirada(
          quem: quem,
          maquinaId: maquinaId,
          ondeEncontrou: ondeEncontrou,
          comentario: comentario));

  @override
  Future<void> roupaRecolhida(String roupaId, Morador quem) =>
      _acao(() => _problemas.roupaRecolhida(roupaId, quem));

  @override
  Future<void> marcarAvisoLido(String avisoId) =>
      _acao(() => _admin.marcarAvisoLido(avisoId));

  @override
  Future<void> marcarNoticiaLida(String id) =>
      _acao(() => _admin.marcarNoticiaLida(id));

  @override
  Future<void> criarSugestao({
    required Morador quem,
    required String titulo,
    required String descricao,
    required String categoria,
  }) =>
      _acao(() => _admin.criarSugestao(
          quem: quem, titulo: titulo, descricao: descricao, categoria: categoria));

  @override
  Future<void> votarSugestao(String id, Morador quem) =>
      _acao(() => _admin.votarSugestao(id, quem));

  @override
  Future<void> responderAvisoConduta(String ocorrenciaId, String texto) =>
      _acao(() => _admin.responderAvisoConduta(ocorrenciaId, texto));

  // ------------------------------------------------------ Ações: síndico

  @override
  Future<void> bloquearMaquina(String maquinaId, String motivo) =>
      _acao(() => _admin.bloquearMaquina(maquinaId, motivo));

  @override
  Future<void> liberarMaquina(String maquinaId) =>
      _acao(() => _admin.liberarMaquina(maquinaId));

  @override
  Future<void> colocarManutencao(
          String maquinaId, String motivo, DateTime? previsao) =>
      _acao(() => _admin.colocarManutencao(maquinaId, motivo, previsao));

  @override
  Future<void> voltarCirculacao(String maquinaId) =>
      _acao(() => _admin.voltarCirculacao(maquinaId));

  @override
  Future<void> atualizarOcorrencia(String id, StatusOcorrencia status,
          {String? resposta}) =>
      _acao(() => _admin.atualizarOcorrencia(id, status, resposta: resposta));

  @override
  Future<void> enviarAvisoConduta(String ocorrenciaId) =>
      _acao(() => _admin.enviarAvisoConduta(ocorrenciaId));

  @override
  Future<void> definirAptoAtivo(String aptoId, bool ativo) =>
      _acao(() => _admin.definirAptoAtivo(aptoId, ativo));

  @override
  Future<void> publicarNoticia({
    required String titulo,
    required String corpo,
    required PrioridadeNoticia prioridade,
    bool fixada = false,
  }) =>
      _acao(() => _admin.publicarNoticia(
          titulo: titulo, corpo: corpo, prioridade: prioridade, fixada: fixada));

  @override
  Future<int> fecharLavanderia(String motivo, {DateTime? ate}) =>
      _acao(() => _admin.fecharLavanderia(motivo, ate: ate));

  @override
  Future<void> reabrirLavanderia() => _acao(_admin.reabrirLavanderia);

  @override
  Future<void> cancelarReservaAdmin(String reservaId, String motivo) =>
      _acao(() => _admin.cancelarReservaAdmin(reservaId, motivo));

  @override
  Future<int> impactoFechamento(DateTime? ate) async {
    _processar();
    return _admin.impactoFechamento(ate);
  }
}
