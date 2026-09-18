---
name: evaluator
description: Verifica a implementação de uma feature contra seu contrato de comportamento, exercitando diretamente cada item do contrato (HTTP / navegador / DB / filesystem) e produzindo um veredito por item, a projeção dos ACs sobre o Coverage Manifest e um relatório persistido com timestamp. Agnóstico de stack e de projeto — descobre tudo a partir do contrato, da documentação do projeto e da codebase.
---

# Evaluator

Verifica se a implementação de uma feature honra seu `contract.md`. A skill é a contraparte de **veredito canônico** de qualquer sinal de prontidão preliminar que um implementador possa emitir — ela é dona do ciclo de vida do ambiente, exercita ponta a ponta cada item in-scope e persiste um relatório de auditoria com timestamp.

A skill é **agnóstica de stack** e **independente**: não importa nem referencia nenhuma outra skill. O formato do contrato é o único acoplamento formal, e a skill lê markdown estruturado por leitura seccional leniente (sem parser de gramática estrita).

**Somente leitura sobre o projeto, exceto pelo arquivo de relatório e pela entrada desta feature no `prd_progress.json`.** Nunca modifica código, testes, fixtures, seeds, configs, contratos, specs ou plans. Nunca modifica nenhuma entrada de feature no `prd_progress.json` além da entrada da target feature. Nunca faz commit, push ou abre PRs.

## INPUT

Free-form. Resolva uma pasta de feature contendo um `contract.md` e produza um relatório de veredito. Formatos aceitos:

- Feature ID (`F03`, `F12`).
- Pasta da feature (`docs/F03-video-upload/`, `./F03/`).
- Arquivo dentro da pasta da feature (`docs/F03-video-upload/contract.md`).
- Nome da feature em kebab-case ou fuzzy (`video upload`, `Video Upload`).
- Um `progress-path=<path>` opcional apontando para o `prd_progress.json` do projeto. Se omitido, a skill procura o arquivo conforme **PROGRESS TRACKING**.

Overrides opcionais em linguagem natural, em qualquer lugar do input:

- `only API`, `only API-UPLOAD-03`, `only API and E2E`, `skip UI`.
- `only failed-last-run` — re-executa apenas os itens marcados `FAIL` ou `BLOCKED` no `eval-report-<ISO-timestamp>.md` mais recente desta feature.
- `keep env` — pula o tear-down; deixa o DB e o tmpdir para inspeção manual.
- `pause on first failure` — para depois do primeiro FAIL.

Se a resolução falhar:

- Nenhum `contract.md` encontrado na pasta resolvida → aborte informando o path resolvido.
- Contrato malformado (sem seção `## Coverage Manifest`, sem seção `## Prerequisites`, ou itens referenciados no manifest que não aparecem sob nenhuma seção de superfície) → aborte.
- Filtro `only failed-last-run` sem relatório anterior → aborte com explicação.
- Filtro seleciona zero itens → aborte.

## OUTPUT

Artefatos por execução:

1. **Chat report (compacto)** — header + status agregado + apenas os ACs FAIL / `⊘` e os itens FAIL / BLOCKED em detalhe + path do relatório em arquivo.
2. **Relatório em arquivo (completo)** em `<feature-folder>/eval-report-<ISO-timestamp>.md`. Irmão do `contract.md`. Não fica no gitignore. Formato fixado por `references/report-template.md`.
3. **Screenshots** (apenas execuções com UI/E2E) em `<feature-folder>/eval-screenshots-<ISO-timestamp>/`. Irmão do relatório; referenciados a partir da Evidence dos itens. Não ficam no gitignore.

Nenhum outro arquivo é gravado. Nenhum commit é produzido. Nenhuma mudança de código é feita.

---

## EXECUTION STEPS

A skill prescreve a **estrutura** de uma execução (fases, ordem, condições de abort, marcas, anti-escopo). Ela é permissiva quanto à **tática** (qual comando roda a migration, qual ferramenta conduz o navegador etc.) — o modelo descobre e aplica o que se encaixa no projeto. Não enumere heurísticas exaustivas em código ou comentários; deixe a descoberta fazer seu trabalho.

### Step 1 — Resolve input

Faça o parsing do input como free-form. Identifique:

- A pasta da target feature (precisa conter `contract.md`).
- Os overrides de filtro (`only`, `skip`, `only failed-last-run`, `keep env`, `pause on first failure`).

Aborte com uma mensagem clara em qualquer falha de resolução listada em INPUT.

### Step 2 — Discovery

Leia o que o projeto confia à skill, nesta ordem de prioridade. **Camadas mais altas vencem**; registre qual camada respondeu cada decisão para que a seção Discovery do relatório seja auditável.

