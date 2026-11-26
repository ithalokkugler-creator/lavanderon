import 'dart:math';

import '../../core/formatos.dart';
import '../../domain/models/models.dart';
import 'estado_demo.dart';
import 'seed_conteudo.dart';

/// Usuários prontos para a tela de entrada da demo (apto, nome).
const usuariosDemo = [
  ('302', 'Maria'),
  ('410', 'Carlos'),
  ('105', 'Ana'),
  ('508', 'Rafael'),
];

/// Gerador pseudoaleatório determinístico (MINSTD), igual em todas as
/// plataformas, para a demo e os testes serem reproduzíveis.
class _Rnd {
  _Rnd(this._s);
  int _s;
  int next(int n) {
    _s = (_s * 48271) % 2147483647;
    return (_s >> 3) % n;
  }
}

const _nomesPool = [
  'João', 'Pedro', 'Lucas', 'Marcos', 'Paulo', 'Felipe', 'Gustavo', 'Ricardo',
  'André', 'Bruno', 'Daniel', 'Eduardo', 'Fernando', 'Henrique', 'Leonardo',
  'Rodrigo', 'Thiago', 'Vinícius', 'Diego', 'Fábio', 'Guilherme', 'Mateus',
  'Roberto', 'Sérgio', 'Alexandre', 'Maria', 'Ana', 'Beatriz', 'Juliana',
  'Camila', 'Fernanda', 'Patrícia', 'Aline', 'Carolina', 'Larissa', 'Mariana',
  'Renata', 'Sandra', 'Tatiana', 'Vanessa', 'Bianca', 'Cláudia', 'Débora',
  'Elaine', 'Gabriela', 'Helena', 'Isabela', 'Letícia', 'Priscila', 'Luciana',
];

const _fixos = <String, List<String>>{
  '302': ['Maria', 'João'],
  '410': ['Carlos'],
  '105': ['Ana'],
  '205': ['Pedro'],
  '612': ['Beatriz'],
  '508': ['Rafael'],
  '101': ['Lúcia'],
};

const _suspensos = {'508', '207', '313', '404', '116', '611'};
const _reservados = {'302', '410', '105', '205', '612', '101', '508'};

