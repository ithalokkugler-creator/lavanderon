# Arquitetura do Lavanderon (demo)

## Camadas

```
lib/
  core/        formatos.dart (pt_BR), texto.dart (normalização)
  domain/      modelos puros, AppErro e o contrato LavanderonRepository
  data/
    demo/      implementação em memória (relógio simulado + seed do Vision)
    firebase/  README com o plano da implementação futura
  app/         providers (Riverpod), app.dart e router.dart
  ui/          telas e widgets (só conhecem o domínio e os providers)
```

Regra de dependência: `ui -> app/providers -> domain <- data`. A UI nunca
importa `data/`. O único ponto que escolhe a implementação é
`lavanderonRepositoryProvider` em `lib/app/providers.dart`.

### Dentro de `data/demo/`

| Arquivo | Papel |
|---|---|
| `relogio_demo.dart` | Relógio simulado: hoje 18:40, anda em tempo real, mais o deslocamento de `avancarRelogio` |
| `estado_demo.dart` | "Banco" em memória e consultas básicas (ocupante de um slot, indisponibilidade, fechamento) |
| `derivacao.dart` | Somente leitura: situação das máquinas, grade, alternativas, informação de roupa, estatísticas |
| `regras_reserva.dart` | Reservar, usar agora, confirmar uso, cronômetro, finalizar, cancelar, trocar |
| `regras_problemas.dart` | Problemas, máquina ocupada, roupa na máquina |
| `regras_admin.dart` | Máquinas, ocorrências, apartamentos, comunicados, fechamento, sugestões |
| `tick.dart` | Rotina por minuto simulado |
| `seed_vision.dart`, `seed_conteudo.dart` | Dados do condomínio Vision |
| `demo_lavanderon_repository.dart` | Fachada que implementa o contrato e expõe os streams |

## Contrato

`lib/domain/lavanderon_repository.dart` é a única coisa que a UI chama.

- **Streams** emitem o valor atual a cada novo ouvinte e voltam a emitir a cada
  mudança. São broadcast.
- **Ações** retornam `Future` e lançam `AppErro(codigo, mensagem)` com mensagem
  em português. Códigos: `SLOT_OCUPADO`, `LIMITE`, `FECHADA`,
  `FORA_JANELA_CHECKIN`, `MAQUINA_INDISPONIVEL`, `APTO_SUSPENSO`,
  `LOGIN_INVALIDO`, `MUITAS_TENTATIVAS`, `APTO_INEXISTENTE`,
  `CRONOMETRO_EXCEDE`, `NAO_PERMITIDO`, e dois extras da demo:
  `HORARIO_INVALIDO` (horário já iniciado ou além da antecedência) e
  `NAO_ENCONTRADO`.
- **Estado derivado**: `Maquina.situacao`, `livreAte`, `proximaReserva*`,
  `previsaoFim` e `alerta` são calculados pelo repositório a partir das
  reservas e do relógio, nunca gravados pela UI.

## Relógio e rotina por minuto

O relógio começa hoje às 18:40 (hora local) e anda em tempo real. Um `Timer`
de 1 s processa todos os minutos simulados pendentes (`Tick.executar`) e
avisa os streams. `avancarRelogio(d)` soma `d` e processa cada minuto
atravessado, na ordem. A rotina é idempotente: cada notificação grava uma
marca em `EstadoDemo.flags`.

## Cobertura das regras de negócio

| Regra | Onde |
|---|---|
| RN-01 slots fixos, 24 h | `Derivacao.grade`, `EstadoDemo.inicioDoSlot` |
| RN-02 duração do slot | `ConfigRegras.slotMin` |
| RN-03 antecedência e slot atual | `RegrasReserva.reservar` (`HORARIO_INVALIDO`) |
| RN-04 limites por apartamento | `RegrasReserva._checarLimites` |
| RN-05 até 2 slots seguidos | `RegrasReserva._fimParaCronometro` |
| RN-06 janela de check-in | `Reserva.podeConfirmar`, `RegrasReserva.confirmarUso` |
| RN-07 não comparecimento | `Tick` (reservas agendadas) |
| RN-08 cancelamento e tardio | `RegrasReserva.cancelar`, `Reserva.cancelamentoTardio` |
| RN-09 reserva é do apartamento | `RegrasReserva._exigirDono` |
| RN-10 reincidência | `Tick._verificarReincidencia` |
| RN-11 usar agora | `RegrasReserva.usarAgora` |
| RN-12 bloqueio e regra noturna | `RegrasProblemas.bloqueioAte`, `Tick` (fim do bloqueio) |
| RN-13 reservas afetadas | `RegrasProblemas.tratarReservasAfetadas`, `Tick` (precisaAcao expira) |
| RN-14 máquina ocupada | `RegrasProblemas.maquinaOcupada` |
| RN-15 prazo de retirada | `Derivacao.infoRoupa`, `Tick` (avisos de prazo) |
| RN-16 fechamento | `RegrasAdmin.fecharLavanderia` |
| RN-17 privacidade na grade | `SlotMaquina.aptoReserva` expõe só o apartamento |
| RN-18 manutenção | `RegrasAdmin.colocarManutencao` |
| RN-19 apartamento suspenso | `RegrasReserva.exigirAptoAtivo`, `RegrasAdmin.definirAptoAtivo` |
| RN-20 tentativas de login | `DemoLavanderonRepository.entrar` |
| RN-21 hora oficial | `RelogioDemo`, nunca `DateTime.now()` nas regras |
| RN-22 mudança de configuração | Não aplicável na demo (config fixa) |
| RN-23 fila de espera, RN-24 combo | Fora do escopo (F2) |
| RN-25 nome único normalizado | `core/texto.dart`, `entrar` |
| RN-26 retenção | Não aplicável na demo |
| RN-27 cronômetro | `RegrasReserva.confirmarUso`, `ajustarCronometro`, `Tick` |
| RN-28 roupa retirada | `RegrasProblemas.roupaNaMaquina`, `minhaRoupaFoiRetirada` |
| RN-29 aviso de conduta | `maquinaOcupada`, `roupaNaMaquina`, `RegrasAdmin.enviarAvisoConduta` |

