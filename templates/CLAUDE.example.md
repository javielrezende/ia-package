# CLAUDE.md — exemplo para projetos que usam o ia-package

Copie este arquivo para a **raiz do seu projeto** (o projeto onde o pipeline vai
rodar, não este repositório do plugin) com o nome `CLAUDE.md` e ajuste os caminhos
e a stack.

O plugin traz as skills; este arquivo traz o que é específico do seu projeto e que
o plugin não tem como adivinhar: onde os documentos moram, qual a stack, e qual
convenção o time segue.

Não copie o README do plugin para cá — ele é versionado junto com as skills e
atualiza sozinho. Deixe só o ponteiro abaixo.

---

## Pipeline agêntico

Este projeto usa o pipeline do plugin **ia-package**: PRD → spec/plan/contract →
implementação → avaliação → correção → PR/MR.

Fluxo completo, comandos, overrides e estados finais:
<https://github.com/javielrezende/ia-package>

---

## Documentação deste projeto

Todo artefato do pipeline vive em `docs/`:

| Artefato | Caminho | Gerado por |
|---|---|---|
| PRD do produto | `docs/PRD.md` | `prd-writer-for-complete-project` |
| Estado das features | `docs/prd_progress.json` | `prd-writer-for-complete-project`, atualizado pelo resto do pipeline |
| Spec + plano + contrato | `docs/<Fxx-nome>/spec.md`, `plan.md` e `contract.md` | `spec-writer` |
| Relatório de avaliação | `docs/<Fxx-nome>/eval-report-<ts>.md` | `evaluator` |
| Screenshots da avaliação | `docs/<Fxx-nome>/eval-screenshots-<ts>/` | `evaluator`, quando a feature tem itens `UI-*`/`E2E-*` |
| Relatório de design | `docs/<Fxx-nome>/design-report-<ts>.md` | `design-review` |
| Screenshots do design review | `docs/<Fxx-nome>/design-screenshots-<ts>/` | `design-review` |
| Journal de orquestração | `docs/<Fxx-nome>/orchestration-<ts>.md` | `implement-and-evaluate` — inclusive dentro de cada worktree, quando a feature roda numa wave |
| Status da wave | `.claude/worktrees/.wave-<run-id>/wave-status.md` | `implement-and-evaluate-tmux`. **Não é versionado**: vive no disco local e some se a pasta for limpa |
| Diretriz de código | `docs/<linguagem>-development-guidelines.md` | `generate-development-guideline` |

Pastas de feature seguem `docs/F01-nome-da-feature/`, com o ID vindo do PRD do produto.

A diretriz de código é um arquivo por linguagem: `docs/go-development-guidelines.md`,
`docs/typescript-development-guidelines.md`.

Os `eval-report-*.md` e os `orchestration-*.md` são histórico imutável com timestamp:
nunca são editados à mão nem sobrescritos, e cada execução gera um arquivo novo.

## Forge

<!-- Onde este projeto hospeda issues e pull/merge requests. Deixe descomentada
     apenas a linha que vale. O pipeline detecta sozinho pelo `git remote` quando
     o host é `github.com` ou tem `gitlab` no nome; esta linha existe para vencer
     a detecção — e é obrigatória em GitLab auto-hospedado num host que não se
     chama `gitlab.*` (é o caso da maioria das instalações corporativas). -->

- Forge: github
<!-- - Forge: gitlab -->

O CLI correspondente precisa estar instalado e autenticado para que a criação de
issue e de PR/MR funcione: `gh` para GitHub, `glab` para GitLab. Sem ele, o
pipeline não trava — ele faz todo o trabalho, salva os arquivos, commita e
imprime o comando manual do que faltou.

Uma única skill não degrada assim: o `implement-and-evaluate-tmux` checa o CLI
antes de despachar a wave e aborta na largada, porque falhar no início custa menos
que descobrir depois de 30 minutos que nenhuma equipe consegue abrir MR. Isso não
faz dele *o* executor do pipeline — ele é apenas a porta de entrada paralela. Ver
**Ordem de trabalho** abaixo.

## Permissões

O pipeline roda sozinho por dezenas de minutos. Se ele parar para pedir aprovação de
um comando, a execução fica esperando — e numa wave paralela, a janela daquela equipe
fica parada até o `team-timeout` matá-la.

A forma recomendada de evitar isso **não** é desligar as permissões, é pré-aprovar o
que o pipeline usa: copie o `templates/settings.example.json` do plugin para
`.claude/settings.json` na raiz deste projeto e ajuste as listas à stack.

- `permissions.allow` — os comandos que o pipeline roda o tempo todo (testes, lint,
  build, git, `gh`/`glab`, subir e derrubar serviços). Pré-aprovados, nunca perguntam.
- `permissions.deny` — o que nunca deve rodar, com ou sem agente. **Regras `deny`
  valem em todos os modos de permissão, inclusive `bypassPermissions`.**

Esse arquivo é versionado e vale para todo mundo no projeto. Com ele no lugar, o modo
de permissão padrão já basta para o pipeline rodar sem interrupção.

## Ordem de trabalho

