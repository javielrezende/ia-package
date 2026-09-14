---
name: spec-writer
description: Gera spec de implementação técnica e plan para uma ou mais features com base no PRD, análise da codebase e esclarecimento iterativo. Suporta batch mode para gerar múltiplas features da mesma wave em parallel.
---

# Feature Specs Writer

Gere especificações técnicas *implementation-ready* com base no *PRD* do projeto e nos *patterns* existentes da *codebase*. A *skill* possui dois modos:

- **Single-feature mode (default):** opera em uma *feature* por vez, identificada pelo seu ID de *feature* no *PRD* (F01, F02...), com uma entrevista interativa (Passos 1–6 abaixo).
- **Batch mode:** opera em múltiplas *features* da mesma *wave* em *parallel*, aplicando *auto-accept* em todas as recomendações da entrevista. Ativado automaticamente quando o *input* contém múltiplos IDs, uma referência de *wave* ou uma mistura. Veja a seção **Batch Mode** perto do final deste arquivo.

**Output:** DOIS arquivos são necessários:
1. `spec.md` - Technical specification (9 seções)
2. `plan.md` - Implementation plan (*phases* e *steps*)

**Output location:** `docs/<feature-id>-<kebab-name>/spec.md` e `docs/<feature-id>-<kebab-name>/plan.md`
- O `<kebab-name>` é derivado do nome da *feature* na Seção 6 do *PRD* (letras minúsculas, espaços → hifens, caracteres especiais removidos). Exemplo: `F03. Video Upload` → `docs/F03-video-upload/`.

---

## Execution Steps (6 Passos)

Nota: Estes são *steps* internos de execução do agente. O documento de *plan* de OUTPUT terá o número de *phases* definido pela tabela de escalonamento em `references/feature-template.md`, com base na complexidade da *feature*.

### Step 1: Resolver Input e Pre-Analysis

**1.1: Identificar o PRD e a target feature**

Aceite *free-form input* do usuário. O usuário pode referenciar a *feature* por ID (`F03`), por nome (`Video Upload`), por *path* (`docs/PRD.md F03`), ou qualquer combinação. Resolva a referência:

- Localize o arquivo *PRD* a partir da referência do usuário ou procure por `docs/PRD.md`, `PRD.md` ou locais convencionais similares. Se existirem múltiplos *PRDs* plausíveis, pergunte ao usuário qual deles utilizar.
- Identifique a *target feature* dentro do *PRD* por ID ou nome.
- Se o *input* for ambíguo (ex: "upload" corresponde a múltiplas *features*), confirme com o usuário antes de prosseguir.
- Se a *feature* referenciada não existir no *PRD*, liste as *features* disponíveis da tabela de dependências (`Appendix A: Implementation Planning` → `Dependency Graph`; em PRDs antigos, Seção 8) e peça ao usuário para esclarecer.

**PRD é obrigatório.** Se nenhum *PRD* for encontrado no projeto, pare e instrua o usuário a gerar um primeiro com a *skill* `prd-writer`. Não faça *fallback* para uma entrevista não estruturada.

**1.2: Checar dependency readiness e Foundation features (greenfield)**

Leia a tabela `Dependency Graph` do *PRD* (em `Appendix A: Implementation Planning`; em PRDs antigos, Seção 8). Para cada *feature* na coluna `Dependencies` da *target feature*, verifique se ela parece estar implementada na *codebase* (se existem arquivos fonte correspondentes ao *scope* da *feature*). Se alguma dependência ainda não estiver implementada, avise o usuário: "F<X> depends on F<Y> (not yet implemented). Continue anyway?". Prossiga apenas se confirmado.

Se o *PRD* contiver uma subseção **Foundation Features** (em `Appendix A`; em PRDs antigos, Seção 8), aplique estas verificações adicionais baseadas no estado de implementação de cada *Foundation feature*:

- **Foundation state detection (o sinal greenfield correto):** para cada *feature* listada em Foundation Features, verifique se ela parece implementada na *codebase* procurando por um ou mais arquivos de *output* característicos que a *feature* deveria criar — por exemplo, um *schema* de *ORM* ou arquivo de *migration* para um *Foundation* de banco de dados, um módulo de *session/middleware* para um *Foundation* de *auth*, um arquivo de *root layout/template* para um *Foundation* de *layout*, ou qualquer artefato equivalente na *stack* sendo usada (framework web, serviço de backend, app mobile, etc.). NÃO dependa da mera presença de marcadores genéricos de projeto como uma pasta fonte ou um arquivo de *package/manifest* — qualquer ferramenta de *scaffolding* (`create-next-app`, `rails new`, `django-admin startproject`, etc.) já cria isso, mas as *Foundation features* do *PRD* ainda podem estar não implementadas.
  - **Greenfield** = zero *Foundation features* implementadas até o momento.
  - **Partial Foundation** = algumas *Foundation features* estão implementadas, outras ainda estão pendentes.
  - **Foundation complete** = todas as *Foundation features* estão implementadas.
