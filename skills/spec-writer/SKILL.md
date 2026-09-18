---
name: spec-writer
description: Gera spec de implementação técnica, plan e contrato de comportamento para uma ou mais features com base no PRD, análise da codebase e esclarecimento iterativo. O contrato é um arquivo GWT (`contract.md`) agnóstico de stack e de consumidor que descreve a promessa testável da feature. Suporta batch mode para gerar múltiplas features da mesma wave em parallel.
---

# Feature Specs Writer

Gere especificações técnicas *implementation-ready* com base no *PRD* do projeto e nos *patterns* existentes da *codebase*. A *skill* possui dois modos:

- **Single-feature mode (default):** opera em uma *feature* por vez, identificada pelo seu ID de *feature* no *PRD* (F01, F02...), com uma entrevista interativa (Passos 1–7 abaixo).
- **Batch mode:** opera em múltiplas *features* da mesma *wave* em *parallel*, aplicando *auto-accept* em todas as recomendações da entrevista. Ativado automaticamente quando o *input* contém múltiplos IDs, uma referência de *wave* ou uma mistura. Veja a seção **Batch Mode** perto do final deste arquivo.

**Output:** TRÊS arquivos são necessários:
1. `spec.md` - Technical specification (9 seções)
2. `plan.md` - Implementation plan (*phases* e *steps*)
3. `contract.md` - Behavior contract (superfícies de verificação + itens GWT + *coverage manifest*); a promessa testável da *feature*, escrita em linguagem agnóstica de consumidor para que qualquer ferramenta, agente ou pessoa consiga lê-la e exercitá-la

**Output location:** `docs/<feature-id>-<kebab-name>/spec.md`, `docs/<feature-id>-<kebab-name>/plan.md` e `docs/<feature-id>-<kebab-name>/contract.md`
- O `<kebab-name>` é derivado do nome da *feature* na Seção 6 do *PRD* (letras minúsculas, espaços → hifens, caracteres especiais removidos). Exemplo: `F03. Video Upload` → `docs/F03-video-upload/`.

O `contract.md` é **irmão** do `spec.md`, não filho: ambos são gerados na mesma execução a partir do mesmo *PRD*, mas o conteúdo do contrato se apoia nos critérios de aceite do *PRD* (Seção 11 e `Appendix A` → A.6), e não nas escolhas de implementação da *spec* — por isso refatorar a implementação nunca afeta o contrato.

---

## Execution Steps (7 Passos)

Nota: Estes são *steps* internos de execução do agente. O documento de *plan* de OUTPUT terá o número de *phases* definido pela tabela de escalonamento em `references/feature-template.md`, com base na complexidade da *feature*.

### Step 1: Resolver Input e Pre-Analysis

**1.1: Identificar o PRD e a target feature**

Aceite *free-form input* do usuário. O usuário pode referenciar a *feature* por ID (`F03`), por nome (`Video Upload`), por *path* (`docs/PRD.md F03`), ou qualquer combinação. Resolva a referência:

- Localize o arquivo *PRD* a partir da referência do usuário ou procure por `docs/PRD.md`, `PRD.md` ou locais convencionais similares. Se existirem múltiplos *PRDs* plausíveis, pergunte ao usuário qual deles utilizar.
- Identifique a *target feature* dentro do *PRD* por ID ou nome.
- Se o *input* for ambíguo (ex: "upload" corresponde a múltiplas *features*), confirme com o usuário antes de prosseguir.
- Se a *feature* referenciada não existir no *PRD*, liste as *features* disponíveis da tabela de dependências (`Appendix A: Implementation Planning` → `Dependency Graph`; em PRDs antigos, Seção 8) e peça ao usuário para esclarecer.

**Flag opcional:** o *input* pode incluir `create-issue` (em qualquer posição). Quando presente, a *skill* cria uma *issue* de acompanhamento no forge do projeto (GitHub ou GitLab, resolvido conforme `${CLAUDE_PLUGIN_ROOT}/references/forge.md`) para a *feature* no Step 6, sem perguntar. Quando ausente no *single-feature mode*, o Step 6 pergunta `y/n` ao usuário antes de criar; quando ausente no *Batch Mode*, o *plan* consolidado do *orchestrator* (B.4) pergunta uma única vez e a resposta vale para todas as *features* do *batch*. Veja o **Step 6** para o fluxo de criação da *issue* e o **Batch Mode** para a interação em *batch*.

**PRD é obrigatório.** Se nenhum *PRD* for encontrado no projeto, pare e instrua o usuário a gerar um primeiro com a *skill* `prd-writer-for-complete-project`. Não faça *fallback* para uma entrevista não estruturada.

**1.2: Checar dependency readiness e Foundation features (greenfield)**

Leia a tabela `Dependency Graph` do *PRD* (em `Appendix A: Implementation Planning`; em PRDs antigos, Seção 8). Para cada *feature* na coluna `Dependencies` da *target feature*, verifique se ela parece estar implementada na *codebase* (se existem arquivos fonte correspondentes ao *scope* da *feature*). Se alguma dependência ainda não estiver implementada, avise o usuário: "F<X> depende de F<Y> (ainda não implementada). Continuar mesmo assim?". Prossiga apenas se confirmado.

Se o *PRD* contiver uma subseção **Foundation Features** (em `Appendix A`; em PRDs antigos, Seção 8), aplique estas verificações adicionais baseadas no estado de implementação de cada *Foundation feature*:

- **Foundation state detection (o sinal greenfield correto):** para cada *feature* listada em Foundation Features, verifique se ela parece implementada na *codebase* procurando por um ou mais arquivos de *output* característicos que a *feature* deveria criar — por exemplo, um *schema* de *ORM* ou arquivo de *migration* para um *Foundation* de banco de dados, um módulo de *session/middleware* para um *Foundation* de *auth*, um arquivo de *root layout/template* para um *Foundation* de *layout*, ou qualquer artefato equivalente na *stack* sendo usada (framework web, serviço de backend, app mobile, etc.). NÃO dependa da mera presença de marcadores genéricos de projeto como uma pasta fonte ou um arquivo de *package/manifest* — qualquer ferramenta de *scaffolding* (`create-next-app`, `rails new`, `django-admin startproject`, etc.) já cria isso, mas as *Foundation features* do *PRD* ainda podem estar não implementadas.
  - **Greenfield** = zero *Foundation features* implementadas até o momento.
  - **Partial Foundation** = algumas *Foundation features* estão implementadas, outras ainda estão pendentes.
  - **Foundation complete** = todas as *Foundation features* estão implementadas.
- **Scenario 1 — greenfield + target feature É uma Foundation feature:** prossiga sem aviso extra. Este é o caminho esperado para um projeto *greenfield*.
- **Scenario 2 — greenfield + target feature NÃO está em Foundation Features:** avise o usuário: "Este parece ser um projeto greenfield (nenhuma Foundation feature implementada ainda). F<target> não é uma Foundation feature. As Foundation features (F<ID>, ...) montam a infraestrutura compartilhada e deveriam vir primeiro. Recomendo começar por F<first-foundation>. Continuar com F<target> mesmo assim?". Prossiga apenas se confirmado.
- **Scenario 3 — Partial Foundation (algumas Foundation features implementadas, outras pendentes) e a target não é um dos Foundations restantes:** liste as *Foundation features* pendentes e avise: "As Foundation features F<ID1>, F<ID2>... ainda não estão implementadas. Implementar F<target> antes delas pode criar conflitos de arquivo no scaffolding. Continuar mesmo assim?". Prossiga apenas se confirmado.
- **Foundation complete (codebase madura para fins de Foundation):** pule todas as verificações específicas de *Foundation*. O *dependency readiness check* normal acima é suficiente.

**Nota sobre Batch Mode:** Em *Batch Mode*, o *orchestrator* executa essas verificações de dependência e *Foundation* uma vez em todo o *batch* (B.2 e B.3) e filtra as *features* antes do *dispatch*. Os *sub-agents* ignoram todo *prompt* de "avise o usuário / Continuar mesmo assim?" neste passo — assuma que a verificação já foi resolvida pelo *orchestrator* e prossiga.

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
- **Convenção de seeding de estado persistente** (usada nos *Prerequisites* do `contract.md`). Como o projeto prepara dados de teste — *migrations* + arquivos de *seed* (`prisma/seed.ts`, `db/seeds/`), *factory functions* (`tests/factories/`), *setup hooks* (`globalSetup`, `beforeAll`), *helpers* de INSERT, ou outra coisa? Inspecione o código de *setup* de testes, as pastas de *seed/migration*, os arquivos de *factory* e os `contract.md` existentes em `docs/F*-*/` para achar o mecanismo dominante.
- **Convenção de path de static inputs / fixtures** (usada nos *Prerequisites* do `contract.md`). Onde ficam os arquivos de dados de teste — `tests/fixtures/`, `__fixtures__/`, `fixtures/`, `cypress/fixtures/`, `playwright/fixtures/`? Por app ou na raiz? Leia primeiro os `contract.md` anteriores; os *paths* declarados neles são autoritativos quando existem.
- **Convenção de configuração de teste** (usada nos *Prerequisites* do `contract.md`). `.env.test`, `config/test/`, blocos específicos do *framework* — o arquivo (ou esquema) que o *test runner* lê para *env vars* e *flags*.
- **Convenção de mocks / dependências externas** (usada nos *Prerequisites* do `contract.md`). `tests/mocks/`, *handlers* MSW, *stubs* do mountebank etc. Descoberta quando os itens vão exigir externos simulados.

