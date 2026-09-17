# Contract Template

Cada feature produz um arquivo `contract.md` ao lado de `spec.md` e `plan.md`. O contrato é uma especificação agnóstica de stack e de consumidor, só de comportamento, do que a feature promete. Dois leitores distintos costumam consumi-lo: um que produz a implementação (usa o contrato como checklist de comportamento esperado) e outro que verifica a implementação (usa o contrato como contrato de asserções). Nenhum dos dois papéis é nomeado dentro do arquivo gerado; o contrato apenas descreve comportamento.

O `contract.md` é a **interface** entre esses dois leitores. O formato abaixo é a única coisa em que eles precisam concordar; todo o resto (test runners, navegadores, fixtures) fica a cargo de quem exercita o contrato.

---

## Identidade do Arquivo

| Propriedade | Valor |
|---|---|
| Path | `docs/<feature-id>-<kebab-name>/contract.md` (irmão de `spec.md` e `plan.md`) |
| Gerado por | `spec-writer`, na mesma execução que `spec.md` e `plan.md` |
| Fonte da verdade | Conteúdo do PRD para esta feature: critérios de aceite da feature na Seção 11 (Seção 9 em PRDs antigos) e critérios de `Cross-Feature Integration` cujo `Owner` em `A.6 Use Scenario Coverage` é esta feature (alimentam o Coverage Manifest); mais `Capabilities`, `Experience` e `Error Handling` (alimentam a geração de itens). Irmão de `spec.md`, não derivado dele. |
| Ciclo de vida | Somente leitura após a geração. A regeneração é integral (re-execute o `spec-writer`). Relatórios vão para outros arquivos (`eval-report.md`), nunca para este. |
| Edição manual | Não suportada. A próxima regeneração sobrescreve as edições. |

---

## Regra de Idioma

O conteúdo do contrato gerado é escrito em **português (pt-BR)**. Permanecem em **inglês**, literalmente, apenas os elementos estruturais que outras skills localizam no documento:

- Título: `# Contract: <Nome da Feature>`
- Seções: `## Prerequisites`, `## Quality gates`, `## Coverage Manifest`, e as superfícies `## Service`, `## HTTP API`, `## CLI`, `## UI`, `## Worker`, `## Event`, `## E2E`, `## Manual` (e qualquer superfície nova adicionada ao catálogo)
- Labels das subseções de Prerequisites: `**Runtime services:**`, `**Persistent state:**`, `**Static inputs:**`, `**Configuration:**`, `**External dependencies:**`
- Labels de linha: `**Verification mode:**`, `**Common given:**`, `Used by:`
- Campos do item: `id`, `given`, `when`, `then`, `notes`; e o marcador `(default)`
- Sub-headers de capability (`### Register`, `### Login`) e, portanto, os IDs dos itens (`API-REGISTER-01`)
- Cabeçalho da tabela do manifest: `| PRD Acceptance Criterion | Covered by |`
- O valor de `notes` para itens subjetivos: `subjective; manual review only`

Tudo o mais é pt-BR: a linha de regeneração, os preâmbulos, o texto de `Verification mode`, o texto de `given`/`when`/`then`/`notes`, as declarações de Prerequisites e as descrições dos quality gates. A primeira coluna do Coverage Manifest é o texto do PRD copiado como está (portanto em pt-BR). Termos técnicos consagrados (status HTTP, nomes de headers, cookies, rotas, comandos) permanecem como são dentro do texto em português.

---

## Estrutura do Documento

```markdown
# Contract: <Nome da Feature>

*Gerado pelo spec-writer. Edições manuais são sobrescritas na regeneração.*

## Prerequisites
<cinco subseções fixas, nesta ordem, com as subseções vazias omitidas por inteiro:>
<  Runtime services, Persistent state, Static inputs, Configuration, External dependencies>

## Quality gates
<preâmbulo de um parágrafo: "Cada gate precisa passar para a feature ser considerada pronta."
 depois uma lista, um bullet por gate, no formato:
   - **<name>** — `<command>` — <descrição de uma linha do que significa passar>
 omita a seção inteira quando nenhum gate foi confirmado no esclarecimento do Step 2>

## Coverage Manifest
<tabela mapeando cada AC in-scope do PRD para esta feature → IDs dos itens que o cobrem>

## <Superfície 1>
**Verification mode:** <uma linha>

### <Capability A>
**Common given:** <pré-condição compartilhada pelos itens desta capability — a linha é omitida por inteiro quando a capability não tem pré-condição compartilhada>

#### `<ITEM-ID-01>` — <rótulo curto>
- given: <pré-condição>
- when: <uma única ação atômica>
- then:
  - <consequência observável>
  - <consequência observável>
- notes: <contexto opcional de uma linha>

#### `<ITEM-ID-02>` — ...

### <Capability B>
...

## <Superfície 2>
...
```

As seções aparecem nesta ordem: título, linha de regeneração em itálico, **Prerequisites**, **Quality gates** (quando presente), **Coverage Manifest**, depois as seções de superfície na ordem do catálogo (Service, HTTP API, CLI, UI, Worker, Event, E2E). As capabilities aparecem na ordem do PRD dentro de cada superfície. Os itens aparecem em NN crescente dentro de cada capability.