- **Scenario 1 — greenfield + target feature É uma Foundation feature:** prossiga sem aviso extra. Este é o caminho esperado para um projeto *greenfield*.
- **Scenario 2 — greenfield + target feature NÃO está em Foundation Features:** avise o usuário: "This appears to be a greenfield project (no Foundation feature is implemented yet). F<target> is not a Foundation feature. Foundation features (F<ID>, ...) set up the shared infrastructure and should be implemented first. Recommend starting with F<first-foundation>. Continue with F<target> anyway?". Prossiga apenas se confirmado.
- **Scenario 3 — Partial Foundation (algumas Foundation features implementadas, outras pendentes) e a target não é um dos Foundations restantes:** liste as *Foundation features* pendentes e avise: "Foundation features F<ID1>, F<ID2>... are not yet implemented. Implementing F<target> before these may create file conflicts in the scaffolding. Continue anyway?". Prossiga apenas se confirmado.
- **Foundation complete (codebase madura para fins de Foundation):** pule todas as verificações específicas de *Foundation*. O *dependency readiness check* normal acima é suficiente.

**Nota sobre Batch Mode:** Em *Batch Mode*, o *orchestrator* executa essas verificações de dependência e *Foundation* uma vez em todo o *batch* (B.2 e B.3) e filtra as *features* antes do *dispatch*. Os *sub-agents* ignoram todo *prompt* de "avise o usuário / Continue anyway?" neste passo — assuma que a verificação já foi resolvida pelo *orchestrator* e prossiga.

**1.3: Codebase Pattern Discovery (duas layers)**

Explore a *codebase* antes de escrever a *spec* (antes da entrevista no *single-feature mode*; antes de aplicar a *Auto-Accept Policy* no *Batch Mode*) para extrair *patterns*. Isso é obrigatório sempre que a *codebase* não for vazia — não espere o usuário fornecer os *paths*.

**Layer 1 — Baseline (piso, não teto):** no mínimo, extraia *patterns* observáveis nestas categorias. Os exemplos são ilustrativos em múltiplas *stacks* — as categorias são a intenção *stack-agnostic*.
- *Runtime* e linguagem (qualquer — Node, Python, Ruby, Go, Java, .NET, Rust, PHP, etc.)
- *Framework* e *project layout* (qualquer — Next.js/Remix, Django/Flask/FastAPI, Rails, Spring, Phoenix, etc.)
- Banco de dados e *data access* (qualquer — Postgres/MySQL/Mongo/SQLite; Prisma/SQLAlchemy/ActiveRecord/GORM/Entity Framework; *raw SQL*)
- Estratégia e biblioteca de *Authentication*
- Estilo da API ou *entry-point* (REST, GraphQL, RPC, CLI, job queue, event handler — o que o projeto usar) e formato de *response/error*
- Abordagem de *Validation* (*typed schemas*, *runtime validators*, checagens manuais — o que a *codebase* preferir)
- *Testing framework* e estilo (*unit* e *integration*)
- *Error handling* (*exceptions*, *Result types*, códigos de erro, panic/recover, etc.)
- *Folder structure* e *naming conventions*

**Layer 2 — Broad exploration (também obrigatório):** além do *baseline*, capture qualquer *pattern* adicional que você observar e que possa informar a implementação — decisões de arquitetura, idiomas da *codebase*, abstrações recorrentes, *logging/observability*, *config management*, convenções de *deploy*, internacionalização, acessibilidade, qualquer coisa. Não se restrinja à lista de *baseline*. Um relatório minucioso em um projeto médio tipicamente tem 8-15 *patterns*.

**1.4: Tratamento de Empty codebase**

Se a *codebase* estiver vazia ou tiver apenas *scaffolding* (ex: apenas `package.json` com padrões, sem implementação em `src/` ainda), pule a descoberta das *Layers* 1/2 e, em vez disso, planeje fazer perguntas transversais da *stack inline* durante o Step 2 (essas perguntas serão feitas apenas uma vez — na primeira *feature*. *Features* subsequentes encontrarão as respostas na *codebase*).

**Nota sobre Batch Mode:** Em *Batch Mode* não há entrevista do Step 2. Aplique a linha "Empty codebase bootstrap" da *Auto-Accept Policy*: faça *fallback* para *industry best practices* da *stack* detectada (ou para o *scaffolding* que existir, se houver), e documente cada escolha de *bootstrap* explicitamente na seção de Assumptions/Decisions da *spec*.

**1.5: Ler os dados da feature do PRD**

Extraia a definição completa da *target feature* do *PRD* e carregue-a como contexto para a *spec* (usado pela entrevista no *single-feature mode*, e pela *Auto-Accept Policy* no *Batch Mode*):
- Nome e ID da *feature*
- Bloco `Consumes` (se presente — em `Appendix A` → `Feature Data Contracts`; em PRDs antigos, dentro da Seção 6)
- Bloco `Provides` (mesma localização)
- Bloco `Core Scope` (se presente)
- Bloco `Full Scope additions` (se presente)
- `Capabilities`
- `Experience`
- `Error Handling` (se presente)
- Critérios de aceite (*acceptance criteria*) por *feature* da seção `Acceptance Criteria` (Seção 11; Seção 9 em PRDs antigos)
- Critérios de *Cross-Feature Integration* da mesma seção que referenciam esta *feature* (seja como *consumer* ou *provider*)
- `Non-Functional Requirements` (Seção 7) cujos `RNF` afetam esta *feature* — desempenho percebido, disponibilidade, capacidade, segurança/privacidade, conformidade, acessibilidade, auditabilidade. **São a principal entrada de negócio para as decisões técnicas da spec.**
- `Key Decisions and Trade-offs` (Seção 8) e `Open Questions` que restringem esta *feature*
- `Dependencies` (Seção 9) que esta *feature* precisa consumir
- `Risks and Mitigation` (Seção 10) cuja mitigação recai sobre esta *feature*
- `Validation and Test Strategy` (Seção 12) — critérios de saída e forma de validação aplicáveis a esta *feature*

