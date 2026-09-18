# CLAUDE.md — exemplo para projetos que usam o ia-package

Copie este arquivo para a **raiz do seu projeto** (o projeto que você vai documentar,
não este repositório do plugin) com o nome `CLAUDE.md` e ajuste os caminhos e a stack.

O plugin traz as skills e os agentes; este arquivo traz o que é específico do seu
projeto e que o plugin não tem como adivinhar: onde os documentos moram, qual a
stack, e qual convenção o time segue.

---

## Documentação deste projeto

Todo artefato do pipeline vive em `docs/`:

| Artefato | Caminho | Gerado por |
|---|---|---|
| PRD do produto | `docs/PRD.md` | `prd-writer-for-complete-project` |
| Estado das features | `docs/prd_progress.json` | `prd-writer-for-complete-project`, atualizado pelo resto do pipeline |
| PRD de uma feature | `docs/<Fxx-nome>/PRD.md` | `generate-prd-for-feature` |
| High-Level Design | `docs/HLD.md` | `generate-high-level-design` |
| Feature Design Doc | `docs/<Fxx-nome>/FDD.md` | `generate-feature-design-doc` |
| Spec + plano + contrato | `docs/<Fxx-nome>/spec.md`, `plan.md` e `contract.md` | `spec-writer` |
| Relatório de avaliação | `docs/<Fxx-nome>/eval-report-<ts>.md` | `evaluator` |
| Journal de orquestração | `docs/<Fxx-nome>/orchestration-<ts>.md` | `implement-and-evaluate` |
| ADRs | `docs/adrs/generated/` | agentes `adr-*` |
| Diagramas C4 | `docs/c4/` | `/generate-c4-from-fdd` |
| Diagramas Mermaid | `docs/mermaid/` | `/generate-mermaid-diagram-from-fdd` |
| Diretriz de código | `docs/<linguagem>-development-guidelines.md` | `generate-development-guideline` |

Pastas de feature seguem `docs/F01-nome-da-feature/`, com o ID vindo do PRD do produto.
O PRD de feature e o FDD são **um por feature** e moram nessa pasta. Quando a pasta ainda
não existe (entrevista feita antes do PRD do produto), eles caem em `docs/PRD-<nome>.md` e
`docs/FDD-<nome>.md`, na raiz de `docs/`. Nenhum dos dois sobrescreve arquivo existente
sem perguntar, e nenhum deles escreve em `docs/PRD.md` — esse é o PRD do produto inteiro.

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
imprime o comando manual do que faltou. A exceção é o `implement-and-evaluate-tmux`,
que checa o CLI antes de despachar a wave e aborta na largada.

## Ordem de trabalho

O pipeline é encadeado: cada etapa lê a anterior em vez de reperguntar o que já
está escrito.

```
PRD ──> HLD ──> FDD ──> spec.md + plan.md + contract.md ──> implementação
                                                                  │
                        ┌─────────────────────────────────────────┘
                        ▼
                  avaliação ⇄ correção ──> PR ──> ADRs ──> diagramas
```

O par avaliação ⇄ correção repete até o contrato ser honrado, o retry budget
acabar ou o circuit-breaker disparar. O veredito é do `evaluator`, nunca do
implementador.

- Não gere um FDD sem que o HLD exista; se ele não existir, diga isso antes de começar.
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
- Subir os serviços:
- Health-check de cada serviço (URL ou sinal de prontidão):
- Derrubar os serviços:
- Resetar o estado entre um item e outro:
- Onde ficam as fixtures:
- Ferramenta de automação de navegador (obrigatória para itens `UI-*` e `E2E-*`):

Portas e variáveis de ambiente que o ambiente efêmero precisa sobrescrever:

-

## Convenções

<!-- Só o que um recém-chegado erraria. Nada que já esteja óbvio no código. -->

-

## O que não fazer

- Não commitar documento com `[NEEDS INPUT]` ou `TBD` em aberto sem sinalizar
  as pendências na descrição do commit ou do PR.
- Não editar à mão os arquivos em `docs/adrs/generated/`: eles são regerados
  pelos agentes `adr-*`. Ajustes manuais vão para um novo ADR que supersede o antigo.
- Não editar à mão `eval-report-*.md` nem `orchestration-*.md`: são histórico de
  auditoria. Para um veredito novo, rode o `evaluator` de novo — ele grava outro
  arquivo com timestamp.
- Não editar `contract.md`, `spec.md` ou `plan.md` para fazer uma avaliação passar.
  Se a correção exigir mudança no contrato, o trio precisa ser regerado pelo
  `spec-writer` — é revisão de escopo, não conserto.