O pipeline é encadeado: cada etapa lê a anterior em vez de reperguntar o que já
está escrito.

```
PRD ──> spec.md + plan.md + contract.md ──> planejamento versionado
                                                       │
        ┌──────────────────────────────────────────────┘
        ▼
  implementação ──> avaliação ⇄ correção ──> PR
```

O par avaliação ⇄ correção repete até o contrato ser honrado, o retry budget
acabar ou o circuit-breaker disparar. O veredito é do `evaluator`, nunca do
implementador.

**Quando o planejamento precisa estar commitado antes de executar** depende da porta
de entrada. Nenhuma skill do plugin commita na branch padrão; o planejamento chega lá
por commit ou PR/MR seu.

- **Uma feature (`/ia-package:implement-and-evaluate F03`) — nada precisa ser
  commitado antes.** O próprio orquestrador commita o trio (`spec.md`, `plan.md`,
  `contract.md`) junto com os artefatos de avaliação, e o PR sai com o contrato que
  validou a implementação. Se o PRD ou o `prd_progress.json` ainda não estiverem na
  branch padrão, a execução avisa numa linha e segue.
- **Uma wave (`/ia-package:implement-and-evaluate-tmux wave 3`) — obrigatório.** Não
  é processo, é git: `git worktree add` materializa a árvore a partir de um commit,
  então arquivo que existe só no disco do checkout principal não aparece dentro da
  worktree, e cada equipe abortaria com "trio ausente". A wave confere isso antes de
  criar a primeira worktree e para, listando o que falta. Depois do merge do PR/MR do
  planejamento, rode `git pull` na branch padrão local antes da wave.

Mesmo na execução de uma feature, commitar o `contract.md` antes vale a pena quando a
feature é de risco alto: o contrato é a especificação que o evaluator vai cobrar, e
revisá-lo antes é o último ponto barato de intervenção humana — depois dele o loop
roda sozinho, e qualquer objeção ao contrato invalida ciclos já gastos.

Em qualquer das duas portas de entrada:

- Não invente requisito que não esteja no PRD — marque como `[NEEDS INPUT]` e pergunte.
- Documentos são escritos em **português (pt-BR)**; apenas títulos de seção e labels
  estruturais ficam em inglês.

## Stack deste projeto

<!-- Substitua pelo que vale no seu caso. É isso que faz o spec-writer gerar
     um plano coerente em vez de um plano genérico. -->

- Linguagem:
- Framework web:
- Banco / ORM:
- Testes:
- Comando de teste:
- Comando de lint:

## Ambiente de avaliação

<!-- Preencha isto. O `evaluator` sobe um ambiente efêmero do zero para exercitar
     cada item do contrato, e procura estas respostas nesta ordem: (1) a seção
     Prerequisites do contrato, (2) ESTE ARQUIVO, (3) o spec.md da feature,
     (4) outros contratos, (5) os manifests do projeto, (6) defaults da stack.
     Quando nada responde, ele ABORTA e aponta para cá. Cada linha preenchida
     aqui é uma camada de adivinhação que ele não precisa fazer. -->

- Instalar dependências:
- Criar banco efêmero:
- Rodar migrations:
- Semear dados (o mecanismo de seed/factory que o projeto usa):
- Subir os serviços (**parametrizado por porta** — veja abaixo):
- Health-check de cada serviço (URL ou sinal de prontidão):
- Derrubar os serviços:
- Resetar o estado entre um item e outro:
- Onde ficam as fixtures:
- Ferramenta de automação de navegador (obrigatória para itens `UI-*` e `E2E-*`):

**Portas: declare a variável, não o número.** O evaluator e o design-review alocam
uma porta livre por serviço a cada execução e a injetam no ambiente efêmero — é o que
permite duas features rodarem em paralelo (a wave do `implement-and-evaluate-tmux`, ou
dois terminais seus) sem que uma bata no serviço da outra e produza veredito falso.
Para isso, cada serviço precisa aceitar a porta por variável de ambiente ou flag.

Liste aqui a variável de cada serviço, não um valor fixo:

| Serviço | Variável / flag que define a porta | Como o serviço é levantado |
|---|---|---|
|  |  |  |

Se algum serviço tiver porta cravada e não puder ser parametrizado, diga aqui — a
execução registra um soft-fail, usa a porta padrão e avisa que execuções paralelas
daquele serviço vão colidir.

Outras variáveis de ambiente que o ambiente efêmero precisa sobrescrever:

-

## Convenções

<!-- Só o que um recém-chegado erraria. Nada que já esteja óbvio no código. -->

-

## O que não fazer

- Não commitar documento com `[NEEDS INPUT]` ou `TBD` em aberto sem sinalizar
  as pendências na descrição do commit ou do PR.
- Não editar à mão `eval-report-*.md` nem `orchestration-*.md`: são histórico de
  auditoria. Para um veredito novo, rode o `evaluator` de novo — ele grava outro
  arquivo com timestamp.
- Não editar `contract.md`, `spec.md` ou `plan.md` para fazer uma avaliação passar.
  Se a correção exigir mudança no contrato, o trio precisa ser regerado pelo
  `spec-writer` — é revisão de escopo, não conserto.