/// Popula [e] com o condomínio Vision "vivo" às 18:40 do dia da demo.
void popularSeedVision(EstadoDemo e) {
  final agora = e.relogio.inicio;
  final hoje = inicioDoDia(agora);
  DateTime t(int dia, int h, [int m = 0]) =>
      DateTime(hoje.year, hoje.month, hoje.day + dia, h, m);

  e.config = const ConfigRegras();

  // ------------------------------------------------------ Apartamentos
  for (var andar = 1; andar <= 6; andar++) {
    for (var n = 1; n <= 20; n++) {
      final id = '$andar${n.toString().padLeft(2, '0')}';
      final existe = n <= 18;
      final k = andar * 20 + n;
      final nomes = !existe
          ? <String>[]
          : _fixos[id] ??
              [
                _nomesPool[(k * 7) % _nomesPool.length],
                if (k.isEven) _nomesPool[(k * 11 + 3) % _nomesPool.length],
              ];
      // Evita nomes repetidos dentro do mesmo apartamento.
      final unicos = nomes.toSet().toList();
      e.apartamentos.add(Apartamento(
        id: id,
        andar: andar,
        existe: existe,
        ativo: !_suspensos.contains(id),
        moradoresNomes: unicos,
      ));
      for (var i = 0; i < unicos.length; i++) {
        e.moradores.add(Morador(id: 'm$id-${i + 1}', aptoId: id, nome: unicos[i]));
      }
    }
  }
  String nomeDe(String apto) =>
      e.apartamentos.firstWhere((a) => a.id == apto).moradoresNomes.first;

  // ---------------------------------------------------------- Máquinas
  for (var i = 1; i <= 6; i++) {
    e.maquinas['lav$i'] = Maquina(
      id: 'lav$i',
      nome: 'Lavadora $i',
      nomeCurto: 'Lav $i',
      tipo: TipoMaquina.lavadora,
      ordem: i,
      cicloMin: 45,
    );
    e.maquinas['sec$i'] = Maquina(
      id: 'sec$i',
      nome: 'Secadora $i',
      nomeCurto: 'Sec $i',
      tipo: TipoMaquina.secadora,
      ordem: 6 + i,
      cicloMin: 60,
    );
  }
  e.maquinas['lav5'] = e.maquinas['lav5']!.copyWith(
    status: StatusMaquina.bloqueadaHoje,
    motivoIndisponivel: 'Não centrifuga',
    indisponivelAte: DateTime(hoje.year, hoje.month, hoje.day, 23, 59),
  );
  e.maquinas['sec5'] = e.maquinas['sec5']!.copyWith(
    status: StatusMaquina.manutencao,
    motivoIndisponivel: 'Troca da correia',
    indisponivelAte: t(6, 18, 40),
  );

  // ----------------------------------------------------------- Reservas
  final ocupados = <String>{};
  String chave(String maq, DateTime ini) => '$maq|${ini.millisecondsSinceEpoch}';
  bool livre(String maq, DateTime ini) => !ocupados.contains(chave(maq, ini));

  Reserva criar({
    required String maq,
    required String apto,
    required DateTime ini,
    required StatusReserva st,
    int slots = 1,
    DateTime? checkin,
    int? dur,
    String? programa,
    bool imediato = false,
    DateTime? finalizada,
    OrigemAcao origem = OrigemAcao.app,
    String? quem,
  }) {
    final m = e.maquinas[maq]!;
    final fim = ini.add(Duration(hours: slots));
    final nome = quem ?? nomeDe(apto);
    for (var s = 0; s < slots; s++) {
      ocupados.add(chave(maq, ini.add(Duration(hours: s))));
    }
    final cron = (checkin != null && dur != null)
        ? Cronometro(
            programa: programa,
            duracaoMin: dur,
            iniciadoEm: checkin,
            terminaEm: checkin.add(Duration(minutes: dur)),
          )
        : null;
    final hist = <String>[
      e.linha(
          imediato
              ? 'Uso imediato iniciado por $nome no app'
              : 'Reserva criada por $nome no app',
          imediato ? checkin : ini.subtract(const Duration(hours: 20))),
      if (checkin != null && !imediato)
        e.linha('Uso confirmado por $nome no app', checkin),
      if (cron != null)
        e.linha(
            'Cronômetro ligado: ${minutosLegivel(cron.duracaoMin)}${programa != null ? ' ($programa)' : ''}, pronta às ${hora(cron.terminaEm)}',
            checkin),
      if (st == StatusReserva.concluida && finalizada != null)
        e.linha('Uso finalizado por $nome: roupa retirada', finalizada),
      if (st == StatusReserva.concluida && finalizada == null)
        e.linha('Horário encerrado', fim),
      if (st == StatusReserva.naoCompareceu)
        e.linha('Não compareceu: sem confirmação até ${hora(ini.add(const Duration(minutes: 15)))}',
            ini.add(const Duration(minutes: 15))),
      if (st == StatusReserva.cancelada)
        e.linha('Cancelada por $nome', ini.subtract(const Duration(hours: 3))),
    ];
    final r = Reserva(
      id: e.novoId('r'),
      maquinaId: maq,
      maquinaNome: m.nome,
      tipo: m.tipo,
      aptoId: apto,
      criadaPorNome: nome,
      inicio: ini,
      fim: fim,
      status: st,
      origem: origem,
      usoImediato: imediato,
      checkinEm: checkin,
      cronometro: cron,
      finalizadaEm: finalizada,
      motivoCancelamento:
          st == StatusReserva.cancelada ? 'Cancelada pelo apartamento' : null,
      historico: hist,
    );
    e.reservas[r.id] = r;
    return r;
  }

  // Estado ao vivo às 18:40.
  final rLav1 = criar(
    maq: 'lav1', apto: '205', ini: t(0, 18), st: StatusReserva.emUso,
    checkin: t(0, 18, 7), dur: 45, programa: 'Normal',
  );
  final rLav3 = criar(
    maq: 'lav3', apto: '410', ini: t(0, 18), st: StatusReserva.emUso,
    checkin: t(0, 17, 50), dur: 44, programa: 'Personalizado',
  );
  final rLav4 = criar(
    maq: 'lav4', apto: '302', ini: t(0, 19), st: StatusReserva.agendada,
  );
  final rSec2 = criar(
    maq: 'sec2', apto: '101', ini: t(0, 18), st: StatusReserva.emUso, slots: 2,
    checkin: t(0, 18, 14), dur: 60, programa: 'Normal',
  );
  final rSec4 = criar(
    maq: 'sec4', apto: '612', ini: t(0, 18), st: StatusReserva.emUso,
    checkin: t(0, 17, 50), dur: 55, programa: 'Personalizado',
  );
  criar(maq: 'sec6', apto: '105', ini: t(0, 19), st: StatusReserva.agendada);
  // Ap 205 já lavou na Lavadora 6 (a roupa foi retirada do balcão às 18:20).
  final rLav6 = criar(
    maq: 'lav6', apto: '205', ini: t(0, 17), st: StatusReserva.concluida,
    checkin: t(0, 17, 5), dur: 45, programa: 'Normal',
  );

  e.aguardando['lav3'] = Aguardando(
    reservaId: rLav3.id,
    aptoId: '410',
    desde: t(0, 18, 34),
  );
  e.flags
    ..add('cron5:${rLav3.id}')
    ..add('pronta:${rLav3.id}')
    ..add('lembrete:${rLav1.id}');

  // Pool de apartamentos para as reservas geradas.
  final pool = e.apartamentos
      .where((a) => a.existe && a.ativo && !_reservados.contains(a.id))
      .map((a) => a.id)
      .toList();
  var cursor = 0;
  final contagem = <String, int>{};
  String escolherApto(TipoMaquina tipo, DateTime dia) {
    for (var i = 0; i < pool.length; i++) {
      final apto = pool[(cursor + i) % pool.length];
      final k = '$apto|${tipo.index}|${dia.year}-${dia.month}-${dia.day}';
      if ((contagem[k] ?? 0) < 2) {
        contagem[k] = (contagem[k] ?? 0) + 1;
        cursor = (cursor + i + 1) % pool.length;
        return apto;
      }
    }
    return pool.first;
  }

  String idMaq(TipoMaquina tipo, int n) =>
      tipo == TipoMaquina.lavadora ? 'lav$n' : 'sec$n';

  // Noite de hoje: 19–22 h quase cheio, mais 23:00 e 02:00.
  const hojeLav = {19: [1, 3], 20: [1, 2, 3, 6], 21: [1, 2, 4, 6], 22: [2, 3, 4, 6], 23: [3], 26: [2]};
  const hojeSec = {19: [4], 20: [1, 2, 3, 6], 21: [1, 3, 4, 6], 22: [1, 2, 4], 23: [3], 26: [4]};
  for (final (tipo, mapa) in [
    (TipoMaquina.lavadora, hojeLav),
    (TipoMaquina.secadora, hojeSec),
  ]) {
    for (final en in mapa.entries) {
      for (final n in en.value) {
        final ini = t(0, en.key);
        if (!livre(idMaq(tipo, n), ini)) continue;
        criar(
          maq: idMaq(tipo, n),
          apto: escolherApto(tipo, inicioDoDia(ini)),
          ini: ini,
          st: StatusReserva.agendada,
        );
      }
    }
  }

  // Reservas da Maria (302) nos próximos dias.
  criar(maq: 'lav2', apto: '302', ini: t(1, 10), st: StatusReserva.agendada);
  criar(maq: 'sec1', apto: '302', ini: t(1, 11), st: StatusReserva.agendada);

  final rnd = _Rnd(20261126);
  const horasNoite = [
    7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 18, 19, 19, 19, 20, 20, 20,
    21, 21, 22, 22, 23,
  ];

  // Amanhã: grade bem movimentada.
  const porHora = {
    7: 1, 8: 2, 9: 3, 10: 2, 11: 2, 12: 1, 13: 1, 14: 2, 15: 2, 16: 2,
    17: 3, 18: 4, 19: 5, 20: 5, 21: 4, 22: 3,
  };
  for (final tipo in TipoMaquina.values) {
    for (final en in porHora.entries) {
      final alvo = tipo == TipoMaquina.secadora ? (en.value * 0.8).ceil() : en.value;
      final ordem = List.generate(6, (i) => i + 1)..shuffle(_Embaralha(rnd));
      var feitas = 0;
      for (final n in ordem) {
        if (feitas >= alvo) break;
        if (tipo == TipoMaquina.secadora && n == 5) continue;
        final ini = t(1, en.key);
        if (!livre(idMaq(tipo, n), ini)) continue;
        criar(
          maq: idMaq(tipo, n),
          apto: escolherApto(tipo, inicioDoDia(ini)),
          ini: ini,
          st: StatusReserva.agendada,
        );
        feitas++;
      }
    }
  }

  // Dias +2 a +6: movimento menor.
  for (var dia = 2; dia <= 6; dia++) {
    for (final tipo in TipoMaquina.values) {
      final qtd = tipo == TipoMaquina.lavadora ? 7 : 5;
      var feitas = 0;
      var tentativas = 0;
      while (feitas < qtd && tentativas++ < 60) {
        final h = horasNoite[rnd.next(horasNoite.length)];
        final n = 1 + rnd.next(6);
        if (tipo == TipoMaquina.secadora && n == 5) continue;
        final ini = t(dia, h);
        if (!livre(idMaq(tipo, n), ini)) continue;
        criar(
          maq: idMaq(tipo, n),
          apto: escolherApto(tipo, inicioDoDia(ini)),
          ini: ini,
          st: StatusReserva.agendada,
        );
        feitas++;
      }
    }
  }

  // Um combo de exemplo (RN-24): lavagem às 20h e secagem às 21h do dia +3,
  // de um apartamento do pool (não mexe em Ap 302).
  {
    final apto = pool.first;
    final lavIni = t(3, 20);
    final secIni = t(3, 21);
    final lavId = ['lav1', 'lav2', 'lav3', 'lav4', 'lav6']
        .firstWhere((m) => livre(m, lavIni), orElse: () => '');
    final secId = ['sec1', 'sec2', 'sec3', 'sec4', 'sec6']
        .firstWhere((m) => livre(m, secIni), orElse: () => '');
    if (lavId.isNotEmpty && secId.isNotEmpty) {
      final lav = criar(
          maq: lavId, apto: apto, ini: lavIni, st: StatusReserva.agendada);
      final sec = criar(
          maq: secId, apto: apto, ini: secIni, st: StatusReserva.agendada);
      final linha = e.linha('Combo lavar + secar',
          lavIni.subtract(const Duration(hours: 20)));
      e.reservas[lav.id] =
          lav.copyWith(comboId: 'c-seed', historico: [...lav.historico, linha]);
      e.reservas[sec.id] =
          sec.copyWith(comboId: 'c-seed', historico: [...sec.historico, linha]);
    }
  }

  // Histórico da Maria (302): ~10 entradas nos últimos 30 dias.
  final hist302 = <Reserva>[];
  const offsets = [-29, -26, -23, -20, -17, -14, -11, -8, -5, -2];
  for (var i = 0; i < offsets.length; i++) {
    final tipo = i.isEven ? TipoMaquina.lavadora : TipoMaquina.secadora;
    final maq = idMaq(tipo, 1 + (i % 4));
    final h = tipo == TipoMaquina.lavadora ? 19 : 20;
    final ini = t(offsets[i], h);
    if (!livre(maq, ini)) continue;
    final dur = tipo == TipoMaquina.lavadora ? 45 : 60;
    final cancelada = offsets[i] == -14;
    final chk = ini.add(Duration(minutes: 2 + i % 6));
    hist302.add(criar(
      maq: maq,
      apto: '302',
      ini: ini,
      st: cancelada ? StatusReserva.cancelada : StatusReserva.concluida,
      checkin: cancelada ? null : chk,
      dur: cancelada ? null : dur,
      programa: cancelada ? null : 'Normal',
      finalizada: cancelada ? null : chk.add(Duration(minutes: dur + 3)),
    ));
  }

  // Últimos 30 dias (para estatísticas) e as manhãs/tardes de hoje.
  const naoCompareceuPool = ['318', '212', '507', '107', '415', '318'];
  void gerarPassado(int dia, int qtd, List<int> horas) {
    var feitas = 0;
    var tentativas = 0;
    while (feitas < qtd && tentativas++ < 80) {
      final tipo =
          rnd.next(100) < 50 ? TipoMaquina.lavadora : TipoMaquina.secadora;
      final n = 1 + rnd.next(6);
      final h = horas[rnd.next(horas.length)];
      final ini = t(dia, h);
      final maq = idMaq(tipo, n);
      if (!livre(maq, ini)) continue;
      final sorteio = rnd.next(100);
      final st = sorteio < 90
          ? StatusReserva.concluida
          : sorteio < 96
              ? StatusReserva.naoCompareceu
              : StatusReserva.cancelada;
      final apto = st == StatusReserva.naoCompareceu && rnd.next(100) < 70
          ? naoCompareceuPool[rnd.next(naoCompareceuPool.length)]
          : escolherApto(tipo, inicioDoDia(ini));
      final aptoOk = e.apartamentos.any((a) => a.id == apto && a.existe);
      final dur = tipo == TipoMaquina.lavadora ? 45 : 60;
      final chk = ini.add(Duration(minutes: rnd.next(11)));
      criar(
        maq: maq,
        apto: aptoOk ? apto : pool.first,
        ini: ini,
        st: st,
        checkin: st == StatusReserva.concluida ? chk : null,
        dur: st == StatusReserva.concluida ? dur : null,
        programa: st == StatusReserva.concluida ? 'Normal' : null,
        finalizada: st == StatusReserva.concluida && rnd.next(100) < 80
            ? chk.add(Duration(minutes: dur + rnd.next(12)))
            : null,
      );
      feitas++;
    }
  }

  for (var dia = -30; dia <= -1; dia++) {
    final ini = t(dia, 0);
    final fimDeSemana = ini.weekday >= 6;
    gerarPassado(dia, 9 + rnd.next(6) + (fimDeSemana ? 4 : 0), horasNoite);
  }
  gerarPassado(0, 8, const [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);

  // ------------------------------------------------------- Ocorrências
  Ocorrencia oc(
    TipoOcorrencia tipo,
    String categoria,
    DateTime em, {
    String? maq,
    String? apto,
    String? descricao,
    StatusOcorrencia status = StatusOcorrencia.aberta,
    bool bloqueou = false,
    int conf = 1,
    String? deducao,
    String? provavel,
    bool confiavel = false,
    bool avisoEnviado = false,
    String? resposta,
    String? respostaApto,
    String? nome,
  }) {
    final o = Ocorrencia(
      id: e.novoId('o'),
      tipo: tipo,
      categoria: categoria,
      maquinaId: maq,
      maquinaNome: maq != null ? e.maquinas[maq]!.nome : null,
      descricao: descricao,
      relatorApto: apto,
      relatorNome: nome ?? (apto != null ? nomeDe(apto) : 'Zelador'),
      criadaEm: em,
      status: status,
      bloqueouMaquina: bloqueou,
      confirmacoes: conf,
      deducao: deducao,
      aptoProvavel: provavel,
      deducaoConfiavel: confiavel,
      avisoCondutaEnviado: avisoEnviado,
      resposta: resposta,
      respostaApto: respostaApto,
    );
    e.ocorrencias.add(o);
    return o;
  }

  oc(TipoOcorrencia.maquina, 'Não centrifuga', t(0, 17, 10),
      maq: 'lav5',
      apto: '612',
      descricao: 'Termina o ciclo e a roupa sai encharcada.',
      bloqueou: true,
      conf: 2);
  oc(TipoOcorrencia.lavanderia, 'Lâmpada queimada perto das secadoras',
      t(-1, 20, 30),
      apto: '204',
      descricao:
          'A lâmpada em cima das secadoras 3 e 4 queimou e o canto fica escuro.',
      status: StatusOcorrencia.emAndamento,
      resposta:
          'Obrigado pelo aviso! O zelador vai trocar a lâmpada amanhã cedo.');
  oc(TipoOcorrencia.usoIndevido, 'Máquina ocupada (uso não registrado)',
      t(-2, 19, 12),
      maq: 'lav2',
      apto: '309',
      descricao:
          'Ap 309 encontrou a Lavadora 2 ocupada no horário reservado e trocou para a Lavadora 6.',
      deducao:
          'Atraso: a reserva anterior da Lavadora 2 (Ap 214, 18:00) fez check-in e não finalizou o uso.',
      provavel: '214',
      confiavel: true,
      avisoEnviado: true,
      respostaApto:
          'Desculpem, o ciclo atrasou e eu estava no elevador. Vou me atentar ao cronômetro.');
  oc(TipoOcorrencia.usoIndevido, 'Máquina ocupada (uso não registrado)',
      t(-4, 21, 3),
      maq: 'sec3',
      apto: '417',
      descricao:
          'Ap 417 encontrou a Secadora 3 funcionando com roupa de alguém.',
      deducao:
          'Possível check-in na máquina errada: o Ap 503 confirmou uso na Secadora 4 há 6 min.',
      provavel: '503');
  oc(TipoOcorrencia.roupaRetirada, 'Roupa retirada antes do prazo', t(-1, 20, 5),
      maq: 'lav4',
      apto: '316',
      descricao: 'Deixada: no balcão da lavanderia.',
      deducao:
          'O Ap 316 retirou a roupa do Ap 108 às 20:05, antes do prazo (20:12).',
      provavel: '316',
      confiavel: true,
      avisoEnviado: true);

  // ------------------------------------------------------------- Roupas
  e.roupas.add(RoupaRetirada(
    id: e.novoId('rt'),
    maquinaId: 'lav6',
    maquinaNome: 'Lavadora 6',
    local: LocalRoupa.balcao,
    localTexto: 'Balcão da lavanderia',
    desde: t(0, 18, 20),
    donoConhecido: true,
    donoApto: '205',
  ));
  e.roupas.add(RoupaRetirada(
    id: e.novoId('rt'),
    maquinaId: 'lav4',
    maquinaNome: 'Lavadora 4',
    local: LocalRoupa.balcao,
    localTexto: 'Balcão da lavanderia',
    desde: t(-1, 20, 5),
    donoConhecido: true,
    donoApto: '108',
    antecipada: true,
    recolhidaEm: t(-1, 21, 30),
  ));

  // ----------------------------------------------- Conteúdo e comunicação
  e.noticias.addAll(noticiasVision(agora));
  e.tutoriais = tutoriaisVision;
  e.sugestoes.addAll(sugestoesVision(agora));

  // ------------------------------------------------------------- Avisos
  void aviso(String apto, String titulo, String corpo, CategoriaAviso cat,
      DateTime em,
      {bool lido = true, String? rota}) {
    e.avisar(apto, titulo, corpo, cat,
        em: em, lido: lido, rota: rota, emitir: false);
  }

  final ultima302 = hist302.isNotEmpty ? hist302.last : rLav4;
  final penultima302 = hist302.length > 1 ? hist302[hist302.length - 2] : rLav4;
  aviso('302', 'Reserva confirmada: Lavadora 4 às 19:00',
      'Hoje, 19:00. Você pode confirmar o uso a partir das 18:50.',
      CategoriaAviso.reserva, t(0, 17, 55),
      lido: false, rota: '/reserva/${rLav4.id}');
  aviso('302', 'Dedetização no sábado, 08:00–12:00',
      'A lavanderia fica fechada para a dedetização das áreas comuns no sábado, das 08:00 às 12:00.',
      CategoriaAviso.sindico, t(-1, 10, 0),
      lido: false);
  aviso('302', 'Secadora 5 em manutenção',
      'Troca da correia, com retorno previsto em cerca de 6 dias. Reservas nessa máquina foram remanejadas.',
      CategoriaAviso.sistema, t(-2, 15, 30),
      lido: false);
  aviso('302', 'Sua roupa está pronta!',
      'Sua roupa está pronta! Retire da ${penultima302.maquinaNome}.',
      CategoriaAviso.cronometro, penultima302.cronometro?.terminaEm ?? t(-5, 20, 50),
      rota: '/reserva/${penultima302.id}');
  aviso('302', 'Sua reserva começa em 15 min',
      '${ultima302.maquinaNome} às ${hora(ultima302.inicio)}. Você pode confirmar o uso a partir de 10 minutos antes.',
      CategoriaAviso.reserva, ultima302.inicio.subtract(const Duration(minutes: 15)),
      rota: '/reserva/${ultima302.id}');
  aviso('302', 'Suas roupas foram retiradas',
      'Suas roupas foram retiradas da Secadora 1 às 21:22 e estão no balcão da lavanderia.',
      CategoriaAviso.roupa, t(-6, 21, 22));

  aviso('410', 'Sua roupa está pronta!',
      'Sua roupa está pronta! Retire da Lavadora 3.', CategoriaAviso.cronometro,
      t(0, 18, 34),
      lido: false, rota: '/reserva/${rLav3.id}');
  aviso('205', 'Suas roupas foram retiradas',
      'Suas roupas foram retiradas da Lavadora 6 às 18:20 e estão no balcão da lavanderia.',
      CategoriaAviso.roupa, t(0, 18, 20),
      lido: false);
  aviso('214', 'Aviso de conduta',
      'Seu ciclo na Lavadora 2 passou do seu horário e o próximo morador precisou trocar de máquina. O síndico foi informado.',
      CategoriaAviso.conduta, t(-2, 19, 12));
  aviso('316', 'Aviso de conduta',
      'Você retirou a roupa da Lavadora 4 antes do prazo do dono. O síndico foi informado.',
      CategoriaAviso.conduta, t(-1, 20, 5));
  aviso('204', 'Sua ocorrência está em andamento',
      '"Lâmpada queimada perto das secadoras". Resposta do síndico: O zelador vai trocar a lâmpada amanhã cedo.',
      CategoriaAviso.ocorrencia, t(-1, 21, 0));
  aviso('612', 'Lavadora 5 bloqueada hoje',
      'Registramos seu relato "Não centrifuga" e a Lavadora 5 foi bloqueada até as 23:59.',
      CategoriaAviso.ocorrencia, t(0, 17, 10));
  aviso('101', 'Lembrete: Secadora 2 pronta às 19:14',
      'O cronômetro da Secadora 2 termina às 19:14.', CategoriaAviso.cronometro,
      t(0, 18, 14),
      rota: '/reserva/${rSec2.id}');
  // Evita avisos duplicados de início para reservas já em curso.
  e.flags
    ..add('lembrete:${rSec2.id}')
    ..add('lembrete:${rSec4.id}')
    ..add('lembrete:${rLav6.id}')
    ..add('lembrete:${rLav3.id}');

  e.moradorAtualId = null;
  e.ultimoTick = DateTime(
      agora.year, agora.month, agora.day, agora.hour, agora.minute);
}

/// Adaptador para usar o gerador determinístico em `List.shuffle`.
class _Embaralha implements Random {
  _Embaralha(this._r);
  final _Rnd _r;
  @override
  int nextInt(int max) => _r.next(max);
  @override
  bool nextBool() => _r.next(2) == 1;
  @override
  double nextDouble() => _r.next(1000000) / 1000000;
}