1. **Prerequisites do contrato** (a seção `## Prerequisites` do `contract.md`). Canônica para *o que* a feature exige (Runtime services, handles de Persistent state, paths de Static inputs + propriedades intrínsecas, chaves de Configuration, External dependencies).
2. **Documentação do projeto**: `CLAUDE.md` (raiz e quaisquer aninhados), conteúdo de `harness/`, `README*`. Canônica para *como* o projeto quer que o ambiente seja levantado, resetado e derrubado — quando o projeto documenta isso.
3. **`spec.md` irmão do `contract.md`** (quando presente): a Seção 4 (`Technical Decisions & Assumptions`) declara convenções do projeto (mecanismo de seeding, path de fixtures, config de teste, ORM etc.).
4. **Outros contratos em `docs/F*-*/`**: paths e handles já declarados por features irmãs — autoritativos para reuso.
5. **Inspeção da stack**: manifests do projeto (`package.json`, `pyproject.toml`, `Gemfile`, `go.mod`, `Cargo.toml` etc.), scripts disponíveis (nesses manifests, `Makefile`, `Taskfile`, `justfile`), configs de DB / ORM, arquivos de container compose, arquivos `.env*`.
6. **Defaults por stack detectada** — aplique defaults de conhecimento geral para a stack que a inspeção identificou.
7. **Abort com diagnóstico** — liste o que foi tentado e onde, e sugira o lugar certo para documentar (tipicamente a camada 2).

A skill é permissiva sobre COMO descobrir dentro de uma camada. Ela desce pelas camadas até encontrar uma resposta utilizável.

O que a skill precisa saber ao final do Step 2 (conhecimento ausente é registrado e informa o pre-flight):

- **Como instalar as dependências do projeto para a stack detectada** (ex.: Node → `npm ci` com `npm install` como fallback; Python → `pip install -r requirements.txt` ou `poetry install`; Go → `go mod download`; Rust → `cargo fetch`). Convenção da stack primeiro; overrides específicos do projeto descobertos na camada 2 (`CLAUDE.md`, `harness/`) ou em `package.json scripts.setup` vencem quando presentes.
- Como criar e remover um banco de dados efêmero.
- Como rodar as migrations contra ele.
- Como semear o Persistent state declarado no contrato.
- Como iniciar, fazer health-check e parar cada serviço declarado em `Runtime services`.
- Como resetar o estado entre itens (o mecanismo preferido do projeto, ou um default sensato para a stack detectada).
- Onde os Static inputs ficam e como verificar suas propriedades intrínsecas (ferramentas que o contrato nomeia — `ffprobe`, `file`, checagens de tamanho etc.).
- Como conduzir cada superfície declarada no contrato (HTTP, UI, E2E, Service, CLI, Worker, Event).

### Step 3 — Pre-run cleanup

Antes de levantar qualquer coisa, procure recursos órfãos de execuções anteriores do evaluator e remova-os. **Remova apenas recursos cujos nomes dão match com o marcador da skill** — nunca qualquer outra coisa.

**Definição do marcador (fixa).** `<feature-id>` é o segmento inicial `F<N>` do nome da pasta da feature, em minúsculas e sem caracteres não alfanuméricos (ex.: pasta `F03-video-upload` → `f03`). A skill PRECISA usar exatamente essa forma em todo marcador — nome do DB, path do tmpdir, path do lockfile, referências no relatório — para que a limpeza dê match byte a byte com a criação entre execuções.

**Segurança contra execuções concorrentes.** Antes de remover qualquer coisa, examine os arquivos `processes.lock` candidatos em busca de PIDs vivos (qualquer PID listado que responda a um sinal `kill -0` está vivo). **Se algum lockfile candidato tiver ao menos um PID vivo, aborte a nova execução** com uma mensagem no formato: `já existe uma execução do evaluator para <feature-id>: PID <N> vivo em <lockfile>. Espere terminar ou encerre-a, e re-rode.` NÃO remova esse lockfile, seu tmpdir, nem qualquer DB associado ao seu run-id — a execução viva é dona deles.

Depois que a checagem de segurança passar:

- Bancos de dados: remova qualquer DB cujo nome dê match com `eval_<feature-id>_*`.
- Tmpdirs: `rm -rf` em qualquer diretório sob `<os.tmpdir()>/evaluator-<feature-id>-*/`.
- Processos: examine os arquivos `<os.tmpdir()>/evaluator-<feature-id>-*/processes.lock`; mate os PIDs listados que ainda estão vivos (best-effort — se um PID foi reciclado para um processo não relacionado, pule em vez de arriscar matar um estranho).

Registre cada recurso removido na seção "Pre-run cleanup" do relatório. Se a própria limpeza der erro (permissão, lock), registre um aviso e prossiga — órfãos não são bloqueadores.

### Step 4 — Bring-up e pre-flight