Se o *PRD* for do formato antigo de 9 seções, estes itens simplesmente não existem: siga sem eles e registre a lacuna nas *assumptions* da spec.

**1.6: Apresentar entendimento ao usuário**

```
Com base na minha análise, entendo que você deseja implementar:

**Feature:** F<ID>. <Name>
**Technical Summary:** [1-2 frases derivadas das Capabilities + Experience do PRD]
**Observed codebase patterns:** [resumo das descobertas da Layer 1 + Layer 2, ou "empty codebase — will bootstrap"]
**PRD context loaded:** Consumes, Provides, Core Scope, Full Scope, Capabilities, Experience, Error Handling, acceptance criteria, NFRs, decisões de produto, dependências, riscos, estratégia de validação

Preciso esclarecer algumas decisões técnicas que o PRD e a codebase ainda não respondem.
```

**Nota sobre Batch Mode:** Os *sub-agents* ignoram este passo — não há usuário interativo para quem apresentar. O *plan* consolidado do *orchestrator* (B.4) cobre o entendimento compartilhado para o *batch*.

### Step 2: Interview (Entrevista)

**Batch Mode override:** Em *Batch Mode*, este passo inteiro é substituído pela *Auto-Accept Policy* (veja a seção Batch Mode). Os *sub-agents* pulam o Step 2 e prosseguem diretamente para o Step 3 com os padrões do *Auto-Accept* aplicados. Toda instrução de "ask the user" abaixo se torna "apply the Auto-Accept default and document the choice in the spec's assumptions".

Entreviste o usuário incansavelmente sobre cada aspecto deste plano até chegarmos a um entendimento compartilhado. Percorra cada ramo da árvore de design, resolvendo as dependências entre decisões uma a uma. Para cada pergunta, forneça sua resposta recomendada.

Faça as perguntas uma de cada vez.

Se uma pergunta puder ser respondida explorando a *codebase* ou lendo o *PRD*, explore ou leia em vez de perguntar.

**Pergunta de Scope (faça primeiro, quando aplicável):** Se a *feature* tem ambos os blocos `Core Scope` e `Full Scope additions` no *PRD*, pergunte: "Should the spec cover Core Scope only, or Core + Full Scope additions?". Se apenas um dos blocos estiver presente, ou nenhum estiver presente, pule esta pergunta e assuma o *scope* completo da *feature*.

**Anti-redundancy rule:** NÃO pergunte sobre nada que já seja observável em:
- Definição da *feature* no *PRD* (Consumes, Provides, Core Scope, Capabilities, Experience, Error Handling)
- Critérios de aceite (*acceptance criteria*) do *PRD* para esta *feature*
- Os *codebase patterns* descobertos no Step 1.3
- Um `spec.md` ou `plan.md` gerado anteriormente para outra *feature* no mesmo projeto (quando existirem e forem relevantes)

Concentre a entrevista em decisões que o *PRD* e a *codebase* **não** respondem ainda: arquitetura interna, detalhes do *schema* de banco de dados (colunas, índices, *constraints*), assinaturas de *endpoints*, regras de validação não especificadas em Capabilities, nomenclatura de novos arquivos, escolha entre bibliotecas quando não houver *patterns* estabelecidos, *edge cases* não cobertos pelo *Error Handling*.

**Partial PRD specifications:** Quando o *PRD* menciona uma *capability* mas omite um detalhe específico (ex: "chunked upload" sem definir o tamanho do chunk), peça o detalhe ausente em vez de assumir um padrão.

**Empty codebase bootstrap:** Se o Step 1.4 sinalizou uma *empty codebase*, faça perguntas transversais da *stack inline* durante este passo (*framework*, *ORM*, *auth*, estilo de API, *validation*, *testing*, *error handling*, *folder structure*). Assim que a primeira *feature* for implementada, a *codebase* se torna a referência para as *features* subsequentes.

### Step 3: Summary e Assumptions

Após receber as respostas:
- Resuma as decisões técnicas tomadas
- Liste as premissas (*assumptions*) derivadas do *PRD*, dos *codebase patterns* e das respostas da entrevista
- Note explicitamente quais blocos do *PRD* informaram quais partes da *spec* (*traceability*)
- **Classifique a complexidade da *feature*** (`trivial` | `simple` | `medium` | `complex`) usando os critérios da tabela "Níveis de Complexidade" em `references/feature-template.md`. Esse valor é o COMPLEXITY_LEVEL usado no Step 4 e reportado no Step 6.

