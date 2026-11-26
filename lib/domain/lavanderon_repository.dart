import 'models/models.dart';

/// Único ponto de contato da UI com os dados e as regras de negócio.
///
/// Hoje há uma implementação em memória (`DemoLavanderonRepository`). No futuro
/// uma `FirebaseLavanderonRepository` implementa a mesma interface (veja
/// `lib/data/firebase/README.md`), sem tocar na UI.
///
/// Convenções:
/// - Os `Stream`s emitem o valor atual imediatamente a cada novo ouvinte e
///   voltam a emitir a cada mudança.
/// - Ações lançam [AppErro] (de `app_erro.dart`) com `mensagem` em português.
abstract class LavanderonRepository {
  // ------------------------------------------------------------------ Leitura

  /// Hora oficial (simulada na demo). Emite a cada segundo real.
  Stream<DateTime> agora();
  DateTime get agoraAtual;

  Stream<List<Maquina>> maquinas();

  /// Mais recentes primeiro.
  Stream<List<Reserva>> reservasDoApto(String aptoId);
  Stream<List<Reserva>> reservasDoDia(DateTime dia);

  /// 24 horários de 1 hora (a lavanderia funciona 24 h).
  Stream<List<SlotGrade>> grade(DateTime dia, TipoMaquina tipo);

  /// Se [relatorApto] for informado, só as ocorrências daquele apartamento.
  Stream<List<Ocorrencia>> ocorrencias({String? relatorApto});

  /// Roupas retiradas de máquinas que ainda não foram recolhidas.
  Stream<List<RoupaRetirada>> roupasRetiradas();
  Stream<List<Noticia>> noticias();
  Future<List<Tutorial>> tutoriais();
  Stream<List<Sugestao>> sugestoes();
  Stream<List<Aviso>> avisos(String aptoId);

  /// Cada aviso no instante em que é criado (para toasts e alarmes).
  Stream<Aviso> novosAvisos();
  Stream<List<Apartamento>> apartamentos();
  Stream<List<Morador>> moradores();
  Stream<Fechamento?> fechamentoAtivo();
  Stream<ConfigRegras> config();
  Future<Estatisticas> estatisticas();
  Future<InfoRoupaMaquina> infoRoupaMaquina(String maquinaId);

  /// Máquinas livres do mesmo tipo naquele horário, as menos usadas primeiro.
  Future<List<Maquina>> alternativas({
    required TipoMaquina tipo,
    required DateTime inicio,
    String? excetoMaquinaId,
  });

  // ---------------------------------------------------------- Ações: morador

  Future<Morador> entrar(String apto, String nome);
  Future<void> pedirAcesso(String apto, String nome, String? obs);

  /// `maquinaId == null`: escolhe a máquina livre menos usada. RN-03/04.
  Future<Reserva> reservar({
    required Morador quem,
    required DateTime inicio,
    required TipoMaquina tipo,
    String? maquinaId,
    OrigemAcao origem = OrigemAcao.app,
  });

  /// RN-24: reserva uma lavadora em [inicioLavagem] e uma secadora no horário
  /// seguinte, juntas ou nenhuma. Os dois ids nulos escolhem a máquina livre
  /// menos usada de cada tipo. As duas reservas compartilham o `comboId`.
  Future<(Reserva lavagem, Reserva secagem)> reservarCombo({
    required Morador quem,
    required DateTime inicioLavagem,
    String? lavadoraId,
    String? secadoraId,
    OrigemAcao origem = OrigemAcao.app,
  });

  /// Quantas secadoras estão livres no horário logo após [inicioLavagem].
  Future<int> secadorasLivresApos(DateTime inicioLavagem);

  /// RN-11: reserva + check-in imediato, já com cronômetro.
  Future<Reserva> usarAgora({
    required Morador quem,
    required String maquinaId,
    required int duracaoMin,
    String? programa,
    OrigemAcao origem = OrigemAcao.app,
  });

  /// Máquina onde a reserva ainda não iniciada poderia começar agora (a
  /// própria; senão a livre menos usada do mesmo tipo), ou null. RN-06.
  Future<String?> maquinaParaAntecipar(String reservaId);