**Layer 2 — Broad exploration (também obrigatório):** além do *baseline*, capture qualquer *pattern* adicional que você observar e que possa informar a implementação — decisões de arquitetura, idiomas da *codebase*, abstrações recorrentes, *logging/observability*, *config management*, convenções de *deploy*, internacionalização, acessibilidade, qualquer coisa. Não se restrinja à lista de *baseline*. Um relatório minucioso em um projeto médio tipicamente tem 8-15 *patterns*.

**1.4: Tratamento de Empty codebase**

Se a *codebase* estiver vazia ou tiver apenas *scaffolding* (ex: apenas `package.json` com padrões, sem implementação em `src/` ainda), pule a descoberta das *Layers* 1/2 e, em vez disso, planeje fazer perguntas transversais da *stack inline* durante o Step 2 (essas perguntas serão feitas apenas uma vez — na primeira *feature*. *Features* subsequentes encontrarão as respostas na *codebase*).

**Nota sobre Batch Mode:** Em *Batch Mode* não há entrevista do Step 2. Aplique a linha "Empty codebase bootstrap" da *Auto-Accept Policy*: faça *fallback* para *industry best practices* da *stack* detectada (ou para o *scaffolding* que existir, se houver), e documente cada escolha de *bootstrap* explicitamente na seção de Assumptions/Decisions da *spec*.

**1.5: Ler os dados da feature do PRD**

Extraia a definição completa da *target feature* do *PRD* e carregue-a como contexto para a *spec* e o contrato (usado pela entrevista no *single-feature mode*, e pela *Auto-Accept Policy* no *Batch Mode*):
- Nome e ID da *feature*
- Bloco `Consumes` (se presente — em `Appendix A` → `Feature Data Contracts`; em PRDs antigos, dentro da Seção 6)
- Bloco `Provides` (mesma localização)
- Bloco `Core Scope` (se presente)
- Bloco `Full Scope additions` (se presente)
- `Capabilities`
- `Experience`
- `Error Handling` (se presente)
- Critérios de aceite (*acceptance criteria*) por *feature* da seção `Acceptance Criteria` (Seção 11; Seção 9 em PRDs antigos)
- Critérios de `Cross-Feature Integration` da mesma seção cujo cenário (`UC<NN>`) tem esta *feature* na coluna `Owner` da tabela `Use Scenario Coverage` (`Appendix A` → A.6)
- A linha da *feature* no `Dependency Graph` (`Priority`, `Dependencies`) e sua *wave* em `Execution Waves` (`Appendix A` → A.2 e A.4; Seção 8 em PRDs antigos)
- `Non-Functional Requirements` (Seção 7) cujos `RNF` afetam esta *feature* — desempenho percebido, disponibilidade, capacidade, segurança/privacidade, conformidade, acessibilidade, auditabilidade. **São a principal entrada de negócio para as decisões técnicas da spec.**
- `Key Decisions and Trade-offs` (Seção 8) e `Open Questions` que restringem esta *feature*
- `Dependencies` (Seção 9) que esta *feature* precisa consumir
- `Risks and Mitigation` (Seção 10) cuja mitigação recai sobre esta *feature*
- `Validation and Test Strategy` (Seção 12) — critérios de saída e forma de validação aplicáveis a esta *feature*

Se o *PRD* for do formato antigo de 9 seções, os itens das Seções 7–12 e a tabela A.6 simplesmente não existem: siga sem eles e registre a lacuna nas *assumptions* da spec. O mesmo vale para um *PRD* de 12 seções sem `A.6 Use Scenario Coverage`: nenhum critério de `Cross-Feature Integration` entra no contrato; registre a lacuna nas *assumptions*.

**1.6: Apresentar entendimento ao usuário**

```
Com base na minha análise, entendo que você deseja implementar:

**Feature:** F<ID>. <Name>
**Technical Summary:** [1-2 frases derivadas das Capabilities + Experience do PRD]
**Observed codebase patterns:** [resumo das descobertas da Layer 1 + Layer 2, ou "empty codebase — will bootstrap"]
**PRD context loaded:** Consumes, Provides, Core Scope, Full Scope, Capabilities, Experience, Error Handling, acceptance criteria (incluindo os de Cross-Feature Integration atribuídos a esta feature), NFRs, decisões de produto, dependências, riscos, estratégia de validação

Preciso esclarecer algumas decisões técnicas que o PRD e a codebase ainda não respondem.
```

**Nota sobre Batch Mode:** Os *sub-agents* ignoram este passo — não há usuário interativo para quem apresentar. O *plan* consolidado do *orchestrator* (B.4) cobre o entendimento compartilhado para o *batch*.

### Step 2: Interview (Entrevista)

**Batch Mode override:** Em *Batch Mode*, este passo inteiro é substituído pela *Auto-Accept Policy* (veja a seção Batch Mode). Os *sub-agents* pulam o Step 2 e prosseguem diretamente para o Step 3 com os padrões do *Auto-Accept* aplicados. Toda instrução de "pergunte ao usuário" abaixo se torna "aplique o default da *Auto-Accept* e documente a escolha nas *assumptions* da *spec*".

Entreviste o usuário incansavelmente sobre cada aspecto deste plano até chegarmos a um entendimento compartilhado. Percorra cada ramo da árvore de design, resolvendo as dependências entre decisões uma a uma. Para cada pergunta, forneça sua resposta recomendada.

Faça as perguntas uma de cada vez.

Se uma pergunta puder ser respondida explorando a *codebase* ou lendo o *PRD*, explore ou leia em vez de perguntar.

**Pergunta de Scope (faça primeiro, quando aplicável):** Se a *feature* tem ambos os blocos `Core Scope` e `Full Scope additions` no *PRD*, pergunte: "A spec deve cobrir apenas o `Core Scope`, ou `Core Scope` + `Full Scope additions`?". Se apenas um dos blocos estiver presente, ou nenhum estiver presente, pule esta pergunta e assuma o *scope* completo da *feature*.

**Esclarecimento de quality gates (faça em segundo, depois da pergunta de scope):** Detecte os *quality gates* do projeto a partir do contexto já ao seu alcance (o *harness* injetou o `CLAUDE.md` e a documentação do projeto; *manifests* como `package.json`, `Makefile`, `Taskfile`, `justfile`, `pyproject.toml` etc. podem ser lidos). Antes de montar a lista, verifique na *codebase* e nas *skills* disponíveis se existe um *script wrapper* que execute todos os *gates* de uma vez; quando existir, proponha o *wrapper* como *gate* no lugar dos *scripts* individuais que ele já executa. Apresente a lista detectada ao usuário: "Detectei estes quality gates no projeto — confirme ou edite a lista antes que eu escreva a seção `## Quality gates` no contrato." Cada entrada detectada deve ter um nome, o comando literal a executar e uma descrição de uma linha do que significa passar. Aceite as edições do usuário (inclusões, remoções, reordenações, correções de comando, reescrita de descrições) antes de continuar. Se você não encontrar nenhum *gate*, pergunte: "Não detectei quality gates neste projeto. Pular a seção `## Quality gates` no contrato?" — o usuário pode recusar (nesse caso, peça que ele dite os *gates*) ou aceitar (a seção é omitida por inteiro do contrato gerado).

**Anti-redundancy rule:** NÃO pergunte sobre nada que já seja observável em:
- Definição da *feature* no *PRD* (Consumes, Provides, Core Scope, Capabilities, Experience, Error Handling)
- Critérios de aceite (*acceptance criteria*) do *PRD* para esta *feature*
- Os *codebase patterns* descobertos no Step 1.3
- Um `spec.md`, `plan.md` ou `contract.md` gerado anteriormente para outra *feature* no mesmo projeto (quando existirem e forem relevantes)

Concentre a entrevista em decisões que o *PRD* e a *codebase* **não** respondem ainda: arquitetura interna, detalhes do *schema* de banco de dados (colunas, índices, *constraints*), assinaturas de *endpoints*, regras de validação não especificadas em Capabilities, nomenclatura de novos arquivos, escolha entre bibliotecas quando não houver *patterns* estabelecidos, *edge cases* não cobertos pelo *Error Handling*, superfícies do contrato quando o *PRD* for ambíguo (Step 4.3) e convenções de *fixtures*/*seeding*/configuração de teste quando o projeto não tiver nenhuma (Step 4.3).

**Partial PRD specifications:** Quando o *PRD* menciona uma *capability* mas omite um detalhe específico (ex: "chunked upload" sem definir o tamanho do chunk), peça o detalhe ausente em vez de assumir um padrão.

**Empty codebase bootstrap:** Se o Step 1.4 sinalizou uma *empty codebase*, faça perguntas transversais da *stack inline* durante este passo (*framework*, *ORM*, *auth*, estilo de API, *validation*, *testing*, *error handling*, *folder structure*). Assim que a primeira *feature* for implementada, a *codebase* se torna a referência para as *features* subsequentes.

### Step 3: Summary e Assumptions

Após receber as respostas:
- Resuma as decisões técnicas tomadas
- Liste as premissas (*assumptions*) derivadas do *PRD*, dos *codebase patterns* e das respostas da entrevista
- Note explicitamente quais blocos do *PRD* informaram quais partes da *spec* (*traceability*)
- **Classifique a complexidade da *feature*** (`trivial` | `simple` | `medium` | `complex`) usando os critérios da tabela "Níveis de Complexidade" em `references/feature-template.md`. Esse valor é o COMPLEXITY_LEVEL usado no Step 4 e reportado no Step 7.

