---
description: |
    Gere ADRs formais em MADR a partir dos potential ADRs identificados pelo adr-analyzer (Fase 3). Usage: /adr-generate [MODULE_ID ...] [--output-dir=<path>] [--context-dir=<path>] [--language=<code>]
---

Esta é a **Fase 3** do fluxo de ADRs, a que o `adr-analyzer` anuncia ao terminar a Fase 2.
O `adr-generator` processa **exatamente um** arquivo de potential ADR por invocação — a
paralelização e a numeração sequencial são trabalho deste command.

## 1. Parse dos argumentos

- **MODULE_ID** (zero ou mais): ids de módulo como aparecem nas pastas geradas pelo analyzer (ex: `AUTH API`). Sem nenhum: processa todos os módulos.
- `--output-dir=<path>`: opcional, default `docs/adrs`. É o `{OUTPUT_DIR}` de todos os paths abaixo.
- `--context-dir=<path>`: opcional, repassado a cada agent (contexto estratégico).
- `--language=<code>`: opcional, default `pt-BR`, repassado a cada agent.

## 2. Validação — Early Return

Valide **antes** de despachar qualquer agent, para não consumir recursos à toa:

| Situação | O que fazer |
|---|---|
| `{OUTPUT_DIR}/potential-adrs/` não existe | Early Return: "Nenhum potential ADR em `{OUTPUT_DIR}/potential-adrs/`. Rode a Fase 2 do `adr-analyzer` antes." |
| MODULE_ID informado que não tem pasta em `must-document/` nem em `consider/` | Aborte citando o módulo pedido e a lista de módulos encontrados |
| A varredura resulta em zero arquivos | Early Return: nada pendente. Se `done/` tiver conteúdo, diga quantos ADRs já foram processados |

## 3. Varredura

Colete os arquivos `.md` de:

```
{OUTPUT_DIR}/potential-adrs/must-document/<MODULE>/*.md
{OUTPUT_DIR}/potential-adrs/consider/<MODULE>/*.md
```

- **Nunca** inclua `potential-adrs/done/` — é o arquivo morto do que já foi gerado.
- Com MODULE_ID informado, restrinja às pastas daqueles módulos.
- `{OUTPUT_DIR}/potential-adrs-index.md`, se existir, é lido em best-effort só para enriquecer o relatório com Categoria e Prioridade. **A varredura do filesystem é a fonte da verdade** — o index pode estar desatualizado.

**Sobras de execução interrompida:** se já existirem arquivos `ADR-XXX-*.md` em
`{OUTPUT_DIR}/generated/`, eles são ADRs válidos de uma rodada anterior que morreu antes
da numeração. Numere-os primeiro (Step 5), antes de despachar — senão a conferência de
contagem do Step 4 acusa colisão onde não houve.

Anuncie o plano no chat antes de despachar: total de arquivos, quebra por módulo e por
prioridade (`must-document/` vs `consider/`), e em quantos lotes vai rodar.

## 4. Despacho paralelo

Um agent `adr-generator` **por arquivo**, pela Agent tool com `subagent_type="adr-generator"`,
em paralelo — **no máximo 8 por lote**, lotes em sequência. É o contrato declarado em
`adr-generator`: o agent processa um arquivo, o launcher paraleliza.

Prompt de cada agent:

"Gere o ADR formal em MADR a partir do arquivo de potential ADR em [FILE_PATH].

Output dir: [OUTPUT_DIR]
Context dir: [CONTEXT_DIR ou 'nenhum']
Idioma: [LANGUAGE]

Execute o seu fluxo completo (Initialization → Process → Validate and Write → Archive) seguindo todas as suas guidelines internas.

LEMBRETES CRÍTICOS:
- Processe APENAS este arquivo. Não varra a pasta nem processe irmãos
- Grave com o placeholder `ADR-XXX` no filename e no título — a numeração sequencial é atribuída pelo command depois que todos os agents terminam
- O git history já está no potential ADR: não faça queries no git
- Zero code snippets no ADR; referências são apenas file paths
- Só mova o arquivo fonte para `potential-adrs/done/<MODULE>/` DEPOIS de confirmar a escrita do ADR

O REPORT deve incluir:
- Path do ADR gravado
- Tier (1 = `generated/<MODULE>/`, 2 = `generated/<MODULE>/needs-input/`)
- Módulo
- Quantidade de marcadores [NEEDS INPUT]
- Confirmação de que o arquivo fonte foi movido para `done/`"

Substitua os placeholders pelos valores reais. `[LANGUAGE]` é `pt-BR` quando `--language`
não foi informado.

