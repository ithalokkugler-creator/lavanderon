# Camada Firebase (futura)

Hoje o app roda 100% em memória com `DemoLavanderonRepository`
(`lib/data/demo/`). Esta pasta existe para a futura
`FirebaseLavanderonRepository`, que implementa **a mesma interface**
(`lib/domain/lavanderon_repository.dart`) sem que a UI mude uma linha.

Não há código nem dependências Firebase neste momento.

## Como trocar

1. Adicionar `firebase_core`, `cloud_firestore`, `cloud_functions` e
   `firebase_auth` ao `pubspec.yaml` e gerar `firebase_options.dart`.
2. Criar `lib/data/firebase/firebase_lavanderon_repository.dart` com
   `class FirebaseLavanderonRepository implements LavanderonRepository`.
3. Em `lib/app/providers.dart`, trocar o corpo de
   `lavanderonRepositoryProvider` para devolver a nova classe. Esse é o único
   ponto de troca.
4. Remover `avancarRelogio` e `restaurar` do uso na UI (ficam no-op ou só
   funcionam no emulador, como as callables `demo*` do plano, seção 21.6).

## Mapeamento método a método

Caminhos Firestore da seção 13.1 do plano, sob `condominios/{condoId}`.
Callables e gatilhos da seção 14. A tabela completa e a cobertura das regras
estão em [`docs/ARQUITETURA.md`](../../../docs/ARQUITETURA.md).

| Método do repositório | Firebase |
|---|---|
| `agora()` / `agoraAtual` | Hora do servidor (RN-21): `Timestamp` de uma callable leve ou `serverTimestamp`; o app só usa para exibir cronômetros |
| `maquinas()` | Snapshot de `maquinas` + `agendas/{hoje}` (o campo `estadoAtual` da máquina é mantido pelas Functions) |
| `reservasDoApto` | Query `reservas` where `aptoId == x` order by `inicio desc` |
| `reservasDoDia` | Documento `agendas/{AAAA-MM-DD}` (mais `reservas` do dia) |
| `grade` | Documento `agendas/{AAAA-MM-DD}` + `maquinas` + `fechamentos`; a grade é gerada no app |
| `ocorrencias` | Query `ocorrencias` (morador: where `relatorApto`) |
| `roupasRetiradas` | Query `roupasRetiradas` where `recolhidaEm == null` |
| `noticias` / `tutoriais` / `sugestoes` | Coleções `noticias`, `tutoriais`, `sugestoes` (+ `leituras`, `votos`) |
| `avisos` / `novosAvisos` | Query `avisos` where `aptoId == x`; `novosAvisos` = `docChanges` do tipo `added` + push (FCM) |
| `apartamentos` / `moradores` | Coleções `apartamentos`, `moradores` (síndico) |
| `fechamentoAtivo` / `config` | `fechamentos` ativos / documento de configuração do condomínio |
| `estatisticas` | `estatisticasDiarias` + `contadores30d` (gerados pela `rotinaDiaria`) |
| `infoRoupaMaquina` | Leitura de `maquinas/{id}.estadoAtual` + última `reservas` com check-in |
| `alternativas` | Callable `listarAlternativas` |
| `entrar` | Callable `loginMorador` (devolve custom token; tentativas em `privado/tentativasLogin`) |
| `pedirAcesso` | Callable `pedirAcesso` (cria `pedidosAcesso`) |
| `reservar` | Callable `criarReserva` (transação em `agendas` + `reservas`) |
| `usarAgora` | Callable `usarAgora` |
| `confirmarUso` | Callable `confirmarUso` |
| `ajustarCronometro` | Callable `ajustarCronometro` |
| `finalizar` | Callable `finalizarUso` |
| `cancelar` | Callable `cancelarReserva` |
| `trocarMaquina` | Callable `trocarReserva` |
| `maquinaOcupada` | Callable `reportarMaquinaOcupada` |
| `relatarProblemaMaquina` | Callable `relatarProblemaMaquina` (e `confirmarMesmoProblema` para duplicidade) |
| `relatarProblemaLavanderia` | Callable `relatarProblemaLavanderia` |
| `roupaNaMaquina` | Callable `roupaNaMaquina` |
| `minhaRoupaFoiRetirada` | Callable `minhaRoupaFoiRetirada` |
| `roupaRecolhida` | Callable `roupaRecolhida` |
| `marcarAvisoLido` | Escrita direta permitida pelas regras em `avisos/{id}.lido` |
| `marcarNoticiaLida` | Escrita em `noticias/{id}/leituras/{moradorId}` |
| `criarSugestao` / `votarSugestao` | Callables `criarSugestao` / `votarSugestao` |
| `responderAvisoConduta` | Callable `responderAvisoConduta` |
| `bloquearMaquina`, `liberarMaquina`, `colocarManutencao`, `voltarCirculacao` | Callables `admin*` de máquinas |
| `atualizarOcorrencia`, `enviarAvisoConduta` | Callables `admin*` de ocorrências |
| `definirAptoAtivo` | Callable `admin*` de apartamentos |
| `publicarNoticia` | Callable `admin*` de comunicados (gatilho `onNoticiaPublicada` envia push) |
| `fecharLavanderia`, `reabrirLavanderia`, `impactoFechamento` | Callables `admin*` de fechamentos |
| `cancelarReservaAdmin` | Callable `cancelarReserva` com papel de administrador |

## O que a demo faz no cliente e o Firebase faz no servidor

- **Rotina por minuto** (`Tick` em `lib/data/demo/tick.dart`): no Firebase é a
  tarefa agendada `tick` (plano 14.3). A UI só escuta; não executa regras.
- **Erros**: as Functions devolvem `HttpsError` com o código da seção 14.6; o
  repositório converte em `AppErro(codigo, mensagem)`.
- **Hora**: nunca usar o relógio do aparelho para decidir nada (RN-21).