**Nota sobre Batch Mode:** Em *Batch Mode* não há respostas de entrevista. Trate cada padrão da *Auto-Accept Policy* que foi aplicado como se fosse uma resposta de entrevista — liste sob *assumptions*, nomeie a linha da política que o gerou e sinalize para que o usuário possa revisar e fazer *override* posteriormente. A *traceability* dos blocos do *PRD* funciona da mesma forma que no *single-feature mode*.

### Step 4: Gerar Documentos

**Announce:** "Generating TWO documents: SPEC and PLAN..."

**Diretrizes de escala por complexidade:** a fonte da verdade são as tabelas "Escalonamento de profundidade por complexidade" e "Escalonamento do documento PLAN" em `references/feature-template.md`. Consulte-as antes de gerar; não duplique esses números aqui.

**Use o template `references/feature-template.md` para AMBOS os documentos** — ele define as 9 seções da *spec*, o formato do *plan* e os níveis de complexidade.

Nota: A profundidade do documento SPEC (*schemas*, índices, *migrations*) escala com a complexidade. Os *steps* do documento PLAN são sempre de alto nível, independentemente da complexidade.

**4.1: Generate SPEC**:
- Escale as seções com base no COMPLEXITY_LEVEL, conforme a tabela de escalonamento do template:
  - trivial: Ignore *API Contracts* e *Data Model*
  - simple: Inclua *API Contracts* e *Data Model* em forma reduzida; omita apenas se a *feature* genuinamente não tiver *endpoints* ou *schema*, e registre a omissão em Assumptions
  - medium/complex: Todas as 9 seções requeridas
- Escale a profundidade dentro das seções com base na complexidade
- Inclua exemplos JSON, *SQL migrations*, especificações de testes
- **Se FEATURE_CROSS_CUTTING existir:** Inclua *cross-cutting concerns* integradas na Spec §1 → *Scope* → "Included":
  ```
  **Included:**
  - Core feature functionality
  - Integrated from cross-cutting concerns:
  ```

**PRD → SPEC mapping (aplique de forma consistente em todas as specs):**

| Bloco do PRD | Destino na Spec.md |
|-----------|---------------------|
| Consumes | Spec §1 → *Scope* (*input contracts*) + Spec §6 *API Contracts* (quando o input chega via API) |
| Provides | Spec §1 → *Scope* (*output contracts*) + Spec §6 *API Contracts* (quando o output é exposto via API) |
| Core Scope | Spec §1 → *Scope* → "Included" |
| Full Scope additions | Spec §1 → *Scope* → "Deferred" (quando o usuário escolheu só Core) ou "Included" (quando o usuário escolheu Core + Full) |
| Capabilities | Spec §2 *Requirements* → *Business Rules* |
| Experience | Spec §2 *Requirements* → *UX Flows* |
| Error Handling | Spec §8 *Error Handling* |
| PRD Seção 7: `Non-Functional Requirements` | Spec §2 *Requirements* → *NFRs* + decisões técnicas que os atendem (§3/§5) |
| PRD Seção 8: `Key Decisions and Trade-offs` | Spec §4 *Assumptions/Constraints* — restrições de produto que a solução técnica não pode violar |
| PRD Seção 9: `Dependencies` | Spec §6 *API Contracts* / integrações externas |
| PRD Seção 10: `Risks and Mitigation` | Spec §4 *Assumptions/Constraints* + §8 *Error Handling* quando a mitigação é comportamento do sistema |
| PRD Seção 12: `Validation and Test Strategy` | Spec §9 *Testing Strategy* → critérios de saída e cenários de validação |
| PRD `Acceptance Criteria`: critérios por feature | Spec §9 *Testing Strategy* → *acceptance tests* |
| PRD `Acceptance Criteria`: critérios de Cross-Feature Integration (referenciando esta feature) | Spec §9 *Testing Strategy* → *integration tests* |

**4.2: Generate PLAN**:
- Seção de *Prerequisites*
- *Phases* com *steps* numerados (1-3 frases cada, alto nível)
- Descreva o QUE fazer, faça referência à *spec* para o COMO fazer

Siga o formato de *Phases e Steps* e as *Guidelines de Conteúdo* de `references/feature-template.md`.

**Announce:** "Both documents ready. Proceeding to save..."

### Step 5: Validate e Save

**Valide antes de salvar:**

Documento SPEC:
- [ ] Seções obrigatórias presentes (todas as 9 para medium/complex; forma reduzida para simple; pule API Contracts/Data Model para trivial ou quando genuinamente N/A)
- [ ] Spec §2 *Requirements* presente sempre que o *PRD* tiver Capabilities (e UX Flows sempre que tiver Experience)
- [ ] Spec §8 *Error Handling* presente sempre que o *PRD* tiver o bloco Error Handling ou a entrevista tiver resolvido *edge cases*
- [ ] Spec §4 *Assumptions* registra toda decisão sem resposta no *PRD*, com a origem (obrigatória em Batch Mode)
- [ ] Visão geral dos componentes possui os *file paths* completos
- [ ] *API Contracts* têm exemplos JSON (se inclusos)
- [ ] *Data model* tem tipos de colunas, índices, *constraints* (se inclusos)
- [ ] *Testing strategy* tem funções de testes específicas
- [ ] Blocos do *PRD* mapeados corretamente conforme a tabela PRD → SPEC
- [ ] *Consumes/Provides* do *PRD* estão refletidos no *Scope* ou *API Contracts*
- [ ] Todo `RNF` Must have do *PRD* que afeta esta *feature* tem uma decisão técnica correspondente na *spec* que o atende
- [ ] Critérios de *Cross-Feature Integration* do *PRD* que referenciam esta *feature* aparecem como *integration tests*