1. **Instale as dependências do projeto** usando o comando descoberto no Step 2 (ex.: `npm ci`). O comando é idempotente — rápido em projetos já instalados, lento apenas num clone novo. Se a instalação sair com código não-zero, aborte a execução com o status `aborted at step 4` e o stderr do comando de instalação no motivo do abort.
2. **Crie o DB efêmero** com o nome `eval_<feature-id>_<run-id>` (run-id = timestamp ISO normalizado para ser seguro em nome de arquivo; `<feature-id>` conforme a definição do marcador fixada no Step 3).
3. **Crie o tmpdir** em `<os.tmpdir()>/evaluator-<feature-id>-<run-id>/`. Crie o lockfile `processes.lock` dentro dele.
4. **Rode as migrations** contra o DB efêmero.
5. **Semeie o Persistent state** declarado no contrato.
6. **Inicie os runtime services** declarados em `Runtime services` (backend, web, fila etc.). Faça o health-check de cada um antes de prosseguir. Acrescente os PIDs ao lockfile.
7. **Pre-flight: verifique cada entrada de todas as subseções de Prerequisites presentes no contrato** contra o ambiente ao vivo. Subseções ausentes do contrato são puladas (não há entradas para verificar).

   - `Runtime services` — o endpoint de health ou sinal de prontidão de cada entrada retorna sucesso.
   - `Persistent state` — cada handle declarado existe com os atributos declarados (consulte o DB).
   - `Static inputs` — cada path de arquivo declarado existe E sua propriedade intrínseca vale (rode a ferramenta que o contrato nomeia).
   - `Configuration` — cada chave declarada está definida nos serviços em execução com um valor compatível com o significado declarado no contrato.
   - `External dependencies` — cada ferramenta / biblioteca declarada está no PATH ou acessível de outra forma; checagem de versão quando o contrato especifica.

   Cada entrada é classificada `✓` (passou) ou `✗` (falhou; registre o motivo). Um `✗` não aborta a execução — ele produz uma marca `BLOCKED` para os itens que consomem aquele prerequisite (resolvido no Step 6). Um `✗` no pre-flight **não** pula o Step 5 (gates) — gates e prerequisites são preocupações ortogonais.

   Um prerequisite declarado que nenhum item referencia (nenhum `given` / `when` / `Common given:` da superfície consome o handle, path ou chave) é uma **declaração órfã** — um bug de autoria do contrato. Verifique normalmente; se `✗`, registre em "Soft-fails" com a nota `<entry> declared but no item references it`. O resultado não bloqueia nenhum item; a linha expõe a deriva do contrato para o autor corrigir.

Se qualquer um dos passos 1–6 não completar (erro de instalação, migrations explodem, um serviço se recusa a subir depois de uma espera razoável etc.), aborte a execução antes do Step 5. Reporte o que completou até a falha em "Abort reason".

### Step 5 — Quality gates

Roda **depois** que o Step 4 (bring-up + pre-flight) termina com sucesso, **antes** de qualquer item do contrato ser executado. Lê a seção `## Quality gates` do contrato e executa cada entrada na ordem do documento.

**Se o contrato não tiver seção `## Quality gates`, pule este step inteiro.** Nenhuma fase roda, nenhuma seção do relatório é renderizada (ela colapsa para `*(none)*` conforme o template). O evaluator é agnóstico ao histórico do contrato — a presença da seção é o único sinal.

**Quando a seção existe:**

1. Faça o parsing de cada entrada. Cada linha sob a seção tem o formato `- **<name>** — \`<command>\` — <description>`. O comando entre crases é o comando de shell literal a executar. O nome rotula a entrada no relatório. A descrição é informativa.

2. Execute cada entrada sequencialmente, na ordem do documento. Para cada uma:
   - Rode `<command>` num shell com raiz na raiz do projeto, com o **ambiente efêmero** da execução levantada injetado (`DATABASE_URL` apontando para `eval_<feature-id>_<run-id>`, URLs dos runtime services iniciados etc.). Gates estáticos (lint, typecheck, arquitetura) ignoram as variáveis injetadas; gates dependentes de DB ou de serviço as usam para verificar contra o ambiente recém-levantado.
   - Capture exit code, stdout, stderr.
   - Marque a entrada `✓` (exit 0) ou `✗` (exit não-zero).

3. **Fail-fast.** No primeiro `✗`, pare a fase de gates imediatamente. Não rode as entradas de gate restantes.

4. **Em qualquer falha de gate:**
   - Run status: `fail (gate <name>)`.
   - Todos os itens do contrato são marcados `BLOCKED — run aborted at gates: <name>` (o mesmo vocabulário usado para a cascata de morte de serviço no Step 6.9).
   - Todos os ACs do Coverage Manifest são marcados `⊘ undetermined` (todo item de cobertura está BLOCKED).
   - Pule o Step 6 (executar itens) inteiro.
   - O Step 7 (tear-down) roda normalmente — o ambiente ESTÁ no ar neste ponto. Se o usuário passou `keep env`, respeite (pule o tear-down, imprima os detalhes de conexão para que ele possa inspecionar o ambiente com falha).
   - O Step 8 (relatório) grava o relatório parcial: Discovery, Pre-run cleanup, Bring-up + pre-flight, Quality gates (com o resultado por gate até e incluindo a falha), Coverage Manifest (todos ⊘), Items (todos BLOCKED), Abort reason (com o comando do gate que falhou, exit code e um trecho do stderr).

5. **Com todos os gates passando**, prossiga normalmente para o Step 6.