O contrato gerado é **agnóstico de consumidor no conteúdo**: descreve o comportamento a verificar e nunca nomeia qual agente ou ferramenta vai lê-lo ou executá-lo. Referências a "agente implementador" ou "agente avaliador" pertencem apenas à meta-documentação deste template, não aos arquivos `contract.md` gerados.

---

## Surface Catalog

As seções de primeiro nível são superfícies de avaliação, não camadas de arquitetura. Emita apenas as superfícies que a feature realmente tem. Cada seção declara seu `Verification mode` para que qualquer consumidor do contrato saiba como executar os itens daquela seção.

| Superfície | Quando aparece | Texto default de `Verification mode` |
|---|---|---|
| `## Service` | A feature expõe uma interface programática com um consumidor real fora desta feature (outra feature, biblioteca, SDK, plugin host). Veja a **Service Admission Rule** abaixo. | "Invocar a função/método público diretamente, no mesmo processo; verificar o valor retornado, o erro lançado ou o efeito persistido sobre o estado fornecido." |
| `## HTTP API` | A feature expõe endpoints de rede (REST/RPC/GraphQL). | "Enviar uma requisição HTTP ao serviço em execução; verificar status, headers, body e qualquer efeito persistido direto." |
| `## CLI` | A feature entrega uma ferramenta de linha de comando. | "Executar o binário com os argumentos e o stdin indicados; verificar stdout, stderr e exit code." |
| `## UI` | A feature entrega uma superfície para humanos (web, mobile, desktop, TUI). | "Renderizar a superfície, conduzi-la com entradas de usuário (cliques, digitação, gestos); verificar o estado observável da superfície (DOM, árvore de acessibilidade, texto visível, navegação)." |
| `## Worker` | A feature tem processamento assíncrono/em background (fila de jobs, scheduler, consumer). | "Enfileirar ou disparar a entrada; observar o efeito no sistema depois que o processamento termina." |
| `## Event` | A feature publica ou assina um barramento de eventos/mensagens. | "Publicar o evento (ou disparar sua origem); observar handlers, projeções e efeitos a jusante." |
| `## E2E` | A feature tem ao menos uma capability que atravessa superfícies e só faz sentido ponta a ponta. | "Executar o sistema completo; conduzi-lo como um usuário real faria; verificar o comportamento entre as camadas." |

O catálogo é aberto. Adicione uma nova superfície quando um consumidor genuinamente exercitaria aquela categoria de forma diferente de todas as existentes (ex.: `## WebSocket`, `## MCP`). Superfícies novas precisam declarar sua própria linha `Verification mode`.

### Service Admission Rule

`## Service` aparece apenas quando existe um consumidor real **fora desta feature** que chama uma interface programática definida aqui.

Qualifica:
- Feature de biblioteca/SDK em que a API pública é a entrega.
- Um use case ou serviço consumido por outra feature explicitamente nomeada como dependência na tabela `Dependency Graph` do PRD (`Appendix A` → A.2; Seção 8 em PRDs antigos) — um bloco de construção cujo consumidor a jusante está documentado, não é hipotético.
- Plugin host que expõe uma API para plugins.
- Serviço gRPC/RPC interno consumido por outros sistemas.

Não qualifica:
- Helpers internos, value objects, entities, repositories, mappers — detalhes de implementação de `## HTTP API`, `## UI` etc.
- Use cases invocados apenas pelos próprios handlers desta feature.

Se você não consegue nomear um consumidor fora desta feature, não emita `## Service`.

### Anti-regra para itens

Os itens do contrato descrevem **comportamento observável na fronteira externa da feature**. Eles NÃO são:
- por classe, por arquivo, por método, por VO, por entity, por helper
- por arquivo de teste, por função de teste

A cobertura de unidades internas pertence à Estratégia de Testing do `spec.md`, não ao `contract.md`.

---

## Hierarquia

Dois níveis por padrão:

```
## <Superfície>
### <Capability>
#### <Bloco GWT do item>
```

Adicione um terceiro nível apenas quando uma única capability for genuinamente grande (≥ ~10 itens coesos que se agrupam naturalmente):

```
## UI
### Player Controls
#### Keyboard shortcuts
##### `UI-PLAYER-KEYBOARD-01` — ...
```

Os sub-headers carregam **vocabulário de capability** (intenção comportamental: "Register", "Login", "Search transcript"), não vocabulário de entidade de superfície (paths de rota, paths de página, nomes de comando). O mesmo nome de capability, portanto, aparece em `## HTTP API > Register`, `## UI > Register` e `## E2E > Register`, e qualquer consumidor consegue correlacionar as superfícies pelo nome. Os sub-headers são escritos em inglês (veja a Regra de Idioma). Os detalhes de entidade de superfície (`POST /auth/register`, a página `/register`) ficam no `when:` de cada item.

---

## Item Schema

Todo item é um bloco Given/When/Then com um ID estável:

```yaml
- id: <SURFACE>-<CAPABILITY>-<NN>
  given: <pré-condição declarativa>
  when: <uma única ação atômica>
  then:
    - <consequência observável — técnica ou de negócio — em linguagem instrutiva>
    - <...>
  notes: <contexto opcional de uma linha>
```

| Campo | Obrigatório | Conteúdo |
|---|---|---|
| `id` | sim | `<SURFACE>-<CAPABILITY>-<NN>`. Código de superfície do catálogo (`SVC`, `API`, `CLI`, `UI`, `WRK`, `EVT`, `E2E`). O código de capability é em MAIÚSCULAS, tokens separados por hífen, derivados do rótulo da capability (ex.: "Register" → `REGISTER`; "Player Controls > Keyboard" → `PLAYER-KEYBOARD`). NN é uma sequência de dois dígitos com zero à esquerda dentro da capability (`01`, `02`, ...). O ID da feature NÃO faz parte do ID do item — a pasta já desambigua. |
| `given` | sim | Pré-condição declarativa: o estado em que o sistema precisa estar antes do `when`. O consumidor decide operacionalmente como chegar a esse estado. Não escreva passos de setup aqui. |
| `when` | sim | Exatamente uma ação atômica. A coisa cujas consequências o `then` vai verificar. |
| `then` | sim | Lista das consequências observáveis esperadas. Pode incluir asserções técnicas (status, body, header, estado do DOM) E regras de negócio em linguagem de domínio. Veja os guard-rails abaixo. |
| `notes` | opcional | Uma linha de contexto que afeta a interpretação mas não cabe no formato GWT. Exemplos: `subjective; manual review only`, `requer TZ=UTC`, `verificar em até 500ms após o disparo`. Use com parcimônia — excesso sinaliza que o item deveria ser dividido. |

**Ordem dos campos na saída renderizada:** `id`, `given`, `when`, `then`, `notes` (quando presente). Embora mapeamentos YAML sejam semanticamente não ordenados, os itens são renderizados exatamente nesta sequência para que o arquivo tenha diffs previsíveis e humanos/agentes leiam os itens sempre do mesmo jeito.

### Guard-rails no `then`

Para evitar que os itens degenerem em checklists longos que escondem sub-tarefas:

1. **Coesão de superfície.** Toda asserção do `then` é verificável pelo `Verification mode` da seção. Se for preciso trocar de superfície (ex.: um item HTTP que também espia o banco), mova a verificação cross-superfície para um item de `## Service` ou de `## E2E`.
2. **Atomicidade da ação.** `when` é uma ação; `then` lista seus observáveis diretos e imediatos. Efeitos assíncronos/atrasados pertencem a itens de `## Worker` ou `## Event`, não a bullets aqui.
3. **Soft cap de ~5 bullets.** Acima de 5, emita um aviso em tempo de geração ("`<ID>` tem N asserções no `then`; considere dividir"). Limite rígido ~10. O cap existe para forçar a reflexão "isto é mesmo uma única ação?".
4. **Bullet atômico.** Cada bullet é uma observação. Agrupamento estrutural é permitido (`body { user.id, user.email }` — uma observação de forma). Observações conjugadas não são (`status 201 e cookie definido e registro persistido` — três observações contrabandeadas em um bullet).

### Common given

Quando vários itens de uma capability compartilham uma pré-condição, declare-a uma vez no nível da capability:

```markdown
### Login

**Common given:** existe um usuário com e-mail "alice@example.com" e senha "Pass1234"; não há sessão ativa para esse usuário.

#### `API-LOGIN-01` — caminho feliz
- given: (default)
- when: POST /auth/login com credenciais válidas
- then:
  - 200 OK com body { user: { id, email, lastLoginAt: não nulo } }
  - Set-Cookie session_token

#### `API-LOGIN-02` — senha errada
- given: (default), e a senha informada é "wrong"
- when: POST /auth/login com essa senha
- then:
  - 401 INVALID_CREDENTIALS
  - nenhum Set-Cookie
```

Itens que herdam sem mudança escrevem `given: (default)`. Itens que estendem escrevem `given: (default), e <extensão>`. Itens com pré-condições totalmente distintas ignoram a comum e escrevem seu próprio `given:` completo.

---

## Coverage Manifest

A segunda seção `##` abaixo do título, logo após `## Prerequisites` (ou após `## Quality gates`, quando presente). Mapeia cada critério de aceite **in-scope** para os itens do contrato que o cobrem.

Os critérios in-scope vêm de duas origens do PRD:
1. **Critérios da própria feature** — o bloco `### F<ID>. <Nome>` da Seção 11 `Acceptance Criteria` (Seção 9 em PRDs antigos) que sobreviveram ao filtro silencioso de escopo descrito nas regras abaixo.
2. **Critérios de `Cross-Feature Integration` desta feature** — os critérios `(UC<NN>)` da Seção 11 cujo cenário tem esta feature na coluna `Owner` da tabela `A.6 Use Scenario Coverage` do `Appendix A`. A dona é a feature, entre as envolvidas no cenário, cujo fecho de dependências contém todas as outras; por isso o cenário é exercitável com esta feature + seu fecho implementados.