**Nota sobre Batch Mode:** Em *Batch Mode* não há respostas de entrevista. Trate cada padrão da *Auto-Accept Policy* que foi aplicado como se fosse uma resposta de entrevista — liste sob *assumptions*, nomeie a linha da política que o gerou e sinalize para que o usuário possa revisar e fazer *override* posteriormente. A *traceability* dos blocos do *PRD* funciona da mesma forma que no *single-feature mode*.

### Step 4: Gerar Documentos

**Announce:** "Gerando TRÊS documentos: SPEC, PLAN e CONTRACT..."

**Diretrizes de escala por complexidade:** a fonte da verdade são as tabelas "Escalonamento de profundidade por complexidade" e "Escalonamento do documento PLAN" em `references/feature-template.md`. Consulte-as antes de gerar; não duplique esses números aqui.

**Use o template `references/feature-template.md` para a SPEC e o PLAN** — ele define as 9 seções da *spec*, o formato do *plan* e os níveis de complexidade. **Use o template `references/contract-template.md` para o CONTRACT** — ele é a fonte única do formato do `contract.md`.

Nota: A profundidade do documento SPEC (*schemas*, índices, *migrations*) escala com a complexidade. Os *steps* do documento PLAN são sempre de alto nível, independentemente da complexidade.

**4.1: Generate SPEC**:
- Escale as seções com base no COMPLEXITY_LEVEL, conforme a tabela de escalonamento do template:
  - trivial: Ignore *API Contracts* e *Data Model*
  - simple: Inclua *API Contracts* e *Data Model* em forma reduzida; omita apenas se a *feature* genuinamente não tiver *endpoints* ou *schema*, e registre a omissão em Assumptions
  - medium/complex: Todas as 9 seções requeridas
- Escale a profundidade dentro das seções com base na complexidade
- Inclua exemplos JSON, *SQL migrations*, especificações de testes
- **Conteúdo da Spec §9 *Testing Strategy*:** descreva arquivos de teste, funções de teste, testes de *frontend* e cenários E2E como orientação de implementação para quem escreve o código. **Não inclua uma tabela de mapeamento de acceptance criteria do PRD, não adicione uma coluna "Critério de aceite coberto" a nenhuma sub-tabela e não anote critérios cross-feature como "OUT OF SCOPE" dentro do `spec.md`.** O mapeamento AC ↔ verificação é gerado separadamente no *Coverage Manifest* do `contract.md` no Step 4.3, que é a fonte única dessa ligação. O filtro de critérios fora do escopo é codificado em silêncio por quais ACs entram no *Coverage Manifest* — nunca por uma anotação na *spec*.
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

**Nota sobre a Seção 11 do PRD (`Acceptance Criteria`):** os critérios por *feature* e os critérios de `Cross-Feature Integration` atribuídos a esta *feature* em A.6 NÃO são mapeados dentro do `spec.md`. A fonte única do mapeamento AC ↔ verificação é o *Coverage Manifest* do `contract.md` (texto do AC copiado do PRD → IDs dos itens que o cobrem). A Spec §9 continua listando arquivos de teste, testes de *frontend* e cenários E2E como orientação de implementação, mas NÃO carrega tabela "AC ↔ teste" nem coluna que ligue cenários a ACs. Os critérios de `Cross-Feature Integration` vivem apenas no contrato da *feature* `Owner` do cenário, nunca na *spec*. Os critérios do bloco `Non-Functional Acceptance` nunca entram no contrato: os `RNF` são tratados pelas linhas "Seção 7" e "Seção 12" da tabela acima. Essa separação permite que quem implementa foque em estrutura/arquitetura (*spec*) e que quem avalia o contrato seja dono da verificação de comportamento (*contract*).

**4.2: Generate PLAN**:
- Seção de *Prerequisites*
- *Phases* com *steps* numerados (1-3 frases cada, alto nível)
- Descreva o QUE fazer, faça referência à *spec* para o COMO fazer

Siga o formato de *Phases e Steps* e as *Guidelines de Conteúdo* de `references/feature-template.md`.

**4.3: Generate CONTRACT**:
- Leia de `references/contract-template.md` o formato completo, a regra de idioma, o catálogo de superfícies, o *schema* dos itens, os *guard-rails*, as regras de *Prerequisites*, de *Quality gates* e do *coverage manifest*. Esse template é a fonte única do formato do `contract.md` — não improvise estrutura.
- **Idioma:** conteúdo em pt-BR; âncoras estruturais em inglês, literalmente como listadas na "Regra de Idioma" do template (títulos de seção, labels de *Prerequisites*, `Verification mode:`, `Common given:`, `Used by:`, campos `id`/`given`/`when`/`then`/`notes`, sub-headers de *capability* e IDs dos itens).
- **Monte o conjunto de critérios candidatos.** São duas origens: (a) os critérios do bloco `### F<ID>` da Seção 11 do *PRD* (Seção 9 em PRDs antigos); (b) os critérios `(UC<NN>)` de `Cross-Feature Integration` cujo cenário tem esta *feature* como `Owner` em `Appendix A` → A.6. Critérios `(RNF<NN>)` do bloco `Non-Functional Acceptance` nunca são candidatos.
- **Filtre os critérios da origem (a) contra o bloco `Included` da `spec.md` da *feature* antes de gerar os itens.** ACs cujo comportamento verificado pertence inteiramente a outra *feature* (seja a jusante desta, irmã na mesma *wave*, ou em qualquer outro lugar do *PRD*) são descartados em silêncio — não entram no *manifest*, não geram itens e não produzem avisos no console durante a geração. Os critérios da origem (b) não passam por este filtro: a atribuição em A.6 já garante que o cenário é exercitável com esta *feature* + seu fecho de dependências. O conjunto restante são os "ACs in-scope". Princípio: todo item precisa ser testável com esta *feature* + o **fecho de dependências** dela no `Dependency Graph` (`Appendix A` → A.2; Seção 8 em PRDs antigos) implementados; itens que exigem *features* FORA do fecho para verificar seu comportamento não devem ser gerados. (Quando o comportamento do AC é desta *feature*, mas o *setup* natural do teste precisaria de infraestrutura de fora, não descarte o AC — mantenha-o e aplique o *Preparation Pattern* da regra de fecho de dependências abaixo.)
- Detecte quais superfícies se aplicam (`Service`, `HTTP API`, `CLI`, `UI`, `Worker`, `Event`, `E2E`) inspecionando `Capabilities`, `Experience` e `Provides` do *PRD* em busca de sinais de superfície. No *single-feature mode*, pergunte durante a entrevista quando for ambíguo. Em *Batch Mode*, o default é "todas as superfícies com ao menos um sinal no PRD", documentado em Assumptions.
- Aplique a **Service Admission Rule** com rigor: emita `## Service` apenas quando houver um consumidor real fora desta *feature*. Nunca a emita para *helpers* internos, VOs, *entities* ou itens por classe.
- Gere os itens com os quatro *guard-rails* no `then` (coesão de superfície, atomicidade da ação, *soft cap* de ~5 bullets, bullet atômico). Use `Common given:` por *capability* para evitar repetição.
- Os IDs dos itens seguem `<SURFACE>-<CAPABILITY>-<NN>` (sem prefixo de ID da *feature*). Códigos de superfície: `SVC`, `API`, `CLI`, `UI`, `WRK`, `EVT`, `E2E`.
- Monte o **Coverage Manifest** mapeando cada AC in-scope para os IDs dos itens que o cobrem. A primeira coluna carrega o **texto do AC copiado do PRD como está** — tudo o que vem depois de `- [ ] ` na linha do critério, incluindo o prefixo de ID (`(RF01.1) ...`, `(UC01) ...`) —, não um ID sintético.
- Monte a seção **Prerequisites** como a primeira seção `##` abaixo do título (a linha de regeneração em itálico não é uma seção), acima do *Coverage Manifest*. Derive condições prospectivas sem inspecionar o *filesystem* (a implementação ainda não existe); use as convenções do projeto capturadas no Step 1.3 para ancorar *paths* e mecanismos.
- Monte a seção **Quality gates** logo depois de `## Prerequisites` e antes de `## Coverage Manifest`. Renderize cada *gate* confirmado no esclarecimento do Step 2 como um bullet no formato `- **<name>** — \`<command>\` — <descrição de uma linha do que significa passar>`. Abra a seção com um parágrafo curto que diga "Cada gate precisa passar para a feature ser considerada pronta" — descreva apenas comportamento, nunca nomeie um executor (nada de "o evaluator roda", nada de vocabulário de *fail-fast*, nada de prescrição de ordem de execução). Se o usuário recusou a seção no esclarecimento do Step 2 (nenhum *gate* detectado e nenhuma lista ditada), omita a seção por inteiro — não renderize um *placeholder* vazio.
- Use as **cinco subseções fixas** nesta ordem, omitindo as que não tiverem entradas (sem *placeholder* "nenhum."): `Runtime services`, `Persistent state`, `Static inputs`, `Configuration`, `External dependencies`.
- **`Persistent state` e `Static inputs` NUNCA se misturam.** *Persistent state* cobre entidades/contas/registros/mensagens/tokens que precisam existir *dentro* do *store*/fila do sistema (O QUE, de forma declarativa — a convenção de *seeding* do projeto dita o COMO). *Static inputs* cobre arquivos que os itens referenciam por *path* (a convenção de *path* de *fixtures* do projeto dita ONDE no disco). Uma conta pertence a *Persistent state*, nunca a *Static inputs*. Um arquivo de vídeo pertence a *Static inputs*, nunca a *Persistent state*.
- **Reutilize as convenções descobertas no projeto; nunca invente *paths* ou mecanismos.** Os *paths* de *Static inputs* vêm da convenção de *path* de *fixtures* descoberta no Step 1.3 e declarada pelos contratos anteriores em `docs/F*-*/`. As entradas de *Persistent state* são escritas de forma declarativa; o implementador as cumpre pela convenção de *seeding* descoberta no Step 1.3. As entradas de *Configuration* seguem a convenção de configuração de teste do projeto. As *External dependencies* seguem a convenção de *mocks* do projeto.
- **Regra de fecho de dependências para Prerequisites (independência vs. preparação).** Toda entrada de *Prerequisites* PRECISA ser satisfazível pelas entregas desta própria *feature* OU por *features* dentro do **fecho de dependências** desta *feature* no `Dependency Graph` (esta *feature* + suas dependências declaradas + as dependências transitivas delas). Nunca declare um *prereq* que exija que uma *feature* **fora** desse fecho esteja implementada — mesmo quando a *feature* de fora está na mesma *wave* ou parece "logicamente relacionada". A tabela `Dependency Graph` é a única fonte autoritativa do que esta *feature* pode usar. (Não confunda com a Seção 9 `Dependencies` do *PRD*, que trata de dependências de negócio externas.)

  Quando um AC in-scope descreve o comportamento da superfície desta própria *feature*, mas o *setup* natural do teste normalmente precisaria de infraestrutura de uma *feature* fora do fecho (caso típico: uma *feature* irmã que constrói *auth*, sessões, pagamentos, armazenamento de arquivos etc.), aplique o **Preparation Pattern**:

  1. Confirme que o AC descreve o comportamento da superfície DESTA *feature*. Se ele na verdade descreve uma integração em nível de sistema com outra *feature*, descarte-o como cross-feature (o filtro do Step 4.3 já trata disso).
  2. Trate a infraestrutura ausente como um *stub*/*override*/*flag* que ESTA *feature* entrega como parte do próprio escopo — não como um estado real que a *feature* irmã produz.
  3. Redija o *prereq* em torno do mecanismo interno da *feature*, nunca em torno do estado real da *feature* irmã.

  Exemplo concreto. F01 (Landing Page, deps: nenhuma) tem o AC "usuários autenticados que visitam `/` são redirecionados para `/app`". A *auth* é entregue por F02 (irmã, também sem deps). F02 está **fora** do fecho de dependências de F01. ERRADO: declarar `landing-returning-user — existe como um usuário autenticado real com sessão válida`, o que exige o fluxo de *auth* de F02. CERTO: declarar uma entrada de `Configuration` como `a verificação de sessão usada por /` `pode ser levada a um estado autenticado por um mecanismo de teste com escopo de F01 (flag só de teste, override do módulo de sessão, ou cookie de teste honrado pela própria F01); esse mecanismo faz parte das entregas de F01.` F01 implementa tanto o comportamento de produção QUANTO o *override* de teste; o contrato é exercitável só com F01.

  Justificativa: o contrato de uma *feature* precisa ser exercitável quando apenas esta *feature* + suas dependências declaradas estão implementadas. Se não for, ou (a) o contrato saiu do escopo declarado e o *prereq* está errado, ou (b) o AC é genuinamente cross-feature e deveria ter sido filtrado no Step 4.3.
