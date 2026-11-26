import 'dart:async';

import 'package:collection/collection.dart';

import '../../core/formatos.dart';
import '../../domain/app_erro.dart';
import '../../domain/models/models.dart';
import 'relogio_demo.dart';

/// Roupa pronta numa máquina, esperando o dono (ou outro morador) retirar.
class Aguardando {
  const Aguardando({
    required this.reservaId,
    required this.aptoId,
    required this.desde,
  });
  final String reservaId;
  final String aptoId;

  /// Momento em que o ciclo terminou.
  final DateTime desde;
}

class PedidoAcesso {
  const PedidoAcesso(this.apto, this.nome, this.obs, this.em);
  final String apto;
  final String nome;
  final String? obs;
  final DateTime em;
}

/// Todo o estado mutável da demo (o "banco de dados" em memória) mais
/// consultas reutilizadas pelas regras. Não contém regra de negócio de ação.
class EstadoDemo {
  EstadoDemo(this.relogio);

  final RelogioDemo relogio;

  /// Durante a rotina por minuto, o "agora" é fixado no minuto processado.
  DateTime? agoraForcado;
  DateTime get agora => agoraForcado ?? relogio.agora();

  // Dados ---------------------------------------------------------------
  final Map<String, Maquina> maquinas = {};
  final Map<String, Reserva> reservas = {};
  final List<Ocorrencia> ocorrencias = [];
  final List<RoupaRetirada> roupas = [];
  final List<Noticia> noticias = [];
  List<Tutorial> tutoriais = [];
  final List<Sugestao> sugestoes = [];
  final List<Aviso> avisos = [];
  final List<Apartamento> apartamentos = [];
  final List<Morador> moradores = [];
  final List<Fechamento> fechamentos = [];
  ConfigRegras config = const ConfigRegras();

  /// Roupa pronta por máquina (máquina -> quem deve retirar).
  final Map<String, Aguardando> aguardando = {};

  /// "Ocupada (uso não registrado)" até o instante indicado.
  final Map<String, DateTime> ocupadaAte = {};

  /// Marcas de notificações já enviadas ("lembrete:r12"), evitam duplicar.
  final Set<String> flags = {};
  final Map<String, Set<String>> votos = {};
  final Map<String, List<DateTime>> tentativasLogin = {};
  final Map<String, DateTime> bloqueioLogin = {};
  final List<PedidoAcesso> pedidos = [];

  /// Último morador que agiu/entrou (para `votadaPorMim`).
  String? moradorAtualId;

  /// Último minuto simulado já processado pela rotina de tick.
  late DateTime ultimoTick;

  int _seq = 0;
  String novoId(String prefixo) => '$prefixo${++_seq}';

  // Notificação de mudanças ---------------------------------------------
  final StreamController<void> mudancas = StreamController<void>.broadcast();
  final StreamController<Aviso> novosAvisos = StreamController<Aviso>.broadcast();
  final StreamController<void> segundos = StreamController<void>.broadcast();

  void notificar() {
    if (!mudancas.isClosed) mudancas.add(null);
  }

  void limpar() {
    maquinas.clear();
    reservas.clear();
    ocorrencias.clear();
    roupas.clear();
    noticias.clear();
    tutoriais = [];
    sugestoes.clear();
    avisos.clear();
    apartamentos.clear();
    moradores.clear();
    fechamentos.clear();
    config = const ConfigRegras();
    aguardando.clear();
    ocupadaAte.clear();
    flags.clear();
    votos.clear();
    tentativasLogin.clear();
    bloqueioLogin.clear();
    pedidos.clear();
    moradorAtualId = null;
    _seq = 0;
  }

  void fechar() {
    mudancas.close();
    novosAvisos.close();
    segundos.close();
  }

  // Avisos ---------------------------------------------------------------
  Aviso avisar(
    String aptoId,
    String titulo,
    String corpo,
    CategoriaAviso categoria, {
    String? rota,
    DateTime? em,
    bool lido = false,
    bool emitir = true,
  }) {
    final a = Aviso(
      id: novoId('a'),
      aptoId: aptoId,
      titulo: titulo,
      corpo: corpo,
      categoria: categoria,
      criadoEm: em ?? agora,
      lido: lido,
      rota: rota,
    );
    avisos.add(a);
    if (emitir && !novosAvisos.isClosed) novosAvisos.add(a);
    return a;
  }