Critérios do bloco `Non-Functional Acceptance` (`(RNF<NN>)`) **nunca** entram no manifest — eles são tratados na `spec.md` (Requirements, decisões técnicas e Estratégia de Testing) e na Seção 12 do PRD.

```markdown
## Coverage Manifest

| PRD Acceptance Criterion | Covered by |
|---|---|
| <texto do AC no PRD, copiado como está> | ITEM-ID-01, ITEM-ID-02 |
| <próximo AC>                             | ITEM-ID-03 |
```

Regras:
- A primeira coluna é o **texto do AC copiado do PRD como está**: tudo o que vem depois de `- [ ] ` na linha do critério, **incluindo o prefixo de ID** (ex.: `(RF01.1) O cadastro é concluído com e-mail corporativo válido e senha de 10+ caracteres`; `(UC01) O analista localiza um trecho por busca...`). O texto é o identificador estável — o mesmo `RF` pode ter vários critérios, então o prefixo sozinho não identifica a linha. Se a redação do PRD mudar, a linha do manifest muda visivelmente na regeneração. A deriva é endereçável pelo conteúdo.
- A segunda coluna lista os IDs dos itens do contrato (separados por vírgula) cujo `then` verifica diretamente a afirmação do AC.
- Um item pode aparecer em várias linhas (cobre vários ACs). Um AC in-scope precisa ter ≥ 1 item.
- Critérios de `Cross-Feature Integration` entram apenas no manifest da feature que é `Owner` do cenário em `A.6`. No contrato das demais features envolvidas, eles não aparecem. Sem `A.6` no PRD (PRD antigo ou gerado antes desta tabela existir), nenhum critério de `Cross-Feature Integration` entra em contrato algum.
- **ACs da própria feature fora do escopo são descartados silenciosamente do manifest.** Um AC da Seção 11 para esta feature está fora do escopo quando seu comportamento cai fora do bloco `Included` da `spec.md` da feature (tipicamente porque a verificação pertence a uma feature a jusante no `Dependency Graph` — ex.: um AC de "falha na etapa de validação" anexado a uma feature de upload cuja etapa de validação é de uma feature posterior do pipeline — ou porque o AC atende uma `Full Scope addition` que ficou em `Deferred`). ACs descartados não aparecem no manifest, não geram itens e não emitem aviso no console **pelo descarte em si**. O princípio: todo item deste contrato precisa ser testável com esta feature + suas dependências implementadas; ACs que exigem features a jusante para serem verificados não podem estar neste contrato. (Essa regra de silêncio vale especificamente para o descarte de AC. Outros sinais de geração — como o aviso de soft cap do `then` — não são afetados e continuam sendo impressos.) Os critérios de `Cross-Feature Integration` atribuídos a esta feature em `A.6` não passam por esse filtro: a atribuição já garante que são exercitáveis com o fecho de dependências.

### Hard coverage gate

O `spec-writer` valida o manifest no Step 5 (Validate e Save). Se qualquer AC **in-scope** (um critério da própria feature que sobreviveu ao filtro de escopo, ou um critério de `Cross-Feature Integration` atribuído a esta feature em `A.6`) tiver zero itens cobrindo, a skill aborta e não salva nada (nem spec, nem plan, nem contract):

```
ERROR: contract coverage gap for F<ID>. The following in-scope PRD acceptance
criteria have no covering item:
  - "<texto do AC>"
  - "<texto do AC>"
Either generate covering items, or revise the PRD/spec if the AC is no longer
applicable to this feature.
```

Abortar os três arquivos (e não só o contrato) mantém a pasta da feature consistente — nunca existe um `spec.md` cujo contrato foi pulado em silêncio. ACs fora do escopo (descartados pelo filtro silencioso) NÃO estão sujeitos ao gate; o gate só garante a cobertura do que entrou no manifest.

Para ACs inerentemente subjetivos (identidade visual, julgamento qualitativo), gere um item placeholder com `notes: subjective; manual review only`. O placeholder satisfaz o gate; se ele é verificável de forma significativa é uma questão de revisão humana. Coloque o placeholder sob a superfície mais alinhada ao vocabulário do AC (um AC "parece com X" vai sob `## UI`; um AC "responde de forma ágil" de uma API vai sob `## HTTP API`). Quando nenhuma superfície servir, emita uma seção `## Manual` com `Verification mode: Revisão humana contra o PRD; nenhuma asserção automatizada é possível.` e coloque o placeholder lá.

---

## Prerequisites

A primeira seção `##` abaixo do título (a linha de regeneração em itálico não é uma seção). Declara **condições prospectivas** que o contrato assume quando os itens são exercitados. O contrato é gerado antes de a implementação existir, então essas condições NÃO estão atendidas no momento da geração — produzi-las faz parte da entrega da feature, junto com o próprio código.

Duas leituras desta seção, ambas sustentadas pelo mesmo texto:
- **Para quem constrói a feature:** os itens daqui fazem parte do trabalho — produzir o runtime, entregar as fixtures, definir a configuração. Um contrato cujos prerequisites ainda não existem não está "reprovado"; está "ainda não pronto para verificar".
- **Para quem exercita o contrato depois:** verifique que cada condição vale antes de executar qualquer item. Se algo estiver faltando, a resposta não é "o contrato está errado", e sim "a feature ainda não está terminada" — pare e reporte.