  /// RN-06 + RN-27. Antes da janela de check-in (ou com [maquinaId]
  /// diferente), a reserva é movida para começar agora no slot atual da
  /// máquina, liberando os horários originais; lança `MAQUINA_INDISPONIVEL`
  /// ou `CRONOMETRO_EXCEDE` se não der.
  Future<void> confirmarUso({
    required String reservaId,
    required Morador quem,
    required int duracaoMin,
    String? programa,
    OrigemAcao origem = OrigemAcao.app,
    String? maquinaId,
  });

  Future<void> ajustarCronometro(String reservaId, int deltaMin);
  Future<void> finalizar(String reservaId, Morador quem);
  Future<void> cancelar(String reservaId, Morador quem);
  Future<Reserva> trocarMaquina({
    required String reservaId,
    required String novaMaquinaId,
    required Morador quem,
  });

  /// Seção 6.7: move a reserva (com check-in) para [destinoMaquinaId] e
  /// registra a ocorrência de uso indevido na máquina original.
  Future<Reserva> maquinaOcupada({
    required String reservaId,
    required Morador quem,
    required String destinoMaquinaId,
  });

  Future<void> relatarProblemaMaquina({
    required Morador? quem,
    required String maquinaId,
    required String categoria,
    required bool impedeUso,
    String? descricao,
    OrigemAcao origem = OrigemAcao.app,
  });
  Future<void> relatarProblemaLavanderia({
    required Morador quem,
    required String categoria,
    required bool urgente,
    String? descricao,
  });

  /// RN-15/RN-28. `retirei == false`: só avisar o dono. Retirada antes do
  /// prazo exige `forcarAntecipada` e vira ocorrência de conduta.
  Future<RoupaRetirada?> roupaNaMaquina({
    required Morador quem,
    required String maquinaId,
    required bool retirei,
    LocalRoupa? local,
    String? localTexto,
    bool forcarAntecipada = false,
  });
  Future<void> minhaRoupaFoiRetirada({
    required Morador quem,
    required String maquinaId,
    required LocalRoupa ondeEncontrou,
    String? comentario,
  });
  Future<void> roupaRecolhida(String roupaId, Morador quem);
  Future<void> marcarAvisoLido(String avisoId);
  Future<void> marcarNoticiaLida(String id);
  Future<void> criarSugestao({
    required Morador quem,
    required String titulo,
    required String descricao,
    required String categoria,
  });

  /// Alterna o voto do morador (um voto por morador).
  Future<void> votarSugestao(String id, Morador quem);
  Future<void> responderAvisoConduta(String ocorrenciaId, String texto);

  // ----------------------------------------------------------- Ações: síndico

  Future<void> bloquearMaquina(String maquinaId, String motivo);
  Future<void> liberarMaquina(String maquinaId);
  Future<void> colocarManutencao(
      String maquinaId, String motivo, DateTime? previsao);
  Future<void> voltarCirculacao(String maquinaId);
  Future<void> atualizarOcorrencia(String id, StatusOcorrencia status,
      {String? resposta});
  Future<void> enviarAvisoConduta(String ocorrenciaId);
  Future<void> definirAptoAtivo(String aptoId, bool ativo);
  Future<void> publicarNoticia({
    required String titulo,
    required String corpo,
    required PrioridadeNoticia prioridade,
    bool fixada = false,
  });

  /// Devolve quantas reservas foram canceladas (as em uso são mantidas, RN-16).
  Future<int> fecharLavanderia(String motivo, {DateTime? ate});
  Future<void> reabrirLavanderia();
  Future<void> cancelarReservaAdmin(String reservaId, String motivo);

  /// Quantas reservas seriam canceladas por um fechamento até [ate].
  Future<int> impactoFechamento(DateTime? ate);

  // -------------------------------------------------------------------- Demo

  /// Avança o relógio simulado, rodando a rotina de cada minuto atravessado.
  void avancarRelogio(Duration d);

  /// Volta aos dados iniciais.
  void restaurar();
}