- **Greenfield (nenhuma convenção encontrada):** no *single-feature mode*, leve a pergunta para a entrevista ("Onde as fixtures devem ficar? Como os dados de teste são semeados? Qual arquivo de env o test runner lê?"). Em *Batch Mode*, aplique o default mais comum da *stack* detectada (ex.: `tests/fixtures/` para projetos Node/Vitest) e documente cada convenção escolhida em Assumptions da *spec*. As *features* seguintes do mesmo projeto reutilizam a escolha.
- Cite os itens consumidores na cláusula `Used by:` de cada entrada de *Persistent state* e *Static inputs*. Os itens referenciam essas entradas por *handle* (nome da conta, *path* do arquivo) no `given` e no `when`.
- Escreva os *Prerequisites* em linguagem agnóstica de consumidor — nunca nomeie "o agente implementador" ou "o evaluator"; apenas declare as condições.
- ACs subjetivos (identidade visual, julgamento qualitativo) são cobertos por um item *placeholder* com `notes: subjective; manual review only`.
- Critérios de `Cross-Feature Integration` entram apenas no *manifest* da *feature* `Owner` do cenário em A.6; nunca no contrato das demais *features* envolvidas.

**Announce:** "Três documentos redigidos. Validando a cobertura..." (o *save* depende de o Step 5 passar, incluindo o *hard coverage gate* do contrato).

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
- [ ] **Nenhum mapeamento AC ↔ teste no `spec.md`.** A Spec §9 lista arquivos de teste / testes de *frontend* / cenários E2E apenas como orientação de implementação; sem tabela de mapeamento de acceptance criteria, sem coluna "Critério de aceite coberto" em nenhuma sub-tabela, sem rastreabilidade por AC dentro do `spec.md`. O mapeamento AC ↔ verificação vive exclusivamente no *Coverage Manifest* do `contract.md`.
- [ ] Nenhuma nota de rastreabilidade na *spec* aponta texto de AC para dentro do `spec.md` (o *Coverage Manifest* do `contract.md` é canônico para essa ligação)

Documento PLAN:
- [ ] *Steps* numerados ao longo das *phases*
- [ ] Formato: **N. Component** - Parágrafo de alto nível (1-3 frases)
- [ ] *Steps* descrevem O QUE, não COMO (a *spec* possui os detalhes)

