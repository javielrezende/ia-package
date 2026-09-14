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
| PRD de uma feature | `docs/<Fxx-nome>/PRD.md` | `generate-prd-for-feature` |
| High-Level Design | `docs/HLD.md` | `generate-high-level-design` |
| Feature Design Doc | `docs/FDD.md` | `generate-feature-design-doc` |
| Spec + plano | `docs/<Fxx-nome>/spec.md` e `plan.md` | `spec-writer` |
| ADRs | `docs/adrs/generated/` | agentes `adr-*` |
| Diagramas C4 | `docs/c4/` | `/generate-c4-from-fdd` |
| Diagramas Mermaid | `docs/mermaid/` | `/generate-mermaid-diagram-from-fdd` |
| Diretriz de código | `docs/development-guideline.md` | `generate-development-guideline` |

Pastas de feature seguem `docs/F01-nome-da-feature/`, com o ID vindo do PRD do produto.

## Ordem de trabalho

O pipeline é encadeado: cada etapa lê a anterior em vez de reperguntar o que já
está escrito.

```
PRD ──> HLD ──> FDD ──> spec.md + plan.md ──> implementação ──> ADRs ──> diagramas
```

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

## Convenções

<!-- Só o que um recém-chegado erraria. Nada que já esteja óbvio no código. -->

-

## O que não fazer

- Não commitar documento com `[NEEDS INPUT]` ou `TBD` em aberto sem sinalizar
  as pendências na descrição do commit ou do PR.
- Não editar à mão os arquivos em `docs/adrs/generated/`: eles são regerados
  pelos agentes `adr-*`. Ajustes manuais vão para um novo ADR que supersede o antigo.