**Ao fim de cada lote**, confira: o número de arquivos novos em `{OUTPUT_DIR}/generated/`
bate com o número de agents que relataram sucesso? Se for menor, houve sobrescrita (ver
EDGE CASES).

## 5. Numeração sequencial

O `adr-generator` grava `ADR-XXX` de propósito — agents em paralelo não conseguem combinar
números entre si. Atribuir a numeração é o passo final deste command, e é **serial**:

1. Varra `{OUTPUT_DIR}/generated/` inteiro, incluindo as subpastas `needs-input/`, e pegue o maior número já usado em `ADR-<NNN>-*.md`. Sem nenhum ADR, comece em `001`.
2. Ordene os arquivos novos por módulo (alfabético) e, dentro do módulo, por filename. A ordem precisa ser determinística, não a de chegada dos agents.
3. Para cada um, em ordem, tome o próximo número livre e:
   - renomeie `ADR-XXX-<slug>.md` → `ADR-<NNN>-<slug>.md`
   - troque a linha de título `# ADR-XXX: <Título>` → `# ADR-<NNN>: <Título>`
4. Três dígitos, com zero à esquerda (`ADR-007`), como nos exemplos do `adr-generator`.

> 🔴 **Troque o `XXX` APENAS no filename e na linha de título.** Um `ADR-XXX` em
> `**ADRs Relacionados:**`, `**Substitui:**` ou `**Substituído por:**` se refere a *outro*
> ADR — e o `adr-generator` usa `ADR-XXX` ali justamente para o caso do ADR futuro que
> ainda não existe. Renumerar esses campos inventa relacionamentos.

Se o número alvo já estiver ocupado, pule para o próximo livre. Se um arquivo novo já vier
numerado (o agent fugiu do placeholder), deixe como está e registre no relatório.

## 6. Relatório consolidado

| Módulo | Potential ADR | ADR gerado | Tier | [NEEDS INPUT] |
|---|---|---|---|---|

Mais:

- Total gerado, com a quebra por tier e a distribuição em % — o `adr-generator` espera 60-80% em Tier 1 e 20-40% em `needs-input/`. Fora dessa faixa, é observação no relatório, não erro.
- Quantos arquivos fonte foram movidos para `done/`.
- Falhas, uma linha por arquivo, com o motivo relatado pelo agent.
- Soft-fails: index desatualizado, arquivo novo já numerado, colisão de slug resolvida.

**Falha de um agent não cancela os outros.** Como o fonte só vai para `done/` depois da
escrita bem-sucedida, o que falhou continua em `must-document/` ou `consider/` — rodar
`/adr-generate` de novo retoma exatamente o que ficou para trás, sem duplicar o que passou.

## 7. Ofereça o adr-linker

Com pelo menos um ADR gerado, ofereça — **e espere o sim explícito**:

"Gerar os links bidirecionais entre os ADRs agora? O `adr-linker` reescreve os cabeçalhos
dos ADRs existentes para registrar os relacionamentos. (sim/não)"

No sim, invoque o agent `adr-linker` pela Agent tool com `subagent_type="adr-linker"`,
passando `--adrs-path={OUTPUT_DIR}/generated/` e `--output-dir={OUTPUT_DIR}/reports/`.
No não, imprima o comando para rodar depois e encerre.

## EDGE CASES

- **Dois potential ADRs com o mesmo slug no mesmo módulo** → os dois agents gravam `ADR-XXX-<mesmo-slug>.md` e o segundo sobrescreve o primeiro. É o que a conferência de contagem do Step 4 pega. Redespache o perdedor com a instrução de sufixar o slug para desambiguar, e registre em Soft-fails.
- **Mesmo slug em módulos diferentes** → sem colisão: os paths incluem `<MODULE>/`.
- **Todos os potential ADRs já em `done/`** → Early Return do Step 2, sem despachar nada.
- **`{OUTPUT_DIR}/generated/` ainda não existe** → normal na primeira rodada; a numeração começa em `001` e os agents criam a pasta.
- **Módulo com pasta vazia** → não é erro; ignore e cite no relatório.
- **Agent relata sucesso mas o arquivo não está lá** → trate como falha, e não considere o fonte processado (o hook de `SubagentStop` também sinaliza isso).

## IDIOMA

Prompts, relatório e mensagens ao usuário em português (pt-BR).

Ficam literais, em inglês, porque outras partes do fluxo os procuram como estão:
os nomes de pasta (`potential-adrs/`, `must-document/`, `consider/`, `done/`, `generated/`,
`needs-input/`, `reports/`), o prefixo `ADR-` e o placeholder `XXX`, e o marcador
`[NEEDS INPUT]`.