Documento CONTRACT:
- [ ] O título é seguido por uma linha de regeneração em itálico (`*Gerado pelo spec-writer. Edições manuais são sobrescritas na regeneração.*`), não por um comentário HTML
- [ ] As âncoras estruturais estão em inglês, literalmente como na "Regra de Idioma" do template; o restante do conteúdo está em pt-BR
- [ ] A primeira seção `##` abaixo do título é `## Prerequisites` (a linha de regeneração em itálico não é uma seção); ela fica acima do *Coverage Manifest* e usa as **cinco subseções fixas** na ordem (`Runtime services`, `Persistent state`, `Static inputs`, `Configuration`, `External dependencies`), omitindo as que não têm entradas
- [ ] Os *Prerequisites* são escritos como condições prospectivas, nunca como retratos do estado atual. A redação sustenta duas leituras sem privilegiar nenhuma: (a) para quem constrói a *feature*, os *prerequisites* são entregas a produzir junto com o código; (b) para quem exercita o contrato depois, são pré-condições a verificar antes de executar os itens
- [ ] O conteúdo gerado é agnóstico de consumidor: o contrato nunca nomeia "o agente implementador", "o evaluator", "o agente avaliador" ou qualquer ferramenta específica — ele descreve comportamento, não quem o executa
- [ ] `Persistent state` e `Static inputs` não estão misturados — contas/registros/sessões/tokens nunca aparecem em `Static inputs`; arquivos nunca aparecem em `Persistent state`
- [ ] As entradas de `Persistent state` são declarativas ("alice existe com X atributos"), nunca operacionais ("rode este seed" / "execute este SQL")
- [ ] Os *paths* de `Static inputs` seguem a convenção de *path* de *fixtures* descoberta no projeto (batendo com as declarações dos `docs/F*-*/contract.md` anteriores e com as pastas de *fixtures* existentes); nenhum *path* ad hoc inventado
- [ ] Todo *handle* referenciado no `given` ou `when` de qualquer item (nomes de conta, *paths* de arquivo) tem declaração correspondente na subseção de *Prerequisites* adequada
- [ ] Nenhuma declaração em `Persistent state` ou `Static inputs` fica sem ao menos um item consumidor na cláusula `Used by:` (sem declarações órfãs)
- [ ] **Checagem de fecho de dependências.** Toda entrada de *Prerequisites* (nas cinco subseções) é satisfazível pelas entregas desta *feature* ou por *features* dentro do fecho de dependências dela no `Dependency Graph`. Nenhuma entrada referencia estado real, conta, sessão, *capability* ou conceito de *runtime* que só uma *feature* FORA do fecho produziria. Quando o *setup* natural de um AC in-scope precisaria de infraestrutura de fora, o *prereq* descreve um *stub*/*override*/*flag* interno da *feature* (o *Preparation Pattern*), não o estado real da *feature* de fora.
- [ ] Se `## Quality gates` estiver presente, fica entre `## Prerequisites` e `## Coverage Manifest`; cada entrada segue `- **<name>** — \`<command>\` — <descrição>`; o preâmbulo descreve apenas comportamento e nunca nomeia um executor (nada de "o evaluator", nada de vocabulário de *fail-fast*, nada de prescrição de ordem de execução); quando nenhum *gate* foi detectado e o usuário recusou ditar algum, a seção é omitida por inteiro (sem *placeholder* vazio)
- [ ] `## Coverage Manifest` é a próxima seção `##` depois de `## Prerequisites` (quando não há *Quality gates*) ou de `## Quality gates` (quando presente) e mapeia o texto copiado do PRD de cada AC in-scope → IDs dos itens que o cobrem
- [ ] A primeira coluna do *manifest* reproduz o critério do PRD como está, incluindo o prefixo de ID (`(RF..)` ou `(UC..)`)
- [ ] Nenhuma linha do *manifest* referencia um AC da própria *feature* cuja verificação cai fora do escopo `Included` do `spec.md` (critérios cross-feature foram descartados em silêncio na geração)
- [ ] Nenhuma linha do *manifest* traz critério `(RNF..)` de `Non-Functional Acceptance`
- [ ] Todo critério `(UC..)` no *manifest* pertence a um cenário cujo `Owner` em A.6 é esta *feature*, e todo critério de cenário com `Owner` = esta *feature* está no *manifest*
- [ ] Toda seção de superfície de primeiro nível corresponde a uma superfície do catálogo (`Service`/`HTTP API`/`CLI`/`UI`/`Worker`/`Event`/`E2E` ou uma extensão documentada)
- [ ] Toda seção de superfície tem uma linha `Verification mode:` logo abaixo do título
- [ ] `## Service` (se presente) nomeia um consumidor real fora desta *feature*; nenhum item por classe/VO/*helper* em lugar nenhum
- [ ] Os sub-headers usam vocabulário de *capability*, não de entidade de superfície (nada de `### POST /auth/register`, nada de `### /login page`)
- [ ] Todo item tem `id`, `given`, `when`, `then` (nesta ordem); `notes` apenas quando necessário
- [ ] Os IDs dos itens são únicos no arquivo e seguem `<SURFACE>-<CAPABILITY>-<NN>` (sem prefixo de ID da *feature*)
- [ ] Nenhum `then` passa de ~5 bullets sem justificativa clara; nenhum passa de 10
- [ ] Nenhum bullet contrabandeia várias observações com conjunções "e"
- [ ] Todo item é testável com esta *feature* + o fecho de dependências dela no `Dependency Graph` implementados. Nenhuma verificação de comportamento depende de uma *feature* fora desse fecho (consumidores a jusante E irmãs incluídas). O *setup* de teste que naturalmente precisaria de infraestrutura de fora é atendido pelo *Preparation Pattern*, não referenciando a *feature* de fora diretamente.
- [ ] Nenhum *anti-pattern* de `references/contract-template.md` § "Anti-patterns a recusar" está presente (nenhum `then` que repete o `when`, nenhum item por classe, nenhum *setup* operacional vazando para o `given`, nenhum bullet "o teste passa" / "a função é chamada", nenhuma linha do *manifest* com "Covered by" vazio, nenhuma referência a *fixture* sem declaração em *Prerequisites*)

**Hard coverage gate:** antes de salvar, verifique que todo AC **in-scope** desta *feature* (todo critério da própria *feature* que sobreviveu ao filtro do Step 4.3, mais todo critério de `Cross-Feature Integration` atribuído a ela em A.6) aparece no *Coverage Manifest* com ao menos um ID de item cobrindo. Se qualquer AC in-scope tiver zero cobertura, aborte e NÃO salve nada (nem *spec*, nem *plan*, nem *contract*). Imprima:

```
ERROR: contract coverage gap for F<ID>. The following in-scope PRD acceptance
criteria have no covering item:
  - "<texto do AC>"
  - "<texto do AC>"
Either generate covering items, or revise the PRD/spec if the AC is no longer
applicable to this feature.
```

Abortar os três arquivos (e não só o contrato) mantém a pasta da *feature* consistente.

**Salve os três arquivos em `docs/<feature-id>-<kebab-name>/spec.md`, `plan.md` e `contract.md`.** Crie a pasta se não existir. Verifique os três arquivos com a *tool* de Read.

### Step 6: Issue Creation (opcional)

Depois que o Step 5 salvar os três arquivos com sucesso, decida se abre uma *issue* de acompanhamento no forge do projeto para esta *feature*.

**6.0 — Resolver o forge.** Só quando o 6.1 decidir que vai criar. Resolva o forge (`github` | `gitlab`) e faça a pré-checagem do CLI conforme `${CLAUDE_PLUGIN_ROOT}/references/forge.md` (seções 1 e 2) — esse arquivo é canônico para as operações de forge desta *skill*; não improvise comandos de CLI. CLI ausente ou não autenticado NÃO aborta: cai no 6.5 como *soft-fail*, com a dica de instalação. Use o termo do forge resolvido no texto que o usuário lê ("issue" vale para os dois).

**6.1 — Decidir se cria.**

- Se a *flag* `create-issue` estava no *input* → siga para 6.2 sem perguntar.
- Se ausente (*single-feature mode*) → pergunte ao usuário: `"Criar uma issue no <GitHub|GitLab> para F<ID> <Feature Name>? (s/n)"`, nomeando o forge resolvido no 6.0. Siga para 6.2 apenas com `s` / `sim` / `y` / `yes`. Qualquer outra resposta (ou `n`) pula a criação por inteiro; vá para o Step 7.
- Se ausente (*Batch Mode*) → o *orchestrator* já perguntou uma vez em B.4 e propagou a decisão. O *sub-agent* trata a ausência aqui como "não criar", porque o *orchestrator* só encaminha `create-issue` quando o usuário optou por criar. Vá para o Step 7.

**6.2 — Detectar issue aberta existente.**

Procure no forge uma *issue* aberta cujo título comece com `[F<ID>]`, com a operação **"listar issue aberta por prefixo de título"** (`references/forge.md` § 3.2). Aplique o filtro de título do lado do chamador que a seção descreve — o `--search` do `glab` varre título e descrição, e sem o filtro uma *issue* que apenas cite `[F<ID>]` no corpo passaria por correspondência.

- **Uma correspondência aberta** → pule a criação. Guarde a URL existente para a saída do Step 7.
- **Várias correspondências abertas** → use a primeira; registre em `Soft-fails`: `"várias issues abertas com o prefixo [F<ID>]; reportando apenas a #<first-number>"`.
- **Só correspondências fechadas OU nenhuma** → siga para 6.3 (criar nova). Uma *issue* fechada significa que o ciclo anterior desta *feature* já foi entregue; a nova *spec* merece uma *issue* nova.

**6.3 — Montar título e corpo.**

Origens dos *placeholders* (sem reler o que já foi carregado):

- **`<Nome da Feature>`** — da entrada da Seção 6 do *PRD* já carregada no Step 1.5; caso contrário, derive do nome da pasta da *feature* (`F<ID>-<kebab>` → remova o prefixo, troque hifens por espaços, capitalize).
- **`<texto do AC>`** — os critérios de aceite da própria *feature* na Seção 11 do *PRD* (já carregados no Step 1.5), cada um copiado como está, incluindo o prefixo de ID.
- **`<dependências>`** — da linha da *feature* no `Dependency Graph` (`Appendix A` → A.2, já carregada no Step 1.5).
- **`<wave>`** — de `Execution Waves` (`Appendix A` → A.4); **`<prioridade>`** — da coluna `Priority` do `Dependency Graph` (A.2).
- **`<resumo de 2–3 frases>`** — as primeiras 1–2 frases de `Capabilities` mais, se necessário, uma frase de `Experience`, da Seção 6 do *PRD*.

Título:
```
[F<ID>] <Nome da Feature>
```

Template do corpo:

````markdown
## Resumo

Implementa **F<ID>: <Nome da Feature>**.

<resumo de 2–3 frases derivado de Capabilities + Experience do PRD>

## Critérios de Aceite

- [ ] <texto do AC copiado da Seção 11 do PRD>
- [ ] <texto do AC copiado da Seção 11 do PRD>
...

## Dependências

- F<dep-ID>: <nome da dependência>
- ...

(ou "Nenhuma" quando não há dependências)

## Wave e Prioridade

- Wave: <N>
- Prioridade: <1|2|3>

## Documentos

- Spec: `docs/F<ID>-<name>/spec.md`
- Plan: `docs/F<ID>-<name>/plan.md`
- Contract: `docs/F<ID>-<name>/contract.md`
- Seção do PRD: `<path do PRD>` § F<ID>

---

🤖 Gerada automaticamente. Cada critério de aceite acima será verificado ponta a ponta contra o contrato.
````

**6.4 — Criar a issue.** Aplique a operação **"criar issue"** (`references/forge.md` § 3.3) com o título e o corpo montados no 6.3, usando o CLI do forge resolvido no 6.0.

Guarde a URL da *issue* retornada (`url` no GitHub, `web_url` no GitLab). NÃO adicione *labels*, *assignees*, *milestones* nem *projects* — nenhum é definido por padrão. Times que os queiram configuram os *defaults* do repositório no próprio forge ou os aplicam manualmente depois da criação.

**6.5 — Tratamento de falha.** Se o CLI do forge sair com código diferente de zero (*auth*, rede, CLI não instalado, repositório não conectado), NÃO aborte a execução. Os três arquivos já estão salvos — essa é a entrega principal da *skill*. Registre em `Soft-fails`: `"issue não criada: <stderr excerpt>; rode manualmente: <comando de criação de issue do forge, § 3.3, com --body-file/--description-file apontando para <path-to-body>.md>"`. Siga para o Step 7.

### Step 7: Output Result

Informe o *path* dos arquivos de *spec*, *plan* e *contract*, o nível de complexidade da *feature*, quantas *phases* há no *plan* e a contagem de itens do contrato por superfície (ex.: "Contrato: 14 itens entre HTTP API (8), UI (4), E2E (2); 9/9 ACs do PRD cobertos"). Informe também a URL da *issue* (criada ou existente) quando o Step 6 rodou, e os `Soft-fails`, quando houver.

---

## Batch Mode

Gere *specs* para múltiplas *features* da mesma *wave* em *parallel*, aplicando *auto-accept* em todas as recomendações de entrevista. Este modo é um mero *wrapper* de orquestração sobre os Steps 1–7: os *sub-agents* executam o fluxo de *single-feature* completo; o *orchestrator* apenas resolve o *input*, valida, faz o *dispatch* e relata.

### Ativação

A *skill* entra no modo *Batch Mode* automaticamente quando o *input* corresponde a qualquer um destes padrões:
- Múltiplos IDs de *features*: `F01 F02 F03`
- Referência de *wave*: `wave 3`
- Mistura dentro da mesma *wave*: `wave 3 F04`
- Múltiplos nomes de *features*, ou nomes misturados com IDs, contanto que todos resolvam para a mesma *wave*

Um *input* de *single-feature* (ex: `F03`, `Video Upload`) continua a usar o fluxo interativo (Steps 1–7).

### Regra de Same-wave

Todas as *features* em um único *batch* devem pertencer à mesma *wave* (conforme `Execution Waves` no `Appendix A` do PRD).

- *Input* de múltiplas ondas (*cross-wave*, ex: `wave 3 wave 4`, ou `F04 F05` onde F04 é *wave 3* e F05 é *wave 4*) é rejeitado. Mensagem: "Features de waves diferentes não podem ser geradas no mesmo batch. As specs de waves posteriores ficam mais ricas quando geradas depois que as waves anteriores estão implementadas, porque a codebase tem mais patterns a observar. Rode a wave N primeiro."
- Misturar `wave N` com nomes/IDs extras de *features* é permitido apenas se todas as *features* listadas pertencerem à wave N. Qualquer exceção aciona a mesma rejeição.
- Número de *wave* desconhecido → rejeite, listando as *waves* disponíveis em `Execution Waves` (`Appendix A` do PRD).
- ID/nome da *feature* desconhecido → rejeite, listando as *features* disponíveis.

### Fluxo de Orchestration

O Step 1 (Resolver Input e Pre-Analysis) é adaptado para o contexto de *batch* conforme descrito abaixo. Os Steps 2–7 NÃO são executados pelo *orchestrator* — eles rodam dentro de cada *sub-agent*, um por *feature*, de acordo com a *Auto-Accept Policy*.

**B.1: Resolver o batch**

- **Localize o PRD** usando as regras do Step 1.1 (*path* fornecido pelo usuário, `docs/PRD.md`, `PRD.md`, ou similares). Se nenhum *PRD* for encontrado, pare e direcione o usuário ao `prd-writer-for-complete-project`. Se existirem múltiplos *PRDs* plausíveis, pergunte ao usuário qual utilizar ANTES de continuar — esta é a primeira pausa interativa possível no *orchestrator*.
- Faça o *parsing* do *input* em uma lista de *target features* (expanda *waves*, faça *merge* de listas, remova duplicatas).
- Se o *PRD* não tiver subseção `Execution Waves` (`Appendix A`, ou Seção 8 em PRDs antigos) e o *input* referenciar uma *wave* (ex: `wave 3`), rejeite com: "Referências a wave exigem a subseção `Execution Waves` no PRD, que este PRD não tem. Use os IDs das features diretamente ou atualize o PRD." Não tente sintetizar *waves*.
- Se o nome de alguma *feature* no *input* for ambíguo (corresponde a múltiplas *features* no *PRD*, ex: "upload" corresponde a F03 e F11), liste as candidatas para o usuário e peça a desambiguação ANTES de prosseguir para o restante de B.1. Esta é a segunda pausa interativa possível antes do plano consolidado.
- Se qualquer ID ou nome de *feature* não existir no *PRD*, rejeite com a lista das *features* disponíveis.
- Valide a regra de *same-wave*.
- Para cada *target*, verifique se `docs/<feature-id>-<kebab-name>/spec.md`, `plan.md` ou `contract.md` já existem. Marque essas *features* como "já tem spec/plan/contract" (tratados como uma unidade — os três arquivos compartilham o ciclo de vida).

**B.2: Classificação de Greenfield e Foundation**

Aplique o *Foundation state detection* do Step 1.2 uma vez para todo o *batch*. Classifique cada *target feature* como:
- **Foundation, not implemented** → deve rodar de forma sequencial (o *scaffolding* compartilhado impede o paralelismo).
- **Non-Foundation, ou Foundation já implementado** → elegível para o *pool* em paralelo.

**B.3: Dependency readiness**

Para cada *target feature*, verifique suas dependências do *PRD* (`Dependency Graph` no `Appendix A`). Se uma dependência não estiver implementada E não estiver ela própria no *batch* atual, marque a *feature* como "dependência ausente — vai abortar". Dependências satisfeitas por outras *features* no mesmo *batch* são aceitáveis (elas terão suas *specs* geradas juntas; a ordem de implementação é decisão do usuário).

**B.4: Apresentar o plan consolidado e aguardar confirmação**

Mostre o *plan* e aguarde a confirmação explícita. *Template default*:

```
Plano do batch para <input>:
- F04 Video Library (só o Core) — nova
- F07 Background Processing Pipeline (escopo completo) — já tem spec (pular / regenerar?)
- F12 Administration Panel (escopo completo — sem divisão Core/Full) — nova

Modo: paralelo (N sub-agents)   # ou "sequencial (Foundation detectada)" quando aplicável
Estado da codebase: Foundation complete   # ou greenfield / Partial Foundation
Auto-accept: todas as recomendações do spec-writer serão aplicadas
Destino: docs/F04-video-library/, docs/F07-background-processing-pipeline/, docs/F12-administration-panel/

Posso prosseguir? (sim/não)
```

*Tag* de *scope* por *feature* (escolha a certa por formato de *PRD*):
- `(só o Core)` — o *PRD* da *feature* possui ambos os blocos `Core Scope` e `Full Scope additions` (O *Auto-Accept* escolhe Core).
- `(escopo completo)` — o *PRD* da *feature* possui apenas um dos blocos de *scope*, então Core e Full são o mesmo.
- `(escopo completo — sem divisão Core/Full)` — o *PRD* da *feature* não possui nenhum dos blocos; a *feature* inteira está no *scope*.

*Tags* de status por *feature*: `nova`, `já tem spec (pular / regenerar?)`, `dependência ausente — vai abortar`, `Foundation, roda em série`, `Foundation já implementada, pulando`.

Prossiga apenas com um "sim" explícito (`yes` também vale). Diante de um "não" ou qualquer resposta negativa/ambígua, aborte o processo de forma limpa, sem fazer *dispatch* dos *sub-agents* e sem criar nenhum arquivo. Se o usuário quiser alterar o *plan*, ele re-invoca a *skill* com o *input* atualizado. As *features* marcadas como "já tem spec" são ignoradas por padrão; o usuário pode solicitar a regeneração na resposta de confirmação (ex.: "sim, regenerar F07").

**Pergunta de criação de issue (apenas quando a *flag* `create-issue` NÃO estava no *input* do *batch*):** depois que o usuário responder "sim" ao *plan* consolidado acima, faça uma pergunta adicional: `"Criar também uma issue no <GitHub|GitLab> para cada feature deste batch? (s/n)"`, nomeando o forge resolvido conforme `${CLAUDE_PLUGIN_ROOT}/references/forge.md`. A resposta vale para **todas** as *features* do *batch* — os *sub-agents* não perguntam individualmente. Registre a resposta:
- `s` / `sim` / `y` / `yes` → defina a *flag* `create-issue` e encaminhe-a no *prompt* de todos os *sub-agents* em B.5.
- qualquer outra coisa → não encaminhe; os *sub-agents* pulam a criação de *issue* do Step 6.

Se `create-issue` já estava no *input* do *batch*, pule esta pergunta e encaminhe a *flag* a todos os *sub-agents* incondicionalmente.

**B.5: Dispatch dos sub-agents**

- **Fase sequencial (somente Foundations, quando greenfield ou Partial Foundation):** faça o *dispatch* dos *sub-agents* de *Foundation* um por vez, aguardando que cada um complete antes de iniciar o próximo, na ordem em que aparecem em `Foundation Features` (`Appendix A` do PRD).
- **Fase paralela:** faça o *dispatch* de todos os *sub-agents* restantes em uma única mensagem com múltiplas chamadas da *tool* Agent, sem limite de concorrência.
- O *prompt* de cada *sub-agent* inclui:
  - O ID da *target feature* e o *path* do *PRD*
  - Instrução para executar os Steps 1–7 deste SKILL.md para aquela *feature*
  - A *Auto-Accept Policy* abaixo, substituindo a entrevista interativa (Step 2)
  - Lembrete para salvar `spec.md`, `plan.md` e `contract.md` conforme o Step 5, e para aplicar o *hard coverage gate* do contrato (abortar os três em caso de lacuna)
  - A *flag* `create-issue`, quando o usuário optou por ela em B.4

Cada *sub-agent* realiza seu próprio *Pattern Discovery* (Step 1.3) de forma independente — sem compartilhamento entre *sub-agents*.

**B.6: Coletar e relatar**

Aguarde todos os *sub-agents*. Relate o resultado consolidado:

```
Batch concluído: 3/4 features geradas com sucesso
✓ F04 → docs/F04-video-library/
✓ F07 → docs/F07-background-processing-pipeline/
✓ F12 → docs/F12-administration-panel/
✗ F05 → falhou: <motivo>
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
| Conjunto de superfícies do contrato ambíguo (o PRD não indica claramente HTTP vs UI vs ambos) | Emita todas as superfícies com ao menos um sinal no PRD (Capabilities, Experience, Provides); documente a escolha em Assumptions |
| Esclarecimento de quality gates (Step 2 — gates detectados) | Inclua automaticamente todos os *gates* detectados, aplicando a regra do *wrapper* do Step 2, sem perguntar; documente a lista em Assumptions para que o usuário possa revisar e fazer *override* depois. NÃO bloqueie. |
| Esclarecimento de quality gates (Step 2 — nenhum gate detectado) | Omita a seção `## Quality gates` por inteiro; documente a ausência em Assumptions ("nenhum quality gate detectado no projeto; seção omitida"). NÃO bloqueie. |
| Criação de issue (Step 6 — flag `create-issue` ausente) | O *orchestrator* já resolveu isso em B.4 (perguntou uma vez e propagou a todos os *sub-agents*). O *sub-agent* trata a ausência aqui como "não criar"; o *orchestrator* só encaminha `create-issue` quando o usuário optou por criar em B.4. NÃO pergunte; NÃO crie em silêncio. |
| Criação de issue (Step 6 — flag `create-issue` presente, encaminhada pelo orchestrator) | Crie a *issue* conforme o Step 6, sem perguntar. Em caso de falha do CLI do forge, registre em `Soft-fails` (espelhando a regra do Step 6.5); NÃO bloqueie o sucesso do *sub-agent*. |
| Falha do hard coverage gate do contrato em Batch Mode | O *sub-agent* falha a *feature* (nenhum arquivo salvo). Reportado ao *orchestrator* como qualquer outra falha (B.6) para que o usuário investigue |

Todas as outras regras do spec-writer (conteúdo *PRD-driven*, aderência aos *codebase patterns*, validação SPEC/PLAN/CONTRACT, nomenclatura *kebab-case*, *file structure*) se aplicam sem alterações.

**Requisito de documentação:** toda vez que um *sub-agent* aplica um *default* da *Auto-Accept* para uma decisão que o *PRD* não respondeu, ele DEVE registrar essa decisão na tabela *Assumptions* da Spec §4 (`Technical Decisions & Assumptions`), nomeando na coluna Origem a linha da policy que a produziu, para que o usuário possa revisar e corrigir depois.

---

## Regras

**Precedência:** Quando uma *feature* está rodando em *Batch Mode*, os grupos de regras de (Batch Mode) abaixo se sobrepõem a qualquer regra conflitante nas listas gerais Always/Never — notavelmente, o *Batch Mode* sobrepõe as regras relacionadas à entrevista ("Preserve o estilo iterativo da entrevista", "Pule perguntas da entrevista…", etc.). Todas as regras não conflitantes continuam válidas.

**Sempre:**
- Gere TRÊS arquivos (*spec*, *plan* e *contract*) em `docs/<feature-id>-<kebab-name>/`
- Valide os três documentos antes de salvar
- Rode o *Codebase Pattern Discovery* em duas camadas (*baseline* + *broad*) antes da entrevista
- Leia a *target feature* do *PRD* e use Consumes/Provides/Core Scope/Full Scope/Capabilities/Experience/Error Handling/acceptance criteria como contexto primário, mais os `RNF` aplicáveis (Seção 7), as decisões de produto (Seção 8), as dependências (Seção 9) e os critérios de validação (Seção 12) quando o PRD os tiver
- O PRD é intencionalmente livre de decisões técnicas. Toda escolha de stack, arquitetura, modelagem e integração nasce aqui na spec (ou no HLD, se existir) — nunca assuma que o PRD já decidiu
- Pule perguntas da entrevista cujas respostas já estejam no *PRD*, na *codebase*, ou em *specs* anteriores
- Aplique o *mapping* PRD → SPEC consistentemente em todas as *features*
- Preserve o estilo iterativo da entrevista: uma pergunta por vez, percorra a árvore de decisões, forneça uma resposta recomendada
- Monte o *Coverage Manifest* do contrato a partir dos ACs in-scope — critérios da própria *feature* na Seção 11 e critérios de `Cross-Feature Integration` cujo `Owner` em A.6 é esta *feature* —, usando como chave da linha o texto do critério copiado do PRD, com o prefixo de ID
- Filtre os critérios da própria *feature* cuja verificação cai fora do escopo `Included` do `spec.md`; descarte-os em silêncio do *manifest* (sem aviso no console, sem itens gerados)
- Escreva o `contract.md` com conteúdo em pt-BR e âncoras estruturais em inglês, conforme a "Regra de Idioma" de `references/contract-template.md`
- Monte a seção *Prerequisites* do contrato como condições prospectivas derivadas da arquitetura da *spec* e das referências dos itens, com as **cinco subseções fixas** (Runtime services, Persistent state, Static inputs, Configuration, External dependencies). Enquadre essas condições para que sejam lidas tanto como entregas de quem constrói a *feature* (produzi-las junto com o código) quanto como pré-condições de quem exercita o contrato depois — nunca como bloqueios ao desenvolvimento antes de a *feature* existir
- Monte a seção `## Quality gates` do contrato (quando *gates* forem confirmados no esclarecimento do Step 2) entre `## Prerequisites` e `## Coverage Manifest`. Cada entrada é `- **<name>** — \`<command>\` — <descrição do que significa passar>`. Mantenha a seção agnóstica de consumidor: descreva o *gate*, nunca o executor
- Procure um *script wrapper* que execute todos os *gates* de uma vez antes de listar *scripts* individuais como *quality gates*
- Reutilize as convenções do projeto capturadas no Step 1.3 (*seeding* de estado persistente, *path* de *static inputs*/*fixtures*, configuração de teste, *mocks*) ao gerar os *Prerequisites* — um *path*/mecanismo declarado por um contrato anterior ou já presente na *codebase* é autoritativo; nunca invente alternativas ad hoc
- Mantenha `Persistent state` (entidades, contas, registros, mensagens, tokens — declarados de forma declarativa) estritamente separado de `Static inputs` (arquivos em disco no *path* de *fixtures* do projeto)
- Garanta que todo *handle* referenciado por qualquer item (nome de conta em `Persistent state`, *path* de arquivo em `Static inputs`) esteja declarado na subseção correspondente E que toda declaração tenha ao menos um item consumidor na cláusula `Used by:` (sem declarações órfãs)
- Aplique o *hard coverage gate* do contrato antes de salvar: se qualquer AC in-scope tiver zero itens cobrindo, aborte os três arquivos
- Limite os *Prerequisites* do contrato ao fecho de dependências desta *feature* no `Dependency Graph`: todo recurso declarado (Persistent state, Static inputs, Configuration, Runtime services, External dependencies) é satisfazível pela própria *feature* ou por uma de suas dependências declaradas. Quando um AC in-scope precisa de infraestrutura que só uma *feature* irmã fora do fecho normalmente produziria, aplique o **Preparation Pattern** (declare um *stub*/*override*/*flag* interno da *feature* e exija que esta *feature* o entregue como parte do próprio escopo) em vez de referenciar o estado real da *feature* irmã
- Aplique o Step 6 (Issue Creation) conforme a lógica de *flag*/pergunta documentada — com a *flag* `create-issue` presente, crie a *issue* sem perguntar; ausente no *single-feature mode* interativo, pergunte uma vez antes de criar; ausente no *Batch Mode*, trate a ausência como "não criar" (o *orchestrator* já resolveu a pergunta em B.4)
- Resolva o forge (`github` | `gitlab`) conforme `${CLAUDE_PLUGIN_ROOT}/references/forge.md` antes de qualquer operação de *issue*, e use as operações § 3.2 e § 3.3 de lá em vez de embutir comandos de CLI — o pipeline roda tanto em GitHub quanto em GitLab
- Detecte *issues* abertas existentes (`references/forge.md` § 3.2, com o filtro de título do lado do chamador) antes de criar uma nova — se houver correspondência, pule a criação e reutilize a URL da primeira na saída do spec-writer
- Trate falhas do CLI do forge durante o Step 6 como *soft-fails* — registre em `Soft-fails` na saída do spec-writer e continue; os arquivos da *spec* já foram salvos no Step 5 e não devem ser revertidos