O texto gerado da seção é agnóstico de consumidor. Ele não diz "o agente implementador deve fazer X" nem "o avaliador verifica Y" — essas formulações pertencem apenas à meta-documentação deste template. O arquivo gerado apenas declara as condições, e o enquadramento do preâmbulo mantém as duas leituras abertas.

```markdown
## Prerequisites

Estas condições descrevem o ambiente em que os itens deste contrato
são exercitados. Produzi-las faz parte da entrega da feature, junto
com a própria implementação — um contrato cujos prerequisites ainda
não estão atendidos não está falhando, ainda está sendo construído.
Depois que a feature for entregue, qualquer condição ausente interrompe
a execução dos itens até ser restaurada.

**Runtime services:**
- <cada processo de longa duração ou binário instalado que o contrato assume>

**Persistent state:**
- <cada entidade, conta, registro, mensagem ou token que precisa existir no sistema antes de os itens rodarem; declarado como O QUE precisa existir, não COMO semear>

**Static inputs:**
- `<path-seguindo-a-convenção-de-fixtures-do-projeto>` — <especificação do formato>. Used by: <lista de IDs de itens>.

**Configuration:**
- <cada env var, flag ou configuração de runtime que os itens assumem>

**External dependencies:**
- <cada dependência de rede/sandbox/mock que os itens assumem; a subseção inteira é omitida quando não há nenhuma>
```

### Subseções

Cinco subseções fixas, sempre nesta ordem. Omita a subseção por inteiro quando nada se aplicar (sem placeholder "nenhum.").

| Subseção | Cobre | O que a convenção descoberta do projeto dita |
|---|---|---|
| `Runtime services` | processos de longa duração, daemons, binários no PATH de que os itens dependem (backend, DB, broker, navegador, ferramentas de CLI) | como o projeto sobe serviços para testes (arquivo compose, script npm etc.) |
| `Persistent state` | entidades, contas, registros, mensagens de fila, sessões, tokens, projeções — tudo o que precisa existir *dentro* do store/fila/cache do sistema antes de os itens rodarem. Declarado de forma declarativa ("alice existe com e-mail X, ativa") — nunca operacional ("rode este SQL"). | a convenção de seeding do projeto: migration + arquivo de seed, factories, setup hooks, helpers de INSERT etc. O contrato declara O QUE precisa ser verdade; o implementador cumpre do jeito que este projeto já cumpre estados semelhantes. |
| `Static inputs` | arquivos que os itens referenciam por handle: amostras de vídeo, payloads JSON, entradas CSV, arquivos de token assinado etc. — tudo o que vive em disco num path controlado pelo projeto. Cada entrada: `<path>` — `<especificação do formato>`. Used by: `<lista de IDs de itens>`. | a convenção de path de fixtures do projeto (`tests/fixtures/`, `__fixtures__/`, `fixtures/`, `cypress/fixtures/` etc.) descoberta no Pattern Discovery. O path é reutilizado por todas as features; nunca inventado. |
| `Configuration` | env vars, flags de runtime, configurações que os itens assumem | a convenção de configuração de teste do projeto (`.env.test`, `config/test/`, blocos específicos do framework) |
| `External dependencies` | acesso à rede, sandboxes de terceiros, mock servers, APIs pagas de que os itens dependem | a convenção de mocks do projeto (`tests/mocks/`, handlers MSW etc.) quando os itens exigem externos simulados |

`Persistent state` e `Static inputs` são deliberadamente separados. Parecem semelhantes, mas vivem em lugares opostos: o estado persistente passa pelo mecanismo de seeding do projeto; os static inputs vivem como arquivos em disco. Misturá-los (a abordagem anterior de "Fixtures") obrigava o implementador a adivinhar o mecanismo; separá-los elimina a adivinhação.

### Regras de geração

A skill deriva os Prerequisites sem inspecionar o filesystem (a implementação ainda não existe), mas **consulta** as convenções do projeto capturadas no Pattern Discovery (Step 1.3), para que paths e mecanismos se alinhem ao que o projeto já faz.

Origens por subseção:

- **Runtime services** — leia `Impacto na Architecture` e `Component Overview` da spec. Cada serviço de longa duração ou binário necessário vira uma linha.
- **Persistent state** — percorra `given` e `when` de todos os itens gerados; cada entidade, conta, sessão, token, registro ou mensagem de fila nomeada vira uma entrada. Cada entrada declara O QUE precisa existir (atributos declarativos); nunca COMO semear. Deduplique por handle. Cite os itens consumidores na cláusula `Used by:`.
- **Static inputs** — percorra `given` e `when` de todos os itens gerados; cada arquivo nomeado vira uma entrada. O path segue a convenção de path de fixtures descoberta no Pattern Discovery (NUNCA invente paths ad hoc). Para arquivos cujo formato exato não está fixado pela spec, aplique defaults padrão de mercado proporcionais ao domínio da feature e documente em Assumptions da spec.
- **Configuration** — leia as Technical Decisions da spec, a seção de ambiente e quaisquer constantes de cookie/header que os itens referenciem.
- **External dependencies** — emita apenas quando um item exigir explicitamente saída de rede, sandbox ou mock; caso contrário, omita a subseção.