  /// Linha da linha do tempo de uma reserva: "18:07 · Uso confirmado".
  String linha(String texto, [DateTime? t]) {
    final quando = t ?? agora;
    final prefixo = mesmoDia(quando, agora)
        ? hora(quando)
        : '${dataCurta(quando)} ${hora(quando)}';
    return '$prefixo · $texto';
  }

  // Consultas -----------------------------------------------------------
  Maquina maquinaBase(String id) {
    final m = maquinas[id];
    if (m == null) {
      throw const AppErro('NAO_ENCONTRADO', 'Máquina não encontrada.');
    }
    return m;
  }

  List<Maquina> baseDoTipo(TipoMaquina t) =>
      maquinas.values.where((m) => m.tipo == t).sortedBy<num>((m) => m.ordem);

  Reserva reserva(String id) {
    final r = reservas[id];
    if (r == null) {
      throw const AppErro('NAO_ENCONTRADO', 'Reserva não encontrada.');
    }
    return r;
  }

  Apartamento apto(String id) {
    final a = apartamentos.firstWhereOrNull((a) => a.id == id);
    if (a == null) {
      throw const AppErro('APTO_INEXISTENTE',
          'Esse número não existe no prédio (101 a 120, 201 a 220 … 601 a 620).');
    }
    return a;
  }

  bool aptoAtivo(String id) =>
      apartamentos.firstWhereOrNull((a) => a.id == id)?.ativo ?? false;

  Ocorrencia ocorrencia(String id) {
    final o = ocorrencias.firstWhereOrNull((o) => o.id == id);
    if (o == null) {
      throw const AppErro('NAO_ENCONTRADO', 'Ocorrência não encontrada.');
    }
    return o;
  }

  void salvarOcorrencia(Ocorrencia o) {
    final i = ocorrencias.indexWhere((x) => x.id == o.id);
    if (i >= 0) ocorrencias[i] = o;
  }

  /// Início do slot (alinhado à meia-noite local) que contém [t].
  DateTime inicioDoSlot(DateTime t) {
    final dia = inicioDoDia(t);
    final min = t.difference(dia).inMinutes;
    final idx = min ~/ config.slotMin;
    return dia.add(Duration(minutes: idx * config.slotMin));
  }

  Duration get slot => Duration(minutes: config.slotMin);

  /// Reserva que segura a máquina em algum ponto de [ini, fim).
  Reserva? ocupante(String maquinaId, DateTime ini, DateTime fim,
      {String? exceto}) {
    for (final r in reservas.values) {
      if (r.maquinaId != maquinaId || r.id == exceto) continue;
      if (r.status != StatusReserva.agendada &&
          r.status != StatusReserva.emUso) {
        continue;
      }
      if (r.inicio.isBefore(fim) && r.fim.isAfter(ini)) return r;
    }
    return null;
  }

  /// A máquina está bloqueada/em manutenção em algum ponto de [ini, fim)?
  bool indisponivelNoPeriodo(Maquina base, DateTime ini, DateTime fim) {
    if (base.status == StatusMaquina.disponivel) return false;
    final ate = base.indisponivelAte;
    return ate == null || ini.isBefore(ate);
  }

  Fechamento? fechamentoNoPeriodo(DateTime ini, DateTime fim) =>
      fechamentos.firstWhereOrNull((f) => f.cobre(ini, fim));

  /// Quantas vezes a máquina foi usada nos últimos 30 dias (para balancear).
  int usoRecente(String maquinaId) {
    final desde = agora.subtract(const Duration(days: 30));
    return reservas.values
        .where((r) =>
            r.maquinaId == maquinaId &&
            r.inicio.isAfter(desde) &&
            (r.status == StatusReserva.concluida ||
                r.status == StatusReserva.emUso))
        .length;
  }

  /// Última reserva com uso confirmado nessa máquina (dono provável da roupa).
  Reserva? ultimoUsoConfirmado(String maquinaId, {String? exceto}) =>
      reservas.values
          .where((r) =>
              r.maquinaId == maquinaId &&
              r.id != exceto &&
              r.checkinEm != null &&
              (r.status == StatusReserva.emUso ||
                  r.status == StatusReserva.concluida ||
                  r.status == StatusReserva.interrompida))
          .sortedBy<DateTime>((r) => r.checkinEm!)
          .lastOrNull;

  void salvarReserva(Reserva r) => reservas[r.id] = r;

  String nomeApto(String id) => 'Ap $id';
}