**Nunca:**
- Coloque código real na *spec* (descreva apenas a estrutura)
- Coloque decisões de arquitetura no *plan*
- Inclua estimativas de tempo
- Crie fases de *testing* no documento de *plan*
- Inclua *metadata* de Feature ID/Data/Versão
- Inclua detalhes de implementação nos *steps* do *plan* (tipos de dados, colunas, métodos)
- Prossiga sem um *PRD* — sempre exija um e direcione o usuário para o `prd-writer-for-complete-project` caso ausente
- Faça novamente perguntas cujas respostas sejam observáveis na *codebase* ou já declaradas no *PRD*
- Restrinja a exploração da *codebase* ao *checklist* de *baseline* — o *baseline* é um piso, não um teto
- Salve a *spec* ou o *plan* quando o *coverage gate* do contrato falhar — os três são salvos juntos ou nenhum
- Emita uma tabela de mapeamento de acceptance criteria (ou qualquer linha AC ↔ teste) no `spec.md`, ou adicione uma coluna "Critério de aceite coberto" a qualquer sub-tabela da *Testing Strategy* — o *Coverage Manifest* do `contract.md` é a fonte única dessa ligação
- Anote "OUT OF SCOPE for F<ID>" dentro do `spec.md` para critérios cross-feature — o filtro é codificado em silêncio pela ausência desses critérios no *Coverage Manifest* do `contract.md`, e o `spec.md` não deve duplicar esse sinal
- Coloque critérios `(RNF<NN>)` do bloco `Non-Functional Acceptance` no *Coverage Manifest* ou em itens do contrato
- Coloque um critério de `Cross-Feature Integration` no contrato de uma *feature* que não é o `Owner` do cenário em A.6
- Emita uma seção `## Service` no `contract.md` sem um consumidor real fora desta *feature*
- Gere itens de contrato por classe, por VO, por *helper* ou por arquivo de teste — os itens descrevem comportamento de fronteira, não unidades internas
- Use sub-headers de entidade de superfície no contrato (`### POST /auth/register`, `### /login page`) — apenas vocabulário de *capability*
- Omita a linha `Verification mode:` em qualquer seção do contrato
- Edite o `contract.md` à mão depois da geração — a regeneração é integral
- Gere itens cujo comportamento depende de uma *feature* FORA do fecho de dependências desta *feature* no `Dependency Graph` — seja a jusante (uma *feature* que depende desta) ou irmã (sem aresta em nenhuma direção). Itens cujo comportamento pertence a outra *feature* vivem no contrato dela; itens cujo comportamento é desta *feature*, mas cujo *setup* de teste precisa de infraestrutura de fora, usam o *Preparation Pattern*.
- Imprima um aviso no console quando um critério cross-feature for descartado — o descarte é silencioso por design
- Descreva *Prerequisites* como retratos do estado existente — são condições prospectivas que precisam valer antes de os itens serem exercitados
- Mencione "agente implementador", "evaluator", "agente avaliador" ou qualquer consumidor específico no `contract.md` gerado — o contrato é agnóstico de consumidor
- Use comentários HTML (`<!-- ... -->`) em qualquer lugar do `contract.md` gerado — eles quebram alguns visualizadores de markdown; use a linha de regeneração em itálico abaixo do título
- Referencie um *handle* (conta, sessão, registro, *path* de arquivo) no `given`/`when` de qualquer item sem declará-lo na subseção de *Prerequisites* correspondente (`Persistent state` ou `Static inputs`)
- Misture `Persistent state` com `Static inputs` — declarar uma conta ou registro em `Static inputs`, ou um arquivo em `Persistent state`
- Escreva entradas de `Persistent state` de forma operacional ("rode esta migration", "execute este seed") em vez de declarativa ("alice existe com X atributos")
- Invente *paths* de *fixtures* em `Static inputs` quando o projeto já tem uma convenção de *path* de *fixtures* descoberta (ou um contrato anterior que declarou uma) — reutilize a convenção existente
- Divirja de uma convenção do projeto sem documentar uma Assumption explícita explicando por quê
- Declare um *Prerequisite* que exija que uma *feature* FORA do fecho de dependências desta *feature* esteja implementada (ex.: declarar `landing-returning-user` como um usuário autenticado real em `Persistent state` quando esta *feature* não depende da *feature* de *auth*). A correção é o **Preparation Pattern**: troque o *prereq* por um *stub*, *override* ou ajuste de configuração interno que esta própria *feature* entrega como parte do escopo, para que o contrato seja exercitável quando apenas esta *feature* + suas dependências declaradas estiverem implementadas
- Confunda "preparação para uma *feature* irmã" com "dependência de uma *feature* irmã". Uma *feature* PODE construir interfaces, *hooks* e *stubs* em que outras *features* vão se encaixar depois (preparação) — isso NÃO torna essas outras *features* suas dependências, e os *Prerequisites* precisam refletir essa fronteira