A fase é **imutável**. Não existe override para pulá-la. Uma execução sobre um contrato com `## Quality gates` sempre roda esses gates depois do bring-up; um desenvolvedor que queira contorná-los precisa remover a seção do contrato (o que é a atitude errada — ele deveria corrigir o gate). A disciplina é intencional: um contrato que declara quality gates está declarando a régua do projeto para entregar; o evaluator a aplica.

### Step 6 — Execute items

Execute cada item selecionado (depois de aplicar os filtros do input) sequencialmente, em **ordem de pirâmide**:

```
Service → HTTP API → CLI → Worker → Event → UI → E2E → Manual
```

Dentro de uma superfície, siga a ordem do documento do contrato. Não paralelize; não embaralhe. Os itens de `## Manual` são sempre placeholders subjetivos (`notes: subjective; manual review only`) e terminam em `MANUAL` no 6.2.

Para cada item:

**6.1 — Checagem de seleção.** Se o item foi filtrado para fora desta execução, marque `SKIPPED` com o motivo do filtro e siga para o próximo.

**6.2 — Checagem de subjetividade.** Se o `notes` do item o declarar subjetivo (ex.: `subjective; manual review only`), marque `MANUAL` e não o exercite. O veredito subjetivo precede o gating de prerequisites porque um item subjetivo nunca é verificado automaticamente — o estado dos seus prerequisites é irrelevante para o resultado.

**6.3 — Gating de prerequisites.** Se qualquer Prerequisite que este item referencia (handles no `given`, paths no `when`, configs / ferramentas pelo `Common given:` da superfície) está `✗` no pre-flight, marque `BLOCKED` identificando o prerequisite que falhou. Não exercite.

**6.4 — Resetar o estado.** Rode o mecanismo de reset do projeto (o que a descoberta encontrou): tipicamente truncar as tabelas efêmeras e limpar o conteúdo de quaisquer locais do filesystem que o contrato declara como "começa vazio". Depois do reset, garanta que o Persistent state está intacto; semeie de novo apenas se o reset o apagou.

**6.5 — Traduzir os bullets do `then`.** Aplique `references/assertion-patterns.md` (carregue de forma lazy na primeira tradução). Cada bullet é um destes:

- **Dá match com um padrão reconhecido** → tradução mecânica, executada e registrada com `expected` / `observed`.
- **NÃO dá match** → o modelo interpreta o bullet, executa sua interpretação E **marca o item com `*`**. A interpretação PRECISA ser registrada no raciocínio do item ("interpreted as: …") para que um leitor possa auditar.
- **Genuinamente ambíguo** (nenhuma interpretação plausível) → marque o bullet como não verificável; o item vira `MANUAL` com `notes: phrasing not auto-verifiable: <quote>`.

**6.6 — Exercitar.** Conduza a superfície usando o que o projeto oferece (descoberto no Step 2):

- HTTP API → cliente HTTP descoberto contra o backend em execução.
- UI → o driver de navegador idiomático do projeto.
- E2E → o mesmo driver de navegador + consultas diretas ao DB efêmero.
- Service → invoque o runtime do projeto para chamar a função / classe nomeada (o modelo descobre o path de import a partir do item do contrato mais o spec.md ou a codebase).
- CLI / Worker / Event → execute o binário, publique na fila ou emita o evento usando os idiomas do projeto.

Se a skill não conseguir conduzir uma superfície (ex.: uma superfície `Worker` de uma tecnologia de fila que a descoberta não reconheceu), marque cada item dessa superfície `BLOCKED — no driver discovered for surface <name>` e continue com as outras superfícies.

**Baseline visual (apenas UI / E2E).** Conduzir o navegador não basta — o estado renderizado também precisa estar íntegro. Depois de cada `when` que afeta o DOM, defina um **escopo** = os elementos nomeados nos bullets do `then` do item (sua subárvore) ∪ qualquer elemento que ficou visível como resultado da ação — overlays montados como portals em `document.body`, dropdowns/menus/popovers aninhados localmente dentro do container do gatilho, tooltips, dialogs, comboboxes e superfícies flutuantes semelhantes. O local de montagem não importa; o que importa é ficar visível com a ação. Quando a ação abre uma dessas superfícies, a baseline visual PRECISA rodar **entre abrir a superfície e qualquer clique posterior dentro dela** — abra a superfície, tire o screenshot, rode as duas passadas contra o estado aberto e só então prossiga para clicar num item ou fechar. Chegar ao estado a jusante (navegação, mutação) NÃO é evidência de que a superfície estava visualmente válida; o estado aberto precisa ser inspecionado por si só. Quando o mesmo gatilho se repete em muitos cards/linhas/células, exercite ao menos uma **instância de fronteira** (a linha visível mais baixa/mais à direita, ou a mais próxima de uma borda de scroll/overflow) além da primeira; bugs de corte quase sempre só aparecem na periferia. Dentro do escopo, rode duas passadas:

