# Lavanderon

Demonstração (front-end apenas) do sistema de reserva da lavanderia do
Condomínio Vision. Feito em Flutter Web, em português do Brasil.

Não há servidor: tudo roda em memória, no navegador, com dados fictícios. A
arquitetura separa a interface dos dados para que, depois, uma implementação
com Firebase substitua a camada de demonstração sem mexer nas telas.

## O que a demo mostra

- Reserva de lavadoras e secadoras em horários de 1 hora, 24 horas por dia.
- Confirmação de uso, cronômetro e aviso de roupa pronta.
- "Usar agora", troca de máquina e "a máquina está ocupada".
- Problemas em máquinas e na lavanderia, com bloqueio e realocação de reservas.
- Roupa esquecida e roupa retirada.
- Perfis de morador, tablet e síndico.
- Relógio simulado: começa hoje às 18:40 e pode ser avançado para ver as
  regras acontecerem (não comparecimento, avisos, fim de bloqueios).

Usuários de teste (apartamento, nome): 302 Maria, 410 Carlos, 105 Ana e
508 Rafael (apartamento suspenso).

## Como rodar

```bash
flutter pub get
flutter run -d chrome
```

Testes e análise:

```bash
flutter test
flutter analyze
```

## Arquitetura (resumo)

```
lib/domain/   modelos, AppErro e o contrato LavanderonRepository
lib/data/demo implementação em memória, relógio simulado e dados do Vision
lib/app/      providers (Riverpod), rotas e app
lib/ui/       telas
lib/core/     formatos pt_BR e utilitários
```

A interface só chama `LavanderonRepository`. Detalhes, cobertura das regras de
negócio e o mapeamento para Cloud Functions estão em
[`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

## Trocar para Firebase no futuro

1. Criar `FirebaseLavanderonRepository implements LavanderonRepository` em
   `lib/data/firebase/` (veja o README dessa pasta, com o mapeamento método a
   método).
2. Em `lib/app/providers.dart`, devolver a nova classe em
   `lavanderonRepositoryProvider`. É o único ponto de troca.

## Publicação

O workflow `.github/workflows/deploy.yml` compila `flutter build web --release`
com `--base-href /<nome-do-repositorio>/` e publica no GitHub Pages a cada push
na `main`. A estratégia de URL é a padrão (com `#`), pois o GitHub Pages não
reescreve rotas.