Documento PLAN:
- [ ] *Steps* numerados ao longo das *phases*
- [ ] Formato: **N. Component** - Parágrafo de alto nível (1-3 frases)
- [ ] *Steps* descrevem O QUE, não COMO (a *spec* possui os detalhes)

**Salve ambos os arquivos em `docs/<feature-id>-<kebab-name>/spec.md` e `docs/<feature-id>-<kebab-name>/plan.md`.** Crie a pasta se não existir. Verifique ambos os arquivos com a *tool* de Read.

### Step 6: Output Result

Informe o *path* dos arquivos de *spec* e *plan*, o nível de complexidade da *feature*, e quantas *phases* há no *plan*.

---

## Batch Mode

Gere *specs* para múltiplas *features* da mesma *wave* em *parallel*, aplicando *auto-accept* em todas as recomendações de entrevista. Este modo é um mero *wrapper* de orquestração sobre os Steps 1–6: os *sub-agents* executam o fluxo de *single-feature* completo; o *orchestrator* apenas resolve o *input*, valida, faz o *dispatch* e relata.

### Ativação

A *skill* entra no modo *Batch Mode* automaticamente quando o *input* corresponde a qualquer um destes padrões:
- Múltiplos IDs de *features*: `F01 F02 F03`
- Referência de *wave*: `wave 3`
- Mistura dentro da mesma *wave*: `wave 3 F04`
- Múltiplos nomes de *features*, ou nomes misturados com IDs, contanto que todos resolvam para a mesma *wave*

Um *input* de *single-feature* (ex: `F03`, `Video Upload`) continua a usar o fluxo interativo (Steps 1–6).

### Regra de Same-wave

Todas as *features* em um único *batch* devem pertencer à mesma *wave* (conforme `Execution Waves` no `Appendix A` do PRD).

- *Input* de múltiplas ondas (*cross-wave*, ex: `wave 3 wave 4`, ou `F04 F05` onde F04 é *wave 3* e F05 é *wave 4*) é rejeitado. Mensagem: "Features from different waves cannot be generated in the same batch. Later-wave specs are richer when generated after earlier waves are implemented, so the codebase has more patterns to observe. Run wave N first."
- Misturar `wave N` com nomes/IDs extras de *features* é permitido apenas se todas as *features* listadas pertencerem à wave N. Qualquer exceção aciona a mesma rejeição.
- Número de *wave* desconhecido → rejeite, listando as *waves* disponíveis em `Execution Waves` (`Appendix A` do PRD).
- ID/nome da *feature* desconhecido → rejeite, listando as *features* disponíveis.

### Fluxo de Orchestration

O Step 1 (Resolver Input e Pre-Analysis) é adaptado para o contexto de *batch* conforme descrito abaixo. Os Steps 2–6 NÃO são executados pelo *orchestrator* — eles rodam dentro de cada *sub-agent*, um por *feature*, de acordo com a *Auto-Accept Policy*.

**B.1: Resolver o batch**

- **Localize o PRD** usando as regras do Step 1.1 (*path* fornecido pelo usuário, `docs/PRD.md`, `PRD.md`, ou similares). Se nenhum *PRD* for encontrado, pare e direcione o usuário ao `prd-writer`. Se existirem múltiplos *PRDs* plausíveis, pergunte ao usuário qual utilizar ANTES de continuar — esta é a primeira pausa interativa possível no *orchestrator*.
- Faça o *parsing* do *input* em uma lista de *target features* (expanda *waves*, faça *merge* de listas, remova duplicatas).
- Se o *PRD* não tiver subseção `Execution Waves` (`Appendix A`, ou Seção 8 em PRDs antigos) e o *input* referenciar uma *wave* (ex: `wave 3`), rejeite com: "Wave references require an 'Execution Waves' subsection in the PRD, which this PRD does not have. Use feature IDs directly or update the PRD." Não tente sintetizar *waves*.
- Se o nome de alguma *feature* no *input* for ambíguo (corresponde a múltiplas *features* no *PRD*, ex: "upload" corresponde a F03 e F11), liste as candidatas para o usuário e peça a desambiguação ANTES de prosseguir para o restante de B.1. Esta é a segunda pausa interativa possível antes do plano consolidado.
- Se qualquer ID ou nome de *feature* não existir no *PRD*, rejeite com a lista das *features* disponíveis.
- Valide a regra de *same-wave*.
- Para cada *target*, verifique se `docs/<feature-id>-<kebab-name>/spec.md` já existe. Marque essas *features* como "already has spec".

**B.2: Classificação de Greenfield e Foundation**