**Sempre (Batch Mode):**
- Valide a regra de *same-wave* antes do *dispatch*; rejeite *batches* *cross-wave*
- Apresente um *plan* consolidado e aguarde confirmação explícita antes de fazer o *dispatch* dos *sub-agents*
- Pule *features* cujos `spec.md`, `plan.md` E `contract.md` já existam, a menos que o usuário solicite explicitamente a regeneração. Se apenas um ou dois dos três estiverem presentes, trate a *feature* como incompleta e regenere o conjunto completo
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

**Nenhum PRD encontrado:** Pare e instrua o usuário a gerar um primeiro com o `prd-writer-for-complete-project`. Não rode a *skill* sem um *PRD*.

**Feature não encontrada no PRD:** Liste as *features* disponíveis na tabela `Dependency Graph` (`Appendix A` do PRD) e pergunte ao usuário qual era a intencionada.

**Referência de feature ambígua:** Se o *input* do usuário corresponder a múltiplas *features* (ex: "upload" corresponde a F03 e F11), liste os candidatos e peça para o usuário desambiguar.

**Múltiplos arquivos de PRD no projeto:** Pergunte ao usuário qual *PRD* utilizar.

**Dependência ainda não implementada:** Avise o usuário (ex.: "F08 depende de F07, que ainda não está implementada. Continuar mesmo assim?") e prossiga apenas se confirmado. A *spec* ainda pode ser gerada — a ordem de implementação é decisão do usuário.