As referências dos itens aos prerequisites usam o mesmo handle declarado aqui. Exemplos: `given: alice está logada` resolve para a entrada de `Persistent state` de alice; `when: POST /upload com tests/fixtures/sample.mp4` resolve para a entrada de `Static inputs` desse arquivo. O consumidor lê os Prerequisites primeiro e então executa os itens sabendo a resolução de cada handle.

### Descoberta de convenções do projeto (o princípio de reuso)

Paths e mecanismos em Prerequisites são específicos do projeto por necessidade (um path é sempre específico do projeto). Para mantê-los consistentes entre features e evitar dispersão, o Pattern Discovery (Step 1.3) captura quatro convenções na spec da primeira feature e as reutiliza em todas as seguintes:

1. **Convenção de seeding de estado persistente** — o projeto usa migrations + arquivos de seed, factory functions, setup hooks, helpers de INSERT ou outra coisa? Descoberta inspecionando o código de setup de testes existente, as pastas de seed/migration e os arquivos de factory.
2. **Convenção de path de static inputs / fixtures** — `tests/fixtures/`, `__fixtures__/`, `fixtures/`, `cypress/fixtures/`, `playwright/fixtures/` etc. Descoberta listando as pastas de fixtures existentes e (quando houver) lendo os `contract.md` anteriores em `docs/F*-*/` para ver qual path declararam.
3. **Convenção de configuração de teste** — `.env.test`, `config/test/`, blocos específicos do framework. Descoberta listando os arquivos de configuração e inspecionando as configs do test runner.
4. **Convenção de mocks / dependências externas** — `tests/mocks/`, handlers MSW, mock servers dedicados. Descoberta inspecionando o setup de testes e os arquivos de mock existentes.

Regras de reuso:
- **A convenção existente do projeto é autoritativa.** Se a codebase já estabelece como cada categoria vive, o contrato usa essa e somente essa.
- **Contratos anteriores também são autoritativos.** Quando existem arquivos `docs/F*-*/contract.md` no mesmo projeto, o novo contrato reutiliza literalmente os paths e mecanismos declarados neles. Divergir exige uma Assumption documentada explicando por quê.
- **Greenfield (nenhuma convenção encontrada):** em single-feature mode, pergunte durante a entrevista ("Onde as fixtures devem ficar? Como os dados de teste são semeados? Qual arquivo de env o test runner lê?"). Em Batch Mode, aplique o default mais comum para a stack detectada (ex.: `tests/fixtures/` para projetos Node/Vitest) e documente cada escolha em Assumptions da spec. A escolha passa a ser a convenção do projeto dali em diante.
- **Nunca invente uma convenção nova** quando uma já existe. Nunca divida uma mesma feature entre duas convenções (ex.: algumas fixtures em `tests/fixtures/`, outras em `__fixtures__/`).

### Relação com `Common given`

`Prerequisites` e `Common given` são camadas diferentes, que nunca se sobrepõem:

- **Prerequisites** = bootstrap do **ambiente**: serviços no ar, fixtures fornecidas, env vars definidas, contas pré-semeadas. Verificado uma vez antes de qualquer item rodar.
- **Common given** (por capability) = preparação do **estado**: qual fixture é a "atual", qual sessão está ativa, qual registro é o sujeito do teste. Reaplicado por item via `given:`.

Uma entrada de Prerequisites estabelece "alice existe com a senha Pass1234". Um `Common given` diz "alice está logada para os itens desta capability".

---

## Quality gates

Seção opcional entre `## Prerequisites` e `## Coverage Manifest`. Lista os comandos do projeto que precisam passar para a feature ser considerada pronta.

```markdown
## Quality gates

Cada gate precisa passar para a feature ser considerada pronta.

- **<name>** — `<command>` — <descrição de uma linha do que significa passar>
```

Regras:
- A lista vem dos gates confirmados no esclarecimento de quality gates do Step 2 (ou aplicados pela Auto-Accept Policy em Batch Mode).
- **Wrapper antes dos scripts individuais.** Antes de listar cada script como um gate, verifique na codebase e nas skills disponíveis se existe um script wrapper que execute todos os gates de uma vez. Quando existir, o wrapper é proposto como gate no lugar dos scripts individuais que ele já executa.
- O preâmbulo descreve apenas comportamento: nunca nomeia um executor, não usa vocabulário de fail-fast e não prescreve ordem de execução.
- Quando nenhum gate foi detectado e o usuário recusou ditar algum, a seção é omitida por inteiro — sem placeholder vazio.

---

## Ordem de Geração

Ordem das operações. Os passos 1–4 são preparação global; os passos 5+ iteram por superfície e por capability:

1. Leia do PRD, para a feature: os critérios de aceite do bloco da feature na Seção 11 (Seção 9 em PRDs antigos), os critérios de `Cross-Feature Integration` cujo `Owner` em `A.6` é esta feature, e `Capabilities`, `Experience` e `Error Handling`. O PRD é a fonte da verdade — o contrato se apoia no conteúdo do PRD, não nas escolhas de implementação da spec. Opcionalmente, consulte o `Error Handling` da `spec.md` (produzida antes, na mesma execução) apenas para descobrir edge cases; nunca deixe escolhas de implementação da spec moldarem os itens do contrato.
2. **Filtre os critérios da própria feature contra o bloco `Included` da spec.** ACs cuja verificação cai fora do escopo da spec (tipicamente porque o comportamento verificado pertence a uma feature a jusante no `Dependency Graph`) são descartados silenciosamente — não entram no manifest, não geram itens e não produzem avisos no console. Os critérios de `Cross-Feature Integration` atribuídos em `A.6` não passam por este filtro. O conjunto restante são os "ACs in-scope".
3. Determine quais superfícies se aplicam. Inspecione `Capabilities`/`Experience` da feature e seu bloco `Provides` (`Appendix A` → A.1 `Feature Data Contracts`) em busca de sinais de superfície. Se for ambíguo (single-feature mode), pergunte durante a entrevista ("Esta feature tem HTTP e UI; emitir `## E2E` para fluxos entre camadas?"). Em Batch Mode, o default é "todas as superfícies com ao menos um sinal no PRD".
4. Identifique as capabilities (tipicamente 1:1 com os bullets de capability do PRD, ou com fluxos de UX agrupados).
5. **Por superfície, por capability:** gere os itens percorrendo os ACs in-scope e o `Error Handling` do PRD, depois enriqueça com edge cases. Aplique os quatro guard-rails no `then`. Todo item precisa ser testável com esta feature + suas dependências do `Dependency Graph` implementadas.
6. Monte o Coverage Manifest percorrendo os itens gerados e associando-os aos ACs in-scope.
7. Monte a seção Prerequisites derivando os runtime services da architecture da spec, as fixtures das referências dos itens, a configuração do ambiente/decisões da spec e as dependências externas apenas quando os itens as exigirem. Nota: Prerequisites é gerada por último (depois que existem itens para percorrer), mas renderizada como a primeira seção `##` do arquivo (acima do Coverage Manifest).
8. Valide o gate. Aborte os três arquivos se qualquer AC in-scope tiver zero itens cobrindo.

---

## Anti-patterns a recusar

- Itens cujo `then` apenas repete o `when` (nenhuma observação real).
- Itens que testam um único value object, entity ou classe isoladamente.
- Itens cujo `given` inclui passos de setup operacional ("rode `npx prisma migrate`...").
- Bullets de `then` que dizem "o teste passa" ou "a função é chamada" — o contrato trata de consequências observáveis, não de pontos de chamada.
- Seções sem a linha `Verification mode:`.
- Linhas do manifest com "Covered by" vazio.
- IDs de itens não únicos no arquivo.
- Sub-headers de entidade de superfície (`### POST /auth/register`, `### /login page`) — apenas vocabulário de capability.
- `## Service` emitida sem um consumidor externo nomeado.
- Itens cuja verificação exige uma feature listada a jusante no `Dependency Graph` (uma feature que depende desta) — esses itens pertencem ao contrato da feature a jusante.
- Critérios `(RNF<NN>)` do bloco `Non-Functional Acceptance` no manifest ou em itens.
- Critérios de `Cross-Feature Integration` no manifest de uma feature que não é o `Owner` do cenário em `A.6`.
- Prerequisites descritos como retratos do estado atual ("o arquivo em X contém Y"). Prerequisites são requisitos prospectivos ("um arquivo em X com formato Y precisa ser fornecido").
- Handles nos itens (nomes de entidade como "alice"; paths de arquivo em `Static inputs`) sem declaração correspondente na subseção de Prerequisites.
- **Declarações órfãs**: entradas em `Persistent state` ou `Static inputs` que nunca são referenciadas pelo `given` ou `when` de nenhum item. Toda entrada declarada precisa ter ao menos um item consumidor citado na cláusula `Used by:`.
- Paths de static inputs inventados pela skill em vez de derivados da convenção de path de fixtures descoberta no projeto.
- Entradas de persistent state escritas de forma operacional ("rode este SQL", "execute este seed") em vez de declarativa ("alice existe com os atributos X"). COMO o estado é produzido é trabalho do implementador, ancorado na convenção de seeding do projeto; o contrato declara apenas O QUE precisa existir.
- Misturar persistent state com static inputs (ex.: declarar uma conta em `Static inputs` ou um arquivo de vídeo em `Persistent state`).

---

## Exemplo Trabalhado (trecho)