Aplique o *Foundation state detection* do Step 1.2 uma vez para todo o *batch*. Classifique cada *target feature* como:
- **Foundation, not implemented** → deve rodar de forma sequencial (o *scaffolding* compartilhado impede o paralelismo).
- **Non-Foundation, ou Foundation já implementado** → elegível para o *pool* em paralelo.

**B.3: Dependency readiness**

Para cada *target feature*, verifique suas dependências do *PRD* (`Dependency Graph` no `Appendix A`). Se uma dependência não estiver implementada E não estiver ela própria no *batch* atual, marque a *feature* como "dependency missing — will abort". Dependências satisfeitas por outras *features* no mesmo *batch* são aceitáveis (elas terão suas *specs* geradas juntas; a ordem de implementação é decisão do usuário).

**B.4: Apresentar o plan consolidado e aguardar confirmação**

Mostre o *plan* e aguarde a confirmação explícita. *Template default*:

```
Batch plan for <input>:
- F04 Video Library (Core only) — new
- F07 Background Processing Pipeline (full scope) — already has spec (skip / regenerate?)
- F12 Administration Panel (full scope — no Core/Full split) — new

Mode: parallel (N sub-agents)   # ou "sequential (Foundation detected)" quando aplicável
Codebase state: Foundation complete   # ou greenfield / Partial Foundation
Auto-accept: all spec-writer recommendations will be applied
Destination: docs/F04-video-library/, docs/F07-background-processing-pipeline/, docs/F12-administration-panel/

OK to proceed? (yes/no)
```

*Tag* de *scope* por *feature* (escolha a certa por formato de *PRD*):
- `(Core only)` — o *PRD* da *feature* possui ambos os blocos `Core Scope` e `Full Scope additions` (O *Auto-Accept* escolhe Core).
- `(full scope)` — o *PRD* da *feature* possui apenas um dos blocos de *scope*, então Core e Full são o mesmo.
- `(full scope — no Core/Full split)` — o *PRD* da *feature* não possui nenhum dos blocos; a *feature* inteira está no *scope*.

*Tags* de status por *feature*: `new`, `already has spec (skip / regenerate?)`, `dependency missing — will abort`, `Foundation, will run sequentially`, `already implemented (Foundation), skipping`.

Prossiga apenas com um "yes" explícito. Diante de um "no" ou qualquer resposta negativa/ambígua, aborte o processo de forma limpa, sem fazer *dispatch* dos *sub-agents* e sem criar nenhum arquivo. Se o usuário quiser alterar o *plan*, ele re-invoca a *skill* com o *input* atualizado. As *features* marcadas como "already has spec" são ignoradas por padrão; o usuário pode solicitar a regeneração na resposta de confirmação (ex: "yes, regenerate F07").

**B.5: Dispatch dos sub-agents**

- **Fase sequencial (somente Foundations, quando greenfield ou Partial Foundation):** faça o *dispatch* dos *sub-agents* de *Foundation* um por vez, aguardando que cada um complete antes de iniciar o próximo, na ordem em que aparecem em `Foundation Features` (`Appendix A` do PRD).
- **Fase paralela:** faça o *dispatch* de todos os *sub-agents* restantes em uma única mensagem com múltiplas chamadas da *tool* Agent, sem limite de concorrência.
- O *prompt* de cada *sub-agent* inclui:
  - O ID da *target feature* e o *path* do *PRD*
  - Instrução para executar os Steps 1–6 deste SKILL.md para aquela *feature*
  - A *Auto-Accept Policy* abaixo, substituindo a entrevista interativa (Step 2)
  - Lembrete para salvar `spec.md` e `plan.md` conforme o Step 5

Cada *sub-agent* realiza seu próprio *Pattern Discovery* (Step 1.3) de forma independente — sem compartilhamento entre *sub-agents*.

**B.6: Coletar e relatar**

Aguarde todos os *sub-agents*. Relate o resultado consolidado:

```
Batch complete: 3/4 features generated successfully
✓ F04 → docs/F04-video-library/
✓ F07 → docs/F07-background-processing-pipeline/
✓ F12 → docs/F12-administration-panel/
✗ F05 → failed: <reason>
```

Falhas de *sub-agents* são isoladas — outros *sub-agents* continuam. *Features* que falharam podem ser rodadas novamente de forma individual.

### Auto-Accept Policy

Cada *sub-agent* pula a entrevista interativa (Step 2) e aplica esses padrões para as decisões que a entrevista teria trazido à tona:

| Decision | Default |
|---|---|
| Scope (Core vs Core+Full, quando ambos existem) | Core only |
| Decisões técnicas com clara recomendação do spec-writer | Aplique a recomendação |
| Dependência ainda não implementada (aviso do Step 1.2) | O *orchestrator* lida em B.3 — o *sub-agent* nunca recebe uma *feature* com dependência externa não atendida; pule o aviso do Step 1.2 inteiramente |
| Avisos de Greenfield Foundation (Step 1.2 Cenários 2/3) | O *orchestrator* lida em B.2 — o *sub-agent* pula esses cenários |
| A feature requer nova tecnologia não presente na codebase | Faça *auto-confirm*; documente a nova dependência nas decisões/*assumptions* da *spec* |
| Múltiplos patterns conflitantes na codebase | Escolha o mais frequente (ou o mais recente em caso de empate); documente a escolha |
| Referência de feature ambígua | Não pode ocorrer — o *orchestrator* pede ao usuário para desambiguar em B.1 antes do *dispatch* |
| Tratamento de Empty codebase bootstrap (Step 1.4) | Faça *fallback* para *industry best practices* da *stack* detectada; documente *assumptions* explicitamente |
| Especificações parciais do PRD (Step 2 — capability mencionada, mas detalhe técnico omitido) | Aplique um *default industry-standard* para o detalhe faltante; documente isso como uma premissa (*assumption*) explícita na *spec*. NÃO bloqueie. |
| Descrição muito vaga (definição da feature deixa muitas decisões abertas) | Aplique padrões de *best-practices* para cada decisão em aberto e documente como premissas (*assumptions*) explícitas na *spec*; nunca deduza silenciosamente |
| Nenhum codebase pattern encontrado (codebase não vazia, mas Pattern Discovery não retornou nada) | Faça *fallback* para *industry best practices* da *stack* detectada; documente como uma *assumption* explícita |

Todas as outras regras do spec-writer (conteúdo *PRD-driven*, aderência aos *codebase patterns*, validação SPEC/PLAN, nomenclatura *kebab-case*, *file structure*) se aplicam sem alterações.

**Requisito de documentação:** toda vez que um *sub-agent* aplica um *default* da *Auto-Accept* para uma decisão que o *PRD* não respondeu, ele DEVE registrar essa decisão na tabela *Assumptions* da Spec §4 (`Technical Decisions & Assumptions`), nomeando na coluna Origem a linha da policy que a produziu, para que o usuário possa revisar e corrigir depois.

---

## Regras

**Precedência:** Quando uma *feature* está rodando em *Batch Mode*, os grupos de regras de (Batch Mode) abaixo se sobrepõem a qualquer regra conflitante nas listas gerais Always/Never — notavelmente, o *Batch Mode* sobrepõe as regras relacionadas à entrevista ("Preserve the iterative interview style", "Skip interview questions...", etc.). Todas as regras não conflitantes continuam válidas.

**Sempre:**
- Gere DOIS arquivos (*spec* e *plan*) em `docs/<feature-id>-<kebab-name>/`
- Valide ambos os documentos antes de salvar
- Rode o *Codebase Pattern Discovery* em duas camadas (*baseline* + *broad*) antes da entrevista
- Leia a *target feature* do *PRD* e use Consumes/Provides/Core Scope/Full Scope/Capabilities/Experience/Error Handling/acceptance criteria como contexto primário, mais os `RNF` aplicáveis (Seção 7), as decisões de produto (Seção 8), as dependências (Seção 9) e os critérios de validação (Seção 12) quando o PRD os tiver
- O PRD é intencionalmente livre de decisões técnicas. Toda escolha de stack, arquitetura, modelagem e integração nasce aqui na spec (ou no HLD, se existir) — nunca assuma que o PRD já decidiu
- Pule perguntas da entrevista cujas respostas já estejam no *PRD*, na *codebase*, ou em *specs* anteriores
- Aplique o *mapping* PRD → SPEC consistentemente em todas as *features*
- Preserve o estilo iterativo da entrevista: uma pergunta por vez, percorra a árvore de decisões, forneça uma resposta recomendada

**Nunca:**
- Coloque código real na *spec* (descreva apenas a estrutura)
- Coloque decisões de arquitetura no *plan*
- Inclua estimativas de tempo
- Crie fases de *testing* no documento de *plan*
- Inclua *metadata* de Feature ID/Data/Versão
- Inclua detalhes de implementação nos *steps* do *plan* (tipos de dados, colunas, métodos)
- Prossiga sem um *PRD* — sempre exija um e direcione o usuário para o `prd-writer` caso ausente
- Faça novamente perguntas cujas respostas sejam observáveis na *codebase* ou já declaradas no *PRD*
- Restrinja a exploração da *codebase* ao *checklist* de *baseline* — o *baseline* é um piso, não um teto

**Sempre (Batch Mode):**
- Valide a regra de *same-wave* antes do *dispatch*; rejeite *batches* *cross-wave*
- Apresente um *plan* consolidado e aguarde confirmação explícita antes de fazer o *dispatch* dos *sub-agents*
- Pule *features* cujos arquivos `spec.md` já existam, a menos que o usuário solicite explicitamente a regeneração
- Rode as *Foundation features* sequencialmente quando a *codebase* for *greenfield* ou *Partial Foundation*
- Aplique a *Auto-Accept Policy* dentro de cada *sub-agent* em vez de conduzir a entrevista interativa

**Nunca (Batch Mode):**
- Misture *features* de diferentes *waves* no mesmo *batch*
- Faça o *dispatch* de *Foundation features* em paralelo quando qualquer *Foundation* ainda não estiver implementada
- Cancele *sub-agents* em execução porque outro *sub-agent* falhou
- Compartilhe um único *Pattern Discovery* entre os *sub-agents* — cada um roda o seu próprio

---

## Edge Cases

**Precedência de Batch Mode:** Em *Batch Mode*, qualquer *edge case* abaixo que instrua o *sub-agent* a "perguntar ao usuário", "confirmar com o usuário", ou "aprofundar a entrevista" é substituído pela linha correspondente da *Auto-Accept Policy* (seção Batch Mode). Os *sub-agents* nunca pausam para perguntar; os *edge cases* em nível de *orchestrator* ("Multiple PRD files", "Ambiguous feature reference", avisos de dependência) são resolvidos de uma só vez em B.1–B.3 antes do *dispatch*.

**Nenhum PRD encontrado:** Pare e instrua o usuário a gerar um primeiro com o `prd-writer`. Não rode a *skill* sem um *PRD*.

**Feature não encontrada no PRD:** Liste as *features* disponíveis na tabela `Dependency Graph` (`Appendix A` do PRD) e pergunte ao usuário qual era a intencionada.

**Referência de feature ambígua:** Se o *input* do usuário corresponder a múltiplas *features* (ex: "upload" corresponde a F03 e F11), liste os candidatos e peça para o usuário desambiguar.

**Múltiplos arquivos de PRD no projeto:** Pergunte ao usuário qual *PRD* utilizar.

**Dependência ainda não implementada:** Avise o usuário (ex: "F08 depends on F07, which is not yet implemented. Continue anyway?") e prossiga apenas se confirmado. A *spec* ainda pode ser gerada — a ordem de implementação é decisão do usuário.

**Codebase vazia ou apenas com scaffolding (primeira feature):** Pule o *Pattern Discovery* e faça perguntas transversais da *stack inline* no Step 2. As *features* subsequentes farão a leitura da *codebase*.

**O PRD não possui blocos Core Scope / Full Scope para a feature:** Pule a pergunta de *scope*; assuma o *scope* completo da *feature*.

**O PRD possui apenas Core Scope (sem Full Scope additions):** Assuma *scope* = Core; não pergunte.

**Descrição muito vaga:** Se a definição da *feature* no *PRD* for excepcionalmente superficial e deixar muitas decisões em aberto, vá mais a fundo na entrevista — não assuma padrões silenciosamente.

**Nenhum codebase pattern encontrado (mas codebase não está vazia):** Peça ao usuário para confirmar o uso de *industry best practices* ou fornecer uma referência.

**A feature requer novas tecnologias não presentes na codebase:** Liste as novas dependências, peça a confirmação do usuário e documente nas decisões.

**Múltiplos patterns conflitantes na codebase:** Apresente ambos, pergunte qual seguir, documente a escolha.

**Limpeza do nome da feature para kebab-case:** use minúsculas, substitua espaços por hifens, remova caracteres fora de `[a-z0-9-]`. Exemplo: `F07. Background Video Processing Pipeline` → `F07-background-video-processing-pipeline`.

**Input de batch cross-wave:** Rejeite com uma mensagem apontando para `Execution Waves` (`Appendix A` do PRD) e explicando que as *waves* rodam sequencialmente para que a *codebase* acumule *patterns* entre elas. Não divida automaticamente em dois *batches* — o usuário deve rodar a *wave* anterior primeiro, implementá-la, para então rodar a próxima.

**Referência de wave desconhecida:** Liste as *waves* disponíveis em `Execution Waves` (`Appendix A` do PRD) e peça para o usuário esclarecer.

**O batch contém uma feature que já possui spec:** O *plan* consolidado a sinaliza como "already has spec"; o padrão é pular (*skip*). O usuário pode solicitar a regeneração explicitamente na resposta de confirmação.

**O batch contém uma feature cuja dependência externa não está implementada:** Marque a *feature* como "dependency missing — will abort" no *plan*; gere as *specs* para as *features* restantes e reporte a que foi abortada no resultado final. Dependências satisfeitas por outra *feature* no mesmo *batch* não contam como não implementadas.

**Batch com múltiplas Foundation features em um projeto greenfield:** As *Foundations* rodam sequencialmente na ordem em que aparecem em `Foundation Features` (`Appendix A` do PRD). O *plan* afirma isso explicitamente ("Mode: sequential (Foundation detected)"). *Features* não-*Foundation* no mesmo *batch* ainda rodam em paralelo após as *Foundations* finalizarem.

**Falha de sub-agent no batch:** Os outros *sub-agents* continuam até a conclusão. O relatório final lista os sucessos e as falhas com os motivos. As *features* que falharam podem ser rodadas individualmente ou como um *batch* menor.

**PRD sem subseção "Execution Waves" no batch mode:** As referências de *waves* (`wave N`) requerem esta subseção para serem expandidas em *features*. Rejeite com: "Wave references require an 'Execution Waves' subsection in the PRD (Appendix A). This PRD does not have one. Use feature IDs directly or update the PRD." Não tente sintetizar as *waves*.

**O usuário recusa o plan consolidado (responde "no" no B.4):** Aborte o processo de forma limpa. Nenhum *sub-agent* despachado, nenhum arquivo criado, nenhum estado parcial deixado para trás. O usuário re-invoca a *skill* com *input* ajustado.