- **Mecânica (determinística, sem `*`):** mídias (`<img>`, `<video>`, `<picture>`, `background-image`) precisam ter carregado de fato — requisição 2xx E `naturalWidth/Height > 0` (ou `readyState >= HAVE_CURRENT_DATA` para vídeo). Um ícone de imagem quebrada não é um placeholder válido, a menos que o bullet do contrato afirme explicitamente um fallback. Nós visíveis precisam estar dentro do viewport, não cortados pelo `overflow` de um ancestral, e acertáveis no seu centro via `elementFromPoint` (pega bugs de z-index/stacking).
- **Visão por LLM (marcada `*`):** tire um screenshot do viewport afetado, olhe apenas para o escopo e reporte qualquer corte, sobreposição, render quebrado, colapso de layout ou outra anomalia visual que a passada mecânica não pegou.

Cada achado vira um bullet sintético no item, registrado em Evidence com o path do screenshot. Bullets sintéticos se comportam como qualquer bullet do contrato: falha → item FAIL → AC ✗. Eles não são erros de transporte e não contam para o limite de morte de serviço.

**6.7 — Asserção.** Para cada bullet, registre `expected` (do contrato) e `observed` (do exercício). Bullet PASS se o observado satisfaz o esperado; FAIL caso contrário.

**6.8 — Veredito e raciocínio.** Item PASS ⇔ todo bullet PASS. Item FAIL ⇔ ao menos um bullet FAIL. Para cada bullet `✗`, gere uma causa raiz narrativa de uma linha, ancorada em evidência observável (body HTTP, linha de log coletada, resultado de consulta ao DB, estado do filesystem, trecho do DOM do navegador). Quando a evidência for insuficiente para identificar uma causa, escreva `→ root cause: unable to determine; see raw evidence` em vez de especular.

**6.9 — Erros transitórios e detecção de morte de serviço.** Um *erro de transporte* é uma falha em nível de TCP ou de processo: connection refused, connection reset, timeout de requisição / socket, crash do processo do navegador ou do runtime. **Respostas HTTP 4xx e 5xx NÃO são erros de transporte** — são falhas honestas do item e nunca disparam este caminho.

Um único item com erro de transporte → 1 retry. Se continuar falhando, registre como `FAIL` com a exceção no `observed` do bullet que falhou.

**Se três ou mais itens consecutivos falharem com a mesma classe de erro de transporte** (mesmo tipo de exceção / mesma família de falha de conexão), trate como morte de serviço: tente um restart do serviço cuja URL os itens com falha estavam atingindo; se ele não voltar saudável, aborte a execução. Marque os itens restantes não exercitados `BLOCKED — run aborted at item <ID>: <service> died`.

**6.10 — `pause on first failure`.** Quando o override está ativo e um item é `FAIL`, grave o relatório parcial e pare. Run status: `aborted at item <ID>: pause-on-first-failure`. Marque os itens restantes não exercitados `BLOCKED — run aborted at item <ID>: pause-on-first-failure`.

### Step 7 — Tear-down

Idempotente. Depois do último item ou em qualquer caminho de abort, nesta ordem:

1. Mate os processos listados em `<tmpdir>/processes.lock`.
2. Remova o DB efêmero (`eval_<feature-id>_<run-id>`).
3. `rm -rf` no tmpdir.

Cada passo é best-effort — registre avisos em caso de falha, NÃO derrube o relatório. Órfãos deixados para trás são limpos no Step 3 da próxima execução.

Se `keep env` estiver ativo, pule o Step 7 inteiro. Imprima os detalhes de conexão (URL do DB, URLs dos serviços, path do tmpdir) para que o usuário possa inspecionar manualmente, mais o comando explícito de limpeza que ele pode rodar depois.

### Step 8 — Report

Projete os resultados da execução sobre o Coverage Manifest e grave tanto o resumo no chat quanto o relatório em arquivo.

**Projeção sobre o Coverage Manifest (três estados por AC):**

- `✓ verified` — todo item de cobertura está `PASS`.
- `✗ failed` — ao menos um item de cobertura está `FAIL`.
- `⊘ undetermined` — nenhum `FAIL`, mas ao menos um item de cobertura está `BLOCKED`, `MANUAL` ou `SKIPPED` (filtrado).

**Run status:**

- `clean` — todo AC `✓`, nenhum `BLOCKED`, nenhum `MANUAL` pendente, nenhum abort.
- `fail` — ao menos um AC `✗`.
- `fail (gate <name>)` — o Step 5 abortou porque o gate `<name>` saiu com código não-zero. Todos os ACs `⊘`, todos os itens `BLOCKED — run aborted at gates: <name>`.
- `pending` — zero ACs `✗`, mas ao menos um AC `⊘` (e a execução não foi abortada nos gates).
- `aborted at step <N>` — abort em nível de infraestrutura durante os Steps 1–4 (resolução do input, discovery, pre-run cleanup, falha no bring-up). Use o número do step (ex.: `aborted at step 4`).
- `aborted at item <ID>: <reason>` — abort em nível de execução durante o Step 6 (morte de serviço, `pause on first failure`). Use o ID do item causador e um motivo curto.