## Método do repositório para Cloud Function / Firestore

Caminhos sob `condominios/{condoId}` (plano 13.1). Detalhes e observações em
`lib/data/firebase/README.md`.

| Método | Função (14.2) ou gatilho | Documentos |
|---|---|---|
| `entrar` | `loginMorador` | `moradores`, `apartamentos`, `privado/tentativasLogin` |
| `pedirAcesso` | `pedirAcesso` | `pedidosAcesso` |
| `reservar` | `criarReserva` | `agendas/{dia}`, `reservas` |
| `usarAgora` | `usarAgora` | `agendas/{dia}`, `reservas`, `maquinas.estadoAtual` |
| `confirmarUso` | `confirmarUso` | `reservas`, `agendas`, `maquinas.estadoAtual` |
| `ajustarCronometro` | `ajustarCronometro` | `reservas.cronometro`, `agendas` |
| `finalizar` | `finalizarUso` | `reservas`, `agendas`, `maquinas.estadoAtual` |
| `cancelar` / `cancelarReservaAdmin` | `cancelarReserva` | `reservas`, `agendas` |
| `trocarMaquina` | `trocarReserva` | `reservas`, `agendas` |
| `maquinaOcupada` | `reportarMaquinaOcupada` | `reservas`, `ocorrencias`, `avisos`, `maquinas` |
| `relatarProblemaMaquina` | `relatarProblemaMaquina`, `confirmarMesmoProblema` | `ocorrencias`, `maquinas`, `reservas`, `avisos` |
| `relatarProblemaLavanderia` | `relatarProblemaLavanderia` | `ocorrencias` |
| `roupaNaMaquina` | `roupaNaMaquina` | `roupasRetiradas`, `avisos`, `ocorrencias` |
| `minhaRoupaFoiRetirada` | `minhaRoupaFoiRetirada` | `ocorrencias`, `avisos` |
| `roupaRecolhida` | `roupaRecolhida` | `roupasRetiradas` |
| `responderAvisoConduta` | `responderAvisoConduta` | `ocorrencias.respostaApto` |
| `criarSugestao`, `votarSugestao` | `criarSugestao`, `votarSugestao` | `sugestoes`, `sugestoes/{id}/votos` |
| `marcarAvisoLido` | escrita direta (regras de segurança) | `avisos` |
| `marcarNoticiaLida` | escrita direta | `noticias/{id}/leituras/{moradorId}` |
| `bloquearMaquina`, `liberarMaquina`, `colocarManutencao`, `voltarCirculacao` | `admin*` | `maquinas`, `reservas`, `avisos` |
| `atualizarOcorrencia`, `enviarAvisoConduta` | `admin*` | `ocorrencias`, `avisos` |
| `definirAptoAtivo` | `admin*` | `apartamentos` |
| `publicarNoticia` | `admin*` + gatilho `onNoticiaPublicada` | `noticias`, push |
| `fecharLavanderia`, `reabrirLavanderia`, `impactoFechamento` | `admin*` | `fechamentos`, `reservas`, `agendas`, `avisos` |
| `alternativas` | `listarAlternativas` | leitura de `agendas` e `maquinas` |
| rotina por minuto (demo: `Tick`) | tarefa `tick` (14.3) | todos os acima |
| `avancarRelogio`, `restaurar` | `demo*` (somente emulador) | n/a |

## Decisões e interpretações da demo

- Limite diário (RN-04) conta reservas agendadas, em uso e já concluídas do
  dia; canceladas e não comparecidas não contam.
- `reservar` aceita só horários futuros; o horário em curso usa `usarAgora`.
- A ocorrência de problema em máquina é duplicada quando a máquina, o dia e a
  categoria (sem acentos/caixa) coincidem; isso soma uma confirmação.
- `finalizadaEm == null` em uma reserva concluída significa que ninguém tocou
  em "Já retirei" (o horário simplesmente acabou). A dedução de "máquina
  ocupada" usa isso para identificar o atraso do apartamento anterior.
- `novosAvisos()` emite avisos de todos os apartamentos (e do `sindico`); a UI
  filtra pelo apartamento logado.