**Codebase vazia ou apenas com scaffolding (primeira feature):** Pule o *Pattern Discovery* e faça perguntas transversais da *stack inline* no Step 2. As *features* subsequentes farão a leitura da *codebase*.

**O PRD não possui blocos Core Scope / Full Scope para a feature:** Pule a pergunta de *scope*; assuma o *scope* completo da *feature*.

**O PRD possui apenas Core Scope (sem Full Scope additions):** Assuma *scope* = Core; não pergunte.

**Descrição muito vaga:** Se a definição da *feature* no *PRD* for excepcionalmente superficial e deixar muitas decisões em aberto, vá mais a fundo na entrevista — não assuma padrões silenciosamente.

**Nenhum codebase pattern encontrado (mas codebase não está vazia):** Peça ao usuário para confirmar o uso de *industry best practices* ou fornecer uma referência.

**A feature requer novas tecnologias não presentes na codebase:** Liste as novas dependências, peça a confirmação do usuário e documente nas decisões.

**Múltiplos patterns conflitantes na codebase:** Apresente ambos, pergunte qual seguir, documente a escolha.

**PRD sem `A.6 Use Scenario Coverage`:** Nenhum critério de `Cross-Feature Integration` entra no contrato desta *feature*. Siga com os critérios da própria *feature* e registre a lacuna nas *assumptions* da *spec*.

**Limpeza do nome da feature para kebab-case:** use minúsculas, substitua espaços por hifens, remova caracteres fora de `[a-z0-9-]`. Exemplo: `F07. Background Video Processing Pipeline` → `F07-background-video-processing-pipeline`.

**Input de batch cross-wave:** Rejeite com uma mensagem apontando para `Execution Waves` (`Appendix A` do PRD) e explicando que as *waves* rodam sequencialmente para que a *codebase* acumule *patterns* entre elas. Não divida automaticamente em dois *batches* — o usuário deve rodar a *wave* anterior primeiro, implementá-la, para então rodar a próxima.

**Referência de wave desconhecida:** Liste as *waves* disponíveis em `Execution Waves` (`Appendix A` do PRD) e peça para o usuário esclarecer.

**O batch contém uma feature que já possui spec:** O *plan* consolidado a sinaliza como "já tem spec"; o padrão é pular (*skip*). O usuário pode solicitar a regeneração explicitamente na resposta de confirmação.

**O batch contém uma feature cuja dependência externa não está implementada:** Marque a *feature* como "dependência ausente — vai abortar" no *plan*; gere as *specs* para as *features* restantes e reporte a que foi abortada no resultado final. Dependências satisfeitas por outra *feature* no mesmo *batch* não contam como não implementadas.

**Batch com múltiplas Foundation features em um projeto greenfield:** As *Foundations* rodam sequencialmente na ordem em que aparecem em `Foundation Features` (`Appendix A` do PRD). O *plan* afirma isso explicitamente ("Modo: sequencial (Foundation detectada)"). *Features* não-*Foundation* no mesmo *batch* ainda rodam em paralelo após as *Foundations* finalizarem.

**Falha de sub-agent no batch:** Os outros *sub-agents* continuam até a conclusão. O relatório final lista os sucessos e as falhas com os motivos. As *features* que falharam podem ser rodadas individualmente ou como um *batch* menor.

**PRD sem subseção "Execution Waves" no batch mode:** As referências de *waves* (`wave N`) requerem esta subseção para serem expandidas em *features*. Rejeite com: "Referências a wave exigem a subseção `Execution Waves` no PRD (`Appendix A`). Este PRD não tem uma. Use os IDs das features diretamente ou atualize o PRD." Não tente sintetizar as *waves*.

**O usuário recusa o plan consolidado (responde "não" no B.4):** Aborte o processo de forma limpa. Nenhum *sub-agent* despachado, nenhum arquivo criado, nenhum estado parcial deixado para trás. O usuário re-invoca a *skill* com *input* ajustado.