Grave o relatório em arquivo seguindo `references/report-template.md` (carregue de forma lazy). Imprima o resumo no chat seguindo a projeção compacta do mesmo template. Ambos referenciam o mesmo run-id.

**Insight defensivo (apenas informativo).** Se ≥ 80 % dos itens *executados* (o denominador exclui `BLOCKED`, `MANUAL` e `SKIPPED`) falharem com o mesmo padrão de causa raiz (ex.: 404 em todo item HTTP, "ENOENT" em todo acesso a fixture), adicione uma única linha ao header do chat:

> Nota: a maioria dos itens falha com `<pattern>`; a implementação pode não estar no lugar.

As marcas continuam honestas; a linha não muda nenhum veredito.

---

## PROGRESS TRACKING

Esta skill grava o veredito canônico da target feature num arquivo compartilhado `prd_progress.json`. O arquivo é o registro determinístico do estado das features ao longo do pipeline `implement-feature` → `evaluator` → `fix-runner`. O schema é canônico em `${CLAUDE_PLUGIN_ROOT}/references/progress-schema.md`; esta seção documenta apenas as escritas desta skill.

**Localizando o arquivo** (na ordem; o primeiro encontrado vence):

1. Se o input contiver `progress-path=<path>`, use-o.
2. Procure a partir da pasta da feature resolvida no Step 1 para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo. O `prd-writer-for-complete-project` grava o arquivo ao lado do PRD por padrão, e as pastas de feature ficam ao lado do PRD (ex.: `docs/F03-video-upload/` → `docs/prd_progress.json`).
3. Procure a partir do CWD para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo.

Se não for encontrado, registre em "Soft-fails" a linha "arquivo de progresso não encontrado, status não rastreado" no relatório e prossiga. O veredito, o chat report e o relatório em arquivo são produzidos normalmente.

**Regra de escopo:** nunca toque na entrada de qualquer feature que não seja a target feature. Nunca modifique os campos de primeiro nível (`schema_version`, `prd_path`, `generated_at`).

**Modos de falha — continuação silenciosa:**

- Arquivo não encontrado, falha no parse, ou feature ID ausente como chave em `features` → registre em "Soft-fails", pule a escrita.
- Escrita atômica falha → registre em "Soft-fails", pule.

A escrita acontece uma vez por execução, no final do Step 8, depois que o relatório em arquivo foi gravado. Ler → modificar apenas a entrada da target feature → escrita atômica (`.tmp` + rename) do JSON inteiro. Timestamps são RFC 3339 UTC.

**Escrita — No final do Step 8, condicionada ao Run status:**

- **`clean`** (todo AC `✓`, nenhum abort) →
  - `status` ← `"done"`
  - `completed_at` ← now
  - `report_path` ← path do `eval-report-<ts>.md` recém-gravado
  - `failure_reason` ← `null` (limpa qualquer nota de falha anterior)
  - `updated_at` ← now

- **`fail`** OU **`fail (gate <name>)`** OU qualquer **`aborted-at-step-<N>`** OU **`aborted-at-item-<ID>`** →
  - `status` ← `"fail"`
  - `failure_reason` ← resumo curto ≤200 caracteres. Templates sugeridos:
    - `fail` → `"<N> contract item(s) failed; first: <ID> — <one-line reason>"`
    - `fail (gate <name>)` → `"gate <name> failed: <stderr excerpt>"`
    - `aborted-at-step-<N>` → `"evaluator aborted at step <N>: <reason>"`
    - `aborted-at-item-<ID>` → `"evaluator aborted at item <ID>: <reason>"`
  - `report_path` ← path do `eval-report-<ts>.md` recém-gravado (`null` apenas se o abort aconteceu antes de o relatório poder ser gravado; execuções abortadas nos gates ainda produzem um relatório parcial, então isso raramente é null).
  - `completed_at` ← inalterado.
  - `updated_at` ← now

- **`pending`** (nenhum AC `✗`, mas ACs `⊘` presentes por `BLOCKED` / `MANUAL` / `SKIPPED`) →
  - `status` ← inalterado. O veredito não é nem sucesso nem falha terminal — tipicamente o orquestrador vai despachar o `fix-runner` em seguida e então reavaliar. Standalone, o usuário inspeciona o relatório e decide.
  - `report_path` ← path do `eval-report-<ts>.md` recém-gravado (para que o usuário consiga navegar do `prd_progress.json` até o relatório que descreve o que está bloqueado/manual).
  - `failure_reason` ← inalterado.
  - `updated_at` ← now

Essa única escrita cobre todos os caminhos de término. Nenhuma escrita acontece antes do Step 8 — o pre-flight, o bring-up e a execução dos itens estão todos "em voo" e seu estado intermediário não é exposto no `prd_progress.json`.

---

## RULES

**Sempre:**