```markdown
# Contract: Authentication System

*Gerado pelo spec-writer. Edições manuais são sobrescritas na regeneração.*

## Prerequisites

Estas condições descrevem o ambiente em que os itens deste contrato
são exercitados. Produzi-las faz parte da entrega da feature, junto
com a própria implementação — um contrato cujos prerequisites ainda
não estão atendidos não está falhando, ainda está sendo construído.
Depois que a feature for entregue, qualquer condição ausente interrompe
a execução dos itens até ser restaurada.

**Runtime services:**
- o serviço de backend da feature está em execução e acessível
- o store de persistência está acessível, migrado e começa num estado conhecido contendo apenas o Persistent state abaixo
- há um navegador disponível para os itens de UI

**Persistent state:**
- `alice` — uma conta `alice@example.com` / `Pass1234` existe, ativa. Used by: API-REGISTER-03, API-LOGIN-01, API-LOGIN-02.

**Configuration:**
- `SESSION_TTL_SECONDS=604800` (default de 7 dias)
- o nome do cookie de sessão é `session_token`
- `TZ=UTC`

## Coverage Manifest

| PRD Acceptance Criterion | Covered by |
|---|---|
| (RF01.1) O usuário consegue se cadastrar com nome, e-mail e senha válidos | API-REGISTER-01, UI-REGISTER-01, E2E-SIGNUP-01 |
| (RF01.2) Senhas com menos de 8 caracteres ou sem letra ou número são recusadas com mensagens no campo | API-REGISTER-02, UI-REGISTER-02 |
| (RF01.3) E-mail duplicado no cadastro retorna um erro claro | API-REGISTER-03 |
| (RF01.4) O login falha com a mensagem genérica "E-mail ou senha inválidos" quando as credenciais estão erradas | API-LOGIN-02 |
| (RF01.1) Depois de um cadastro bem-sucedido, o usuário é autenticado automaticamente e chega em /app | E2E-SIGNUP-01 |

## HTTP API

**Verification mode:** Enviar uma requisição HTTP ao serviço em execução; verificar status, headers, body e qualquer efeito persistido direto.

### Register

**Common given:** não existe usuário com e-mail "carla@example.com"; backend em execução com a configuração default.

#### `API-REGISTER-01` — caminho feliz
- given: (default)
- when: POST /auth/register com body { name: "Carla", email: "carla@example.com", password: "Pass1234" }
- then:
  - 201 Created com body { user: { id, email: "carla@example.com" } }
  - Set-Cookie session_token (HttpOnly, SameSite=Lax, Max-Age=604800)
  - o usuário é persistido com o e-mail normalizado em minúsculas, is_admin=false
  - a senha é armazenada com hash (nunca em texto puro)

#### `API-REGISTER-02` — senha fraca recusada
- given: (default)
- when: POST /auth/register com password "abc" (menos de 8 caracteres, sem número)
- then:
  - 422 Unprocessable Entity com code WEAK_PASSWORD
  - o body indica qual regra falhou (tamanho, letra ou número)
  - nenhum usuário é persistido

#### `API-REGISTER-03` — e-mail duplicado recusado
- given: a conta alice existe
- when: POST /auth/register com e-mail "alice@example.com"
- then:
  - 409 Conflict com code USER_ALREADY_EXISTS
  - o registro de alice não é alterado

### Login

**Common given:** a conta alice existe; não há sessão ativa para alice.

#### `API-LOGIN-01` — caminho feliz
- given: (default)
- when: POST /auth/login com { email: "alice@example.com", password: "Pass1234" }
- then:
  - 200 OK com body { user: { id, email, lastLoginAt: não nulo } }
  - Set-Cookie session_token
  - o lastLoginAt de alice é atualizado

#### `API-LOGIN-02` — senha errada recusada
- given: (default)
- when: POST /auth/login com { email: "alice@example.com", password: "wrong" }
- then:
  - 401 Unauthorized com code INVALID_CREDENTIALS
  - a mensagem da resposta é "E-mail ou senha inválidos" (não revela qual campo)
  - nenhum Set-Cookie

## UI

**Verification mode:** Renderizar a superfície, conduzi-la com entradas de usuário (cliques, digitação); verificar o estado observável do DOM/página e a navegação.

### Register

**Common given:** usuário anônimo em /register; não existe usuário com e-mail "carla@example.com".

#### `UI-REGISTER-01` — envio de formulário válido chega em /app
- given: (default)
- when: preencher nome "Carla", e-mail "carla@example.com", senha "Pass1234", confirmação "Pass1234"; clicar em "Criar conta"
- then:
  - a página navega para /app
  - o título de boas-vindas diz "Bem-vinda, Carla"

#### `UI-REGISTER-02` — senha fraca mostra a regra no campo
- given: (default)
- when: preencher a senha "abc" e enviar
- then:
  - o formulário não navega
  - uma mensagem abaixo do campo de senha diz qual regra falhou (tamanho, letra ou número)

## E2E

**Verification mode:** Executar o sistema completo (backend + frontend + DB); conduzir por um navegador real; verificar o comportamento entre as camadas.

### Sign-up

#### `E2E-SIGNUP-01` — cadastrar e continuar autenticado após recarregar
- given: usuário anônimo; não existe usuário com e-mail "carla@example.com"
- when: concluir o formulário de /register com nome "Carla", e-mail "carla@example.com" e senha "Pass1234"; recarregar o navegador em /app
- then:
  - após recarregar, /app continua mostrando "Bem-vinda, Carla"
  - o cookie session_token persiste após recarregar
  - o usuário aparece no banco com o e-mail "carla@example.com"
```