- Trate o `contract.md` como a fonte única da verdade sobre o que verificar. Não consulte o spec, o plan ou o PRD para as asserções.
- Rode a fase de gates (Step 5) depois que o Step 4 (bring-up + pre-flight) tiver sucesso, antes de executar qualquer item, quando o contrato tiver uma seção `## Quality gates`. Execute cada entrada na ordem do documento, fail-fast no primeiro exit não-zero, e capture exit code + stderr por entrada. Injete o ambiente efêmero (`DATABASE_URL` e as URLs dos serviços iniciados) no shell do comando do gate para que gates dependentes de DB ou de serviço possam validar contra o ambiente levantado. Pule a fase silenciosamente quando a seção estiver ausente.
- Rode o pre-flight sobre cada entrada de Prerequisites declarada no contrato (em qualquer uma das cinco subseções que estiverem presentes) antes de executar qualquer item.
- Execute os itens sequencialmente em ordem de pirâmide: Service → HTTP API → CLI → Worker → Event → UI → E2E → Manual.
- Resete o estado entre cada item usando o mecanismo de reset descoberto no projeto.
- Traduza os bullets do `then` via `references/assertion-patterns.md` de forma mecânica quando os padrões derem match; marque o item com `*` e registre a interpretação quando não derem.
- Para itens de UI/E2E, rode a baseline visual (Step 6.6) — sucesso de DOM/clique não basta sozinho. Um overlay cortado, uma thumbnail quebrada ou um layout visivelmente colapsado precisa dar FAIL no item mesmo que todos os bullets do contrato fossem passar.
- Marque os itens como um de `PASS / FAIL / BLOCKED / MANUAL / SKIPPED`. Projete os ACs como `✓ / ✗ / ⊘`.
- Persista o relatório em `<feature-folder>/eval-report-<ISO-timestamp>.md` seguindo `references/report-template.md`. O placeholder `<ISO-timestamp>` é o mesmo run-id usado no nome do DB e no tmpdir, estável byte a byte em todas as referências.
- Limpe apenas recursos cujos nomes dão match com os marcadores da skill (`eval_<feature-id>_*` para DBs, `evaluator-<feature-id>-*` para tmpdirs, PIDs no próprio lockfile). Nunca toque em qualquer outra coisa.
- O tear-down é idempotente; órfãos são limpos no Step 3 da próxima execução.
- Quando a descoberta esgotar todas as camadas sem uma resposta, aborte com um diagnóstico que liste o que foi tentado e onde documentar.
- Grave o veredito no `prd_progress.json` conforme **PROGRESS TRACKING** no final do Step 8 (depois que o relatório em arquivo foi gravado), modificando apenas a entrada da target feature. Pule a escrita silenciosamente, com uma linha em "Soft-fails", se o arquivo não for localizável, não fizer parse, ou o feature ID estiver ausente.

**Nunca:**

- Modifique código, testes, fixtures, seeds, configs, contratos, specs ou plans do projeto. Somente leitura sobre o projeto, exceto pelo arquivo de relatório e pela entrada da target feature no `prd_progress.json`.
- Modifique qualquer entrada de feature no `prd_progress.json` além da entrada da target feature. Nunca modifique os campos de primeiro nível (`schema_version`, `prd_path`, `generated_at`).
- Crie arquivos que o projeto não tem (um seed ausente, uma fixture ausente, um teste ausente). Marque os itens dependentes como `BLOCKED` ou `MANUAL` e reporte.
- Rode a test suite existente do projeto como substituta da execução direta dos itens do contrato. Os itens são exercitados diretamente. (Os quality gates declarados em `## Quality gates` são uma preocupação separada — eles rodam no Step 5 porque o contrato os declara como pré-condições, não como substitutos do exercício dos itens.)
- Pule a fase de gates via override. O Step 5 é imutável quando `## Quality gates` existe; não há flag `skip gates`.
- Remova um banco de dados ou faça `rm -rf` num diretório cujo nome não dá match com o próprio marcador da skill. Jamais.
- Faça commit, push ou abra PRs. Nem o arquivo de relatório é commitado automaticamente.
- Marque um AC `✓` quando qualquer item de cobertura não estiver `PASS`. Use `⊘` para cobertura parcial (BLOCKED / MANUAL / SKIPPED), `✗` para qualquer FAIL.
- Marque um bullet PASS sem registrar o valor observado. Todo PASS e todo FAIL tem evidência `expected` / `observed`.
- Pule o pre-flight para "ganhar tempo". O pre-flight é imutável — overrides não o desabilitam.
- Continue a execução depois de uma detecção de morte de serviço (3+ falhas consecutivas por erro de transporte). Abortar é mais honesto do que carimbar FAIL em itens que nunca rodaram de forma limpa.
- Especule a causa raiz quando a evidência for insuficiente. Escreva `→ root cause: unable to determine; see raw evidence`.
- Edite à mão um relatório gerado. Re-execuções produzem novos arquivos com timestamp; relatórios antigos são histórico imutável.
- Retome uma execução anterior. Cada invocação é independente.
- Enumere inline heurísticas exaustivas específicas de stack. A descoberta é permissiva; deixe o modelo descobrir a tática a partir da camada em que chegar.

---

## OVERRIDES

Flags free-form em linguagem natural adicionadas ao input sobrescrevem os defaults. Reconhecidas:

| Override | Efeito |
|---|---|
| `only <surface>` | Roda apenas os itens da(s) superfície(s) nomeada(s). Várias superfícies são permitidas. |
| `only <ITEM-ID>` | Roda apenas o(s) item(ns) nomeado(s). |
| `skip <surface>` | Pula a(s) superfície(s) nomeada(s). |
| `only failed-last-run` | Lê o `eval-report-<ISO-timestamp>.md` mais recente desta feature; re-executa apenas os itens marcados `FAIL` ou `BLOCKED` (o que inclui itens bloqueados por uma execução anterior abortada no meio do Step 5). |
| `keep env` | Pula o tear-down; imprime os detalhes de conexão e o comando explícito de limpeza. |
| `pause on first failure` | Para depois do primeiro item `FAIL`. |

**Immutable core (não pode sofrer override):**

- Fase de quality gates (Step 5) quando o contrato tem uma seção `## Quality gates`. Roda depois do bring-up + pre-flight, fail-fast no primeiro exit não-zero; a execução pula a execução dos itens, mas ainda faz o tear-down (ou respeita `keep env`).
- Pre-flight sobre cada entrada de Prerequisites declarada no contrato.
- Projeção dos ACs em três estados.
- Relatório em arquivo gerado em `<feature-folder>/eval-report-<ISO-timestamp>.md`.
- Anti-escopo (nenhuma mutação no projeto, nenhum commit, limpeza apenas por marcador).

Overrides não reconhecidos ou contraditórios: o default vence; registre em "Overrides ignored" no relatório.

---

## EDGE CASES

- **Contrato sem seção `## Quality gates`.** O Step 5 é pulado silenciosamente; a seção Quality gates do relatório renderiza `*(none)*`. O evaluator não avisa, não aborta — a ausência da seção é um formato de contrato válido.
- **Comando de quality gate não encontrado / erro de parse do shell.** Trate como exit não-zero: a entrada é `✗`, o fail-fast dispara, a execução aborta com `fail (gate <name>)`. O relatório captura o erro do shell no campo de stderr do gate.
- **Implementação ausente.** O bring-up pode ter sucesso mesmo quando rotas / views estão faltando — os itens então dão FAIL com 404 ou similar. O insight defensivo no topo do chat report sinaliza o padrão, mas não muda as marcas dos itens.
- **Projeto não documenta nada sobre avaliação.** As camadas de descoberta 1, 3-5 ainda produzem contexto suficiente para a maioria das stacks. Quando não produzem, a execução aborta com um diagnóstico; a mensagem aponta a camada 2 (`CLAUDE.md` / `harness/`) como o lugar para documentar.
- **Fixture de Static input ausente ou falha na checagem intrínseca.** O pre-flight marca a entrada `✗`; os itens que a consomem ficam `BLOCKED`. A skill nunca cria a fixture.
- **Seed de Persistent state ausente.** Igual ao anterior — itens `BLOCKED`, nenhuma criação automática.
- **Duas execuções concorrentes do evaluator na mesma feature.** Cada execução cria um DB e um tmpdir com nomes únicos. Teoricamente seguro, mas não suportado na prática — podem ocorrer colisões de porta nos serviços. Documente em "Soft-fails" se detectado e recomende serializar.
- **Contrato com zero itens.** Aborte: contrato malformado.
- **Filtro seleciona zero itens.** Aborte com explicação.
- **`keep env` e execução abortada.** O tear-down continua sendo pulado; o usuário inspeciona o estado parcial. Documente isso claramente na saída do chat.
- **Erros de transporte que não são morte de serviço.** Um único item faz 1 retry e depois dá FAIL. Três seguidos → detecção de morte de serviço.
- **Superfície presente no contrato, mas não suportada pela descoberta atual.** Marque cada item dessa superfície `BLOCKED — no driver discovered for surface <name>` e continue com as outras superfícies.
- **Itens subjetivos (`notes: subjective; manual review only`).** Sempre `MANUAL`, independentemente de filtro ou ambiente. Isso inclui todos os itens da seção `## Manual`.
- **Coverage Manifest referencia IDs de itens que não aparecem sob nenhuma seção de superfície.** Trate como contrato malformado; aborte.
- **Item referencia um handle / path / config que NÃO está declarado em Prerequisites.** Trate como contrato malformado; aborte citando a referência problemática.
- **`only failed-last-run` depois de uma execução anterior `clean`.** Nenhum item se qualifica; aborte com explicação ("a execução anterior foi clean; não há o que re-rodar").
- **`only failed-last-run` depois de uma execução anterior `aborted`.** Itens marcados `FAIL` ou `BLOCKED` se qualificam e são re-executados — isso inclui itens marcados `BLOCKED — run aborted at item <ID>: ...` do abort anterior, já que nunca foram exercitados de forma honesta. Itens ainda marcados `PASS` de antes não são re-executados. Se nenhum item se qualificar, aborte com a mesma explicação do caso `clean`.
