---
name: implement-and-evaluate-tmux
description: Despacha uma wave inteira do PRD em paralelo, criando um worktree git isolado e uma janela tmux por feature, cada uma rodando `/implement-and-evaluate` de forma independente. A sessão Main do Claude orquestra apenas o despacho (criação das worktrees, layout do tmux, throttling e a serialização das Foundation Features), depois faz polling até toda equipe atingir um status terminal, e então emite um único relatório consolidado e grava `wave-status.md`. Cada equipe abre seu próprio PR (com resolução de conflitos) no sucesso; falhas preservam a worktree para inspeção. Use quando o usuário quiser tocar uma wave inteira concorrentemente — ex.: `/implement-and-evaluate-tmux wave 3`, `/implement-and-evaluate-tmux F03,F05,F07`, `/implement-and-evaluate-tmux wave 3 except F04`.
---

# Implement and Evaluate (tmux)

Dispatcher ponta a ponta de **nível de wave**. Onde o `implement-and-evaluate` conduz **uma** feature pelo caminho `impl → eval → fix → eval → PR`, esta skill despacha **N equipes independentes** — uma por feature da wave — cada uma na sua própria worktree git e na sua própria janela tmux, cada uma rodando sua própria invocação de `/implement-and-evaluate`.

A sessão Main do Claude é um **dispatcher e consolidador**, não um orquestrador estrito: cria as worktrees, monta a sessão tmux, aplica o throttling e a serialização das Foundation Features, e então faz polling. Ela nunca decide nada no meio do ciclo de nenhuma equipe — essa tomada de decisão vive inteiramente dentro do `/implement-and-evaluate` de cada equipe.

## Core principles

1. **Uma equipe por feature, uma worktree por equipe, uma janela tmux por equipe.** O paralelismo entre features é real e físico: processos separados, working trees separadas, branches separadas.
2. **Reusar, não reinventar.** Cada equipe é literalmente `claude "/ia-package:implement-and-evaluate F<ID>"` rodando na sua janela. O loop de retry, o circuit-breaker, o journaling, a resolução de conflitos e a criação do PR são todos trabalho da skill existente.
3. **Sem orquestração da Main durante os ciclos.** A sessão Main NÃO supervisiona ciclos individuais, não intervém em equipes travadas (exceto pelo timeout de relógio de parede) e não reescreve artefatos de nenhuma equipe. Ela despacha, espera e consolida.
4. **Independência acima de coordenação.** A falha de uma equipe não aborta as outras. Um Ctrl-C do usuário na sessão Main não mata as equipes.
5. **Foundation Features nunca em paralelo.** O Anexo A.3 do PRD marca as features que configuram infraestrutura compartilhada. Elas tocam os mesmos arquivos de scaffolding, então esta skill as despacha uma de cada vez, antes de tudo (Step 5.1).

---

## INPUT

Free-form. Quatro famílias de tokens são reconhecidas; tudo o mais é repassado literalmente à invocação de `/implement-and-evaluate` de cada equipe.

### Family 1 — Seleção (quais features entram nesta wave)

| Forma | Efeito |
|---|---|
| `wave <N>` | Toda feature com `wave == <N>` no `prd_progress.json` cujo `status` esteja em {`pending`, `fail`, `implemented`}. |
| `F0X,F0Y,...` | Feature IDs explícitos (separados por vírgula, espaços opcionais). |
| `wave <N> except F0X[,F0Y]` | A wave menos as exclusões. |
| `wave <N> only F0X[,F0Y]` | A wave restrita às inclusões (interseção). |
| Mistura: `F0X wave <N> except F0Y` | União dos IDs explícitos com os membros da wave, depois as exclusões. |

A seleção PRECISA resolver para ≥1 feature. Seleção vazia → aborte explicando o conjunto resolvido.

**A seleção é resolvida a partir do `prd_progress.json`, nunca por parse do PRD.** O arquivo já carrega `wave`, `dependencies`, `status` e `name` por feature (schema canônico na skill `prd-writer-for-complete-project`, seção "SCHEMA DO ARQUIVO DE PROGRESSO"). O PRD só é lido no Step 1.7, e apenas para descobrir as Foundation Features.

Cada feature selecionada PRECISA ter:
- Uma pasta `docs/F<ID>-<slug>/` contendo `spec.md`, `plan.md` e `contract.md`.
- `status` no `prd_progress.json` fora de {`done`, `removed`, `pr-blocked`, `implementing`} — veja **Step 1.6** para avisos/aborts.
- Todas as dependências declaradas (campo `dependencies`) com `status == "done"` (caso contrário, aborte — dependências dentro da mesma wave estão explicitamente fora de escopo; veja **EDGE CASES**).

### Family 2 — Overrides do dispatcher (valem para a wave, não são repassados)

| Override | Efeito | Default |
|---|---|---|
| `max-parallel=<N>` | Teto de equipes concorrentes. `N ≥ 1`. Ignorado durante a fase serial das Foundation Features. | `3` |
| `team-timeout=<N>m` | Timeout de relógio de parede por equipe. Passado isso, a Main mata a janela tmux e marca a equipe como `timeout` (veja **Step 6**). | `90m` |
| `permission-mode=<modo>` | Modo de permissão do `claude` de cada equipe. Um de `auto`, `acceptEdits`, `manual`, `plan`, `dontAsk`, `bypassPermissions`. Veja **PERMISSÕES**. | `auto` |
| `keep worktrees` | NÃO apagar as worktrees no sucesso da equipe. | off |
| `clean worktrees` | Apagar worktrees mesmo em falha. Mutuamente exclusivo com `keep worktrees`. | off |
| `progress-path=<path>` | Um único `prd_progress.json` usado por toda equipe e pelo reconcile da Main. Repassado a cada equipe. | auto-descoberta |
| `no foundation serialization` | Desliga a serialização do Step 5.1; as Foundation Features passam a concorrer como qualquer outra. Escape hatch para projetos não-greenfield, em que o scaffolding já existe. | off |

### Family 3 — Overrides repassados (por equipe, literalmente para `/implement-and-evaluate`)

Qualquer coisa da gramática do `/implement-and-evaluate` que não esteja nas Families 2 e 4 é repassada literalmente à invocação de cada equipe. Exemplos: `max <N> retries`, `no retries`, `unlimited retries`, `keep eval env`, `with design review`, `max <N> design passes`, `skip lint`, `stub OpenAI`, `only phases 1 and 2`. O mesmo valor vale para todas as equipes (não há targeting por feature nesta versão).

### Family 4 — Overrides bloqueados (incompatíveis com paralelismo)

| Override | Motivo | Ação |
|---|---|---|
| `pause between cycles` | Várias janelas não conseguem todas pausar esperando input humano — a ordem seria indefinida. | Aborte com: `"'pause between cycles' é incompatível com wave paralela; invoque /implement-and-evaluate por feature para execuções passo a passo"`. |
| `pause between phases` | Mesmo motivo. | Mesmo abort. |

### Parsing dos overrides

Faça o parsing da Family 2 primeiro (match mais longo vence), depois da Family 4 (aborte se houver), e deixe o resto como o **`tail`** repassado a cada equipe. Se um token da Family 2 tiver valor inválido (`max-parallel=cinco`, `team-timeout=2horas`, `permission-mode=turbo`), aborte citando o trecho problemático e o formato esperado.

---

## PERMISSÕES

Cada equipe roda `claude --permission-mode <modo>` dentro da sua worktree. O default é **`auto`**: a documentação do Claude Code o define como *"Auto-approves tool calls with background safety checks that verify actions align with your request"* — um classificador revisa cada ação em vez do usuário. É o modo mais permissivo que ainda mantém uma checagem no caminho, e é o que torna a execução autônoma da wave possível sem desligar as verificações.

A escala, do mais restritivo ao mais permissivo:

| Modo | Comportamento na janela da equipe |
|---|---|
| `manual` | Pergunta no primeiro uso de cada tool. A equipe trava esperando o usuário; o `team-timeout` corre enquanto isso. |
| `acceptEdits` | Auto-aceita edições de arquivo e comandos comuns de filesystem. Bash em geral continua perguntando — e o pipeline roda testes, gates e sobe serviços via Bash. |
| `plan` | Só exploração; não edita. Inútil para esta skill. |
| `dontAsk` | Auto-**nega** tudo o que pediria aprovação. A equipe falha em vez de travar. |
| **`auto`** (default) | Auto-aprova com checagem de segurança em background. |
| `bypassPermissions` | Pula os prompts, inclusive escrita em paths protegidos (`.git`, `.claude`). A doc recomenda apenas ambientes isolados (container/VM). |

**Modo de falha a conhecer:** o `auto` pode não estar disponível para a sessão (depende do plano) ou estar desligado por `permissions.disableAutoMode` nas settings. Nesse caso a equipe cai em prompt e fica parada até o `team-timeout` matar a janela. O sintoma no dashboard é uma equipe em `running` com o ciclo sem avançar. A saída é re-rodar com `permission-mode=bypassPermissions` (se o ambiente for isolado) ou acompanhar as janelas manualmente com `acceptEdits`.

---

## OUTPUT

Por execução:

1. **Sessão tmux** chamada `iaet-<wave-tag>-<run-id>` contendo:
   - **Janela 0 — `dashboard`** rodando `dashboard.sh` sob `watch -n 5`. É a fonte de status ao vivo durante a wave.
   - **Janelas 1..N — uma por feature**, chamadas `<F-ID>-<slug>`, cada uma rodando `team-driver.sh`. O driver entra na worktree e roda `claude --permission-mode <modo> "/ia-package:implement-and-evaluate F<ID> <tail>"`; na saída, grava o status terminal da equipe.

2. **Diretório da wave** em `.claude/worktrees/.wave-<run-id>/` contendo:
   - `wave.lock` — lockfile de nível de wave, com PID.
   - `wave.meta` — key=value: wave-tag, started_at, max_parallel, team_timeout, permission_mode, foundation_features, tail, selected_features.
   - `queue.txt` — fila das features ainda não despachadas.
   - `status/F<ID>.status` — um arquivo de status terminal por equipe, gravado pelo team driver.
   - `status/F<ID>.log` — captura de `pipe-pane` do painel do claude (artefato só de debug).
   - `wave-status.md` — artefato consolidado final (formato em `references/wave-status-template.md`).

3. **Worktrees por equipe** em `.claude/worktrees/F<ID>-<slug>/` (preservadas em falha, salvo `clean worktrees`; apagadas no sucesso, salvo `keep worktrees`).

4. **Artefatos por equipe dentro de cada worktree** (produzidos pelo `/implement-and-evaluate`, não por esta skill):
   - `docs/F<ID>-<slug>/orchestration-<ts>.md` (o journal da equipe)
   - `docs/F<ID>-<slug>/eval-report-<ts>.md` (um por invocação do evaluator)
   - Branch `feat/F<ID>-<slug>` com push (no sucesso) e um PR aberto.

5. **Relatório consolidado no chat**, emitido pela Main depois que toda equipe atingiu status terminal. Formato fixado por `references/wave-status-template.md`.

Esta skill nunca edita código, nunca commita e nunca abre PRs. Código, commits e PRs são produzidos pelas invocações de `/implement-and-evaluate` de cada equipe, cada uma a partir da sua própria worktree.

---

## EXECUTION STEPS

### Step 1 — Resolver o input

**1.1 — Calcule `<run-id>`** = timestamp ISO 8601 normalizado para ser seguro em nome de arquivo (ex.: `2026-05-02T18-02-13Z`). Usado no nome da sessão tmux, no diretório da wave e em todo arquivo de status.

**1.2 — Calcule `<wave-tag>`** para legibilidade: se o input contiver `wave <N>`, `<wave-tag>` = `wave-<N>`; caso contrário, `adhoc`. Usado apenas nos nomes de sessão e janelas.

**1.3 — Faça o parsing das famílias** conforme as regras de **INPUT**. Aborte em valor inválido da Family 2 ou em qualquer token da Family 4.

**1.4 — Localize o `prd_progress.json`** (na ordem; o primeiro encontrado vence):
1. O valor de `progress-path=<path>`, quando informado.
2. Busca a partir do CWD para cima (máximo 4 níveis) pelo `prd_progress.json` mais próximo.

Se não for encontrado, **aborte**: `"prd_progress.json não encontrado a partir do CWD (até 4 níveis acima). A seleção por wave depende dele. Gere-o com a skill prd-writer-for-complete-project, ou passe progress-path=<path>."`. Diferente das outras skills do pipeline, aqui o arquivo não é opcional — ele É a fonte da seleção.

Se o arquivo não fizer parse como JSON, aborte citando o erro de parse.

**1.5 — Resolva a seleção para uma lista de pares `(feature_id, slug)`**.

- Se a seleção contiver `wave <N>`, tome toda entrada de `features` cujo campo `wave` seja igual a `<N>`. Aplique os filtros `except` / `only`.
- Acrescente os IDs explícitos passados pelo usuário. De-duplique em silêncio.
- **Ordene** por `priority` ascendente, com empate pelo feature ID mais baixo — a mesma regra de ordenação dentro da wave que o Anexo A.4 do PRD define. (O Step 5.1 reordena as Foundation Features para a frente.)
- Para cada feature ID resolvido, **derive o slug varrendo `docs/`** por uma pasta que case com `F<ID>-*/`. Exatamente um match é exigido:
  - Zero matches → aborte: `"Nenhuma pasta docs encontrada para F<ID>; esperado docs/F<ID>-<slug>/. Rode o spec-writer primeiro."`.
  - Vários matches → aborte: `"Pasta docs ambígua para F<ID>: <lista>. Resolva manualmente antes de re-rodar."`.
  - Exatamente um → registre o par `(feature_id, slug)` (ex.: `(F03, video-upload)`).
- A lista de pares (não apenas de IDs) é o que fica persistido em `wave.meta` e é repassado a todo passo seguinte.

**1.6 — Valide cada feature selecionada**:

- Pasta `docs/F<ID>-<slug>/` existe com `spec.md` + `plan.md` + `contract.md` → se não, aborte listando o trio faltante.
- Inspecione o `status` da entrada no `prd_progress.json`:

| `status` | Ação |
|---|---|
| `done` | Aviso (re-rodar pode regredir para `fail`), mas inclui. |
| `removed` | Aviso (ressuscita a feature), mas inclui. |
| `pr-blocked` | Aviso (pode sobrescrever a tentativa de resolução), mas inclui. |
| `implementing` | Aviso (provável resquício de uma execução anterior que caiu), mas inclui. |
| `pending` / `fail` / `implemented` | Sem aviso. |

- Para cada ID no campo `dependencies` desta feature, cheque `status == "done"`. Se alguma dependência não estiver `done`, aborte com: `"F<ID> depende de F<DEP> (status=<S>); dependências dentro da mesma wave estão fora de escopo. Implemente F<DEP> antes via /implement-and-evaluate e re-rode."`.
- **ID explícito sem entrada no `prd_progress.json`** (o usuário passou `F99` e o arquivo não tem F99): pule a checagem de dependências dessa feature, registre o soft-fail `"F<ID> ausente do prd_progress.json; validação de dependências pulada"` (vai para os Soft-fails do `wave-status.md` no finalize) e prossiga. A checagem do trio continua valendo.

**1.7 — Descubra as Foundation Features** (best-effort, só leitura).

Localize o PRD: use o campo de primeiro nível `prd_path` do `prd_progress.json` quando presente; caso contrário, procure `docs/PRD.md` e depois `PRD.md` a partir do CWD para cima (máximo 4 níveis).

Leia a subseção `### Foundation Features` do `# Appendix A: Implementation Planning` (A.3). Extraia os feature IDs das entradas `- **F<ID> <Nome>** — …`, **preservando a ordem do documento** (o Anexo A.3 as lista em ordem topológica).

- `foundation_ids` = os IDs extraídos.
- `foundation_selecionadas` = `foundation_ids ∩ seleção`, na ordem do A.3.

Modos de falha, todos silenciosos e não bloqueantes:
- PRD não localizável → soft-fail `"PRD não localizado; serialização de Foundation Features pulada"`; `foundation_selecionadas = ∅`.
- Seção A.3 ausente → é o caso normal de um PRD que só acrescenta features a um produto maduro. Sem soft-fail; `foundation_selecionadas = ∅`.

Se o override `no foundation serialization` foi passado, defina `foundation_selecionadas = ∅` e registre em `Overrides applied`.

**1.8 — Seleção vazia depois dos filtros** → aborte com o conjunto vazio explicado (o que a wave trouxe, o que os filtros tiraram).

### Step 2 — Adquirir o lockfile da wave

**2.1 —** Crie `.claude/worktrees/.wave-<run-id>/` (`mkdir -p`).

**2.2 — Lockfile da wave** em `.claude/worktrees/.wave-<run-id>/wave.lock`. Arquivo de uma linha: `<PID> <run-id>`.

- O path é escopado pelo run-id, então dois run-ids diferentes nunca colidem. A checagem de aliveness abaixo importa quando uma execução anterior caiu no meio e deixou o lockfile sob o mesmo `<run-id>` — raríssimo na prática (o run-id é um timestamp novo a cada vez), mas vale a guarda.
- **Aquisição:**
  1. Lockfile não existe → grave-o com o PID atual e o `<run-id>`. Prossiga.
  2. Existe → leia o PID e cheque `kill -0 <pid>`:
     - PID vivo → aborte: `"execução concorrente de /implement-and-evaluate-tmux para <run-id>: PID <N> vivo. Espere ou pare antes de re-rodar."`.
     - PID morto → a execução anterior caiu; sobrescreva e prossiga. Registre em Soft-fails: `"lockfile de wave obsoleto do PID <pid-morto>; sobrescrito"`.
- **Retenção:** veja o Step 7.5 — o lockfile intencionalmente NÃO é liberado.

**2.3 — Checagens de colisão por feature** (worktree E branch são independentes — os dois precisam estar limpos):

**a) Existência da worktree** em `.claude/worktrees/F<ID>-<slug>/`:
- Se existir (`git worktree list --porcelain` a mostra OU o path simplesmente existe), pergunte: `"A worktree de F<ID> já existe em <path> (provavelmente de uma execução anterior). Recriar (apaga a worktree e força a remoção da branch)? [y/N]"`.
- Se o usuário aceitar (`y` / `yes` / `s` / `sim`):
  1. **Se** `<path>/scripts/stop.sh` existir e for executável, rode `(cd <path> && ./scripts/stop.sh --clean)` em best-effort, para derrubar serviços e recursos por branch que o projeto tenha criado. Ignore qualquer erro (a worktree pode estar corrompida, o script pode ter mudado de forma). Se o arquivo não existir, pule em silêncio — é uma convenção de projeto, não um requisito desta skill.
  2. `git worktree remove --force <path>` — o `--force` é obrigatório: a worktree quase sempre tem arquivos não rastreados (logs de serviço, `.pids/`, tmpdirs do evaluator), e sem ele o `git` recusa a remoção.
  3. `git branch -D feat/F<ID>-<slug>` (sempre — a branch sobrevive à worktree por padrão).
- Qualquer outra resposta → aborte a **wave inteira** (nada de prosseguir parcialmente).

**b) Existência da branch** (apenas se a worktree não existia ou acabou de ser limpa): `git rev-parse --verify --quiet feat/F<ID>-<slug>`. Se a branch existir:
- Pergunte: `"A branch feat/F<ID>-<slug> já existe localmente (provavelmente órfã de uma execução anterior). Forçar a exclusão? [y/N]"`.
- Se o usuário aceitar → `git branch -D feat/F<ID>-<slug>`.
- Qualquer outra resposta → aborte a wave inteira.

**2.4 — Resolver o forge e pré-checar o CLI.** Primeiro resolva o forge do projeto (`github` | `gitlab`) conforme `${CLAUDE_PLUGIN_ROOT}/references/forge.md` (seção 1) e guarde em cache para o resto da execução — esse arquivo é canônico para as operações de forge; não improvise comandos de CLI. Só então pré-cheque o CLI **daquele** forge (seção 2): primeiro o binário (`command -v gh` ou `command -v glab`), depois a autenticação (`gh auth status` ou `glab auth status`).

Esta é a **única** pré-checagem de forge que aborta em todo o plugin, e o abort é deliberado: descobrir no fim de 30min de ciclos que nenhuma equipe consegue abrir PR/MR custa muito mais do que falhar na largada. Em todo o resto do pipeline, CLI ausente é soft-fail.

- Binário ausente → aborte a wave nomeando o CLI e como instalar: `"CLI <gh|glab> não instalado; a criação de PR/MR depende dele. Instale (<link da seção 2 de forge.md>) e re-rode."`.
- Não autenticado → aborte a wave: `"CLI <gh|glab> não autenticado; a criação de PR/MR vai falhar. Rode '<gh|glab> auth login' e re-rode."`.

### Step 3 — Inicializar os artefatos da wave

**3.1 —** Grave `.claude/worktrees/.wave-<run-id>/wave.meta`:

```
run_id=<run-id>
wave_tag=<wave-tag>
started_at=<ISO-8601>
max_parallel=<N>
team_timeout=<Nm>
permission_mode=<modo>
foundation_features=<IDs de foundation_selecionadas, separados por vírgula, ou vazio>
progress_path=<path absoluto, ou vazio>
tail=<tail literal da Family 3>
selected_features=F03:video-upload,F05:transcription,F07:admin-panel
```

`selected_features` usa pares **`F<ID>:<slug>`** separados por vírgula. O dispatcher e o dashboard fazem parse desse formato de forma idêntica (`tr ',' '\n' | cut -d: -f1` para IDs, `cut -d: -f2` para slugs).

**3.2 —** Crie `.claude/worktrees/.wave-<run-id>/status/` (vazio por ora).

**3.3 —** Copie os scripts empacotados para o diretório da wave (copiar é mais seguro que symlink quando a pasta de skills está em outro filesystem):

- `scripts/lib-time.sh` → `<wave-dir>/lib-time.sh`
- `scripts/team-driver.sh` → `<wave-dir>/team-driver.sh`
- `scripts/dashboard.sh` → `<wave-dir>/dashboard.sh`
- `scripts/services-tail.sh` → `<wave-dir>/services-tail.sh`
- `scripts/ports-tail.sh` → `<wave-dir>/ports-tail.sh`

Dê permissão de execução a todos (`chmod +x`). A skill os distribui já com o bit de execução, mas a cópia pode removê-lo dependendo do filesystem. **`lib-time.sh` precisa ir junto** — o `team-driver.sh` e o `dashboard.sh` o carregam pelo diretório em que eles próprios estão.

### Step 4 — Criar as worktrees e a sessão tmux

**4.1 — Para cada feature selecionada**, crie a worktree:

```
git worktree add -b feat/F<ID>-<slug> .claude/worktrees/F<ID>-<slug> <default-branch>
```

Descubra a branch padrão conforme a seção 4 de `${CLAUDE_PLUGIN_ROOT}/references/forge.md` (`git symbolic-ref --short refs/remotes/origin/HEAD`, sem o prefixo `origin/`; fallback `git remote show origin`) e guarde em cache para o resto da execução. Isso é git puro e não depende do forge. Se os dois comandos falharem, aborte a wave — sem branch padrão não há base de onde criar as worktrees.

**4.2 — Crie a sessão tmux e a janela do dashboard**:

```
tmux new-session -d -s iaet-<wave-tag>-<run-id> -n dashboard \
    "watch -n 5 '<WAVE_ABS>/dashboard.sh <WAVE_ABS>'"
```

A sessão é criada destacada (`-d`) justamente para sobreviver à morte da sessão Main.

### Step 5 — Despachar

O despacho tem duas fases. Throttling e gestão de fila ficam divididos entre este step (despacho inicial) e o Step 6 (respawn a partir da fila), para que nenhuma chamada Bash isolada precise rodar mais que o timeout da plataforma — só invocações curtas de `tmux new-window` acontecem aqui.

**5.1 — Ordene o despacho e monte a fila.**

Parta da lista ordenada do Step 1.5 e reordene em dois blocos:

1. **Bloco Foundation (serial)** — as features de `foundation_selecionadas`, na ordem do Anexo A.3.
2. **Bloco paralelo** — todas as demais, na ordem do Step 1.5 (priority ascendente, empate por ID).

A regra de despacho:

- Enquanto houver qualquer feature do Bloco Foundation ainda não terminal, o teto de concorrência efetivo é **1**, e apenas features do Bloco Foundation são despachadas. O `max-parallel` é ignorado nessa fase. Nada do Bloco paralelo começa.
- Assim que toda feature do Bloco Foundation atingir status terminal, o Bloco paralelo é despachado normalmente, com throttling por `max-parallel`.

Isso honra a nota do Anexo A.4 do PRD: *"As foundation features não podem ser executadas em paralelo em um projeto greenfield, mesmo que apareçam juntas em uma wave — elas compartilham arquivos de scaffolding."*

Grave a ordem resultante em `<wave-dir>/queue.txt`, um `F<ID>:<slug>` por linha. O **`initial`** é o primeiro item quando há Bloco Foundation, ou os primeiros `min(max-parallel, len(seleção))` itens quando não há. Consuma essas linhas de `queue.txt` ao despachar.

Registre no chat, antes de despachar, uma linha nomeando a decisão quando houver Bloco Foundation: `"F01, F02 são Foundation Features (Anexo A.3) — serão despachadas em série antes das demais."`

**5.2 — Para cada par a despachar**, abra uma janela tmux com **três painéis**:

```
┌───────────────────────┬───────────────────┐
│                       │ services-tail     │
│   claude TUI          │ (logs de serviço) │
│   painel .0           │ painel .1         │
│   ~50% largura        │                   │
│                       ├───────────────────┤
│                       │ ports-tail        │
│                       │ (lsof)            │
│                       │ painel .2 (14 li) │
└───────────────────────┴───────────────────┘
```

- **Painel .0 (esquerda):** o `claude` via `team-driver.sh`.
- **Painel .1 (superior direito):** `services-tail.sh` — descobre os logs de serviço por convenção (`.pids/*.log`, depois `logs/*.log`) e faz `tail -F`. Se o projeto não usar nenhuma das duas, o painel diz o que está procurando e segue esperando, sem travar nada.
- **Painel .2 (inferior direito):** `ports-tail.sh` — descoberta de portas TCP em LISTEN via `lsof`, por processos cujo CWD está dentro da worktree. Totalmente agnóstico de projeto.

Forma concreta (por par):

```bash
WAVE_ABS="$(pwd)/.claude/worktrees/.wave-<run-id>"
SESSION="iaet-<wave-tag>-<run-id>"
TAIL="<tail literal da Family 3>"
PMODE="<permission-mode resolvido>"
WORKTREE_ABS="$(pwd)/.claude/worktrees/F03-video-upload"
WIN="F03-video-upload"

# 1) Cria a janela da equipe com o claude como painel único.
tmux new-window -t "$SESSION" -n "$WIN" \
    "$WAVE_ABS/team-driver.sh F03 video-upload $WAVE_ABS \"$TAIL\" $PMODE"

# 2) Divisor vertical — coluna direita = services-tail (painel .1).
tmux split-window -h -p 50 -t "${SESSION}:${WIN}" \
    "$WAVE_ABS/services-tail.sh $WORKTREE_ABS"

# 3) Divisor horizontal DENTRO da coluna direita — embaixo = ports-tail (painel .2).
#    -l 14 dá 14 linhas ao ports-tail (cabeçalho + ~7 portas com linha de comando).
tmux split-window -v -l 14 -t "${SESSION}:${WIN}.1" \
    "$WAVE_ABS/ports-tail.sh $WORKTREE_ABS"

# 4) Captura APENAS o painel do claude (.0) para o artefato .log de debug.
tmux pipe-pane -t "${SESSION}:${WIN}.0" -o "cat >> $WAVE_ABS/status/F03.log"
```

**Importante: nunca passe o team-driver por `| tee`.** Isso quebra o TTY do claude — ele detecta "não é um terminal" e não produz saída. Use `tmux pipe-pane` depois de criar a janela; ele captura a saída do painel sem interferir no TTY do processo. **Esta mesma sequência de 4 comandos vale para toda janela de equipe**, tanto as do despacho inicial quanto as que o Step 6 respawna a partir da fila — não existe uma forma abreviada para as janelas da fila.

Cada chamada `tmux ...` retorna imediatamente — nenhuma delas bloqueia.

O que o `team-driver.sh` faz dentro de cada janela:
- Grava o status inicial (`status=running`, `started_at=<agora>`, `phase=spawning`).
- Entra na worktree.
- Roda `claude --permission-mode <modo> "/ia-package:implement-and-evaluate F<ID> <tail>"` em foreground na janela tmux.
- Na saída do `claude` (por qualquer motivo): faz parse do bloco Final Verdict do journal mais recente em `docs/F<ID>-<slug>/orchestration-*.md`, grava o status terminal e então `sleep 99999` (mantém a janela viva para inspeção até um `tmux kill-window` ou o teardown da sessão).

### Step 6 — Esperar status terminal, respawnar da fila, aplicar o timeout

Este é o único step de longa duração. A Main NÃO bloqueia numa chamada `Bash` em foreground — waves rotineiramente passam do timeout de 10 minutos do Bash. Use **`Monitor`** (observando o diretório de status) ou **`ScheduleWakeup`** em intervalos de 300s.

A cada tick, rode a lógica de polling. Conceitualmente:

```
loop:
  leia todos os .claude/worktrees/.wave-<run-id>/status/*.status
  TERMINAL = {success, manual-pending, stuck, exhausted, aborted, pr-blocked, timeout}
  para cada equipe despachada (status file existe):
    se status ∈ TERMINAL: marque como concluída
    senão se (agora - started_at) > team_timeout:
      tmux kill-window -t iaet-<wave-tag>-<run-id>:<F-ID>-<slug>
      grave status file: status=timeout, finished_at=<agora>
      marque como concluída
    senão: ainda rodando

  # Teto efetivo: 1 enquanto o Bloco Foundation não terminar (Step 5.1).
  se alguma feature de foundation_selecionadas NÃO é terminal:  TETO = 1
  senão:                                                        TETO = max_parallel

  enquanto (rodando < TETO) E queue.txt não vazia:
    tire o próximo (F<ID>, slug) de queue.txt
    despache-o com a sequência completa de 4 comandos do Step 5.2
    rodando += 1

  se queue vazia E toda equipe despachada concluída: pare
  senão: agende o próximo tick (Monitor / ScheduleWakeup) e encerre este turno
```

Implementação concreta do tick (uma chamada Bash curta, bem abaixo do teto de 10 minutos). Carregue `lib-time.sh` para a conversão de data — ela funciona tanto no Linux quanto no macOS:

```bash
WAVE_DIR="$(pwd)/.claude/worktrees/.wave-<run-id>"
SESSION="iaet-<wave-tag>-<run-id>"
. "$WAVE_DIR/lib-time.sh"
TIMEOUT_S=$(( <team-timeout-minutos> * 60 ))
NOW=$(date -u +%s)

# 1. Aplica o timeout nas equipes que ainda rodam.
for sf in "$WAVE_DIR"/status/*.status; do
    [ -f "$sf" ] || continue
    status=$(awk -F= '$1=="status"     { sub(/^[^=]+=/,""); print; exit }' "$sf")
    started=$(awk -F= '$1=="started_at" { sub(/^[^=]+=/,""); print; exit }' "$sf")
    [ "$status" = "running" ] || continue
    s0=$(iso_to_epoch "$started")
    if [ "$s0" -gt 0 ] && [ $(( NOW - s0 )) -gt "$TIMEOUT_S" ]; then
        fid=$(basename "$sf" .status)
        slug=$(awk -F= '$1=="feature_slug" { sub(/^[^=]+=/,""); print; exit }' "$sf")
        tmux kill-window -t "${SESSION}:${fid}-${slug}" 2>/dev/null || true
        # Reescreve o status preservando os campos, trocando status por timeout.
        { grep -v '^status=' "$sf"; echo "status=timeout"; echo "finished_at=$(now_iso)"; } \
            > "$sf.tmp.$$" && mv -f "$sf.tmp.$$" "$sf"
    fi
done

# 2. Condição de parada: fila vazia E nenhum status running E todas despachadas.
running=$(grep -lE '^status=running$' "$WAVE_DIR"/status/*.status 2>/dev/null | wc -l | tr -d ' ')
spawned=$(ls "$WAVE_DIR"/status/*.status 2>/dev/null | wc -l | tr -d ' ')
queue_left=$(grep -c . "$WAVE_DIR/queue.txt" 2>/dev/null || echo 0)
echo "running=$running spawned=$spawned queue_left=$queue_left"
```

A Main lê esses números, calcula o TETO conforme a regra do Step 5.1, despacha o que couber pela sequência do Step 5.2 e decide se para ou agenda outro tick. Uma atualização curta no chat a cada tick (`"3 equipes rodando, 1 na fila, 2 concluídas"`) é aceitável, mas opcional.

**6.2 — Efeitos colaterais do timeout**: a worktree e a janela tmux de uma equipe que estourou o tempo são preservadas (`clean worktrees` NÃO apaga equipes em `timeout`). `status=timeout` é terminal para efeito da wave e mapeia para `fail` em qualquer reconcile (Step 7.1).

### Step 7 — Consolidar, finalizar, emitir o relatório

**7.1 — Reconciliar o `prd_progress.json` — condicionado ao `progress-path`.**

Dois regimes, com implicações de correção bem diferentes:

**Regime A — `progress-path` NÃO informado (default).**
O `/implement-and-evaluate` de cada equipe rodou dentro da sua própria worktree, na sua própria branch, e gravou na cópia do `prd_progress.json` daquela branch. Essas escritas **já estão commitadas dentro da branch da equipe** — o `implement-and-evaluate` commita os artefatos de avaliação (incluindo o `prd_progress.json`) nos Steps 7.2, 7.6 e 8.4 dele. Elas chegam à branch padrão quando o PR de cada equipe é mergeado. Nunca houve contenção entre worktrees para reconciliar.

→ **NÃO toque no `prd_progress.json` do checkout principal.** Escrevê-lo aqui criaria estado sujo não commitado na working tree principal, conflitando com os merges de PR que vêm a seguir (`git merge` recusa tree suja; e mesmo que não recusasse, produziria conflitos linha a linha porque cada PR carrega as mesmas atualizações de campo).

O retrato da wave vive inteiramente no `wave-status.md` (Step 7.3). O estado das equipes que falharam continua como está no `prd_progress.json` da main até o usuário re-rodá-las; o das equipes que tiveram sucesso chega pelos merges de PR. Isso é correto e livre de conflito.

**Regime B — `progress-path=<path absoluto>` informado.**
O usuário apontou explicitamente todas as equipes para o MESMO `prd_progress.json`, fora das worktrees. As N equipes escreveram concorrentemente, com possibilidade de lost update. O reconcile é necessário e seguro (o arquivo está fora de qualquer branch, então os merges de PR não o tocam).

Para cada equipe neste regime:
- Leia o `docs/F<ID>-<slug>/orchestration-<ts>.md` mais recente da worktree da equipe.
- Mapeie o **Final Verdict.Status** dele para os campos (status, failure_reason, updated_at, completed_at, cycles, report_path). As mesmas regras de mapeamento do bloco de finalize de **PROGRESS TRACKING** do `implement-and-evaluate`.
- Para equipes em `timeout`: `status=fail`, `failure_reason="implement-and-evaluate-tmux: timeout de relógio de parede (<Nm>) excedido"`.

Faça a escrita atômica do arquivo mesclado (read-modify-write do arquivo inteiro de uma vez — reconcile de escritor único).

Se um journal estiver ausente ou não parseável em qualquer um dos regimes, registre um soft-fail e pule o reconcile daquela equipe (o arquivo mantém o estado anterior).

**7.2 — Limpeza das worktrees**:
- Para cada equipe com `status=success`: apague a worktree, salvo `keep worktrees`, com `git worktree remove --force .claude/worktrees/F<ID>-<slug>`. O `--force` é necessário porque a worktree carrega arquivos não rastreados que nenhum commit recolheu (logs de serviço, `.pids/`, tmpdirs do evaluator). A branch e o PR/MR permanecem no forge.
- Para cada equipe com status diferente de `success`: preserve a worktree e a janela tmux, salvo `clean worktrees` (e mesmo assim, NUNCA para equipes em `timeout`).

**7.3 — Grave o `wave-status.md`** em `.claude/worktrees/.wave-<run-id>/wave-status.md` conforme `references/wave-status-template.md`.

**7.4 — Emita o relatório consolidado no chat** conforme a seção "Chat report" do mesmo template: resumo compacto em cima, detalhe por equipe que falhou embaixo.

**7.5 — NÃO libere o lockfile da wave.** Deixe-o para clareza forense. Execuções futuras usam outro `<run-id>`, então não colidem. O lockfile é aposentado implicitamente no momento em que o relatório é emitido.

**7.6 — A sessão tmux continua viva.** O relatório inclui o comando de attach. O usuário pode inspecionar as janelas das equipes que falharam e então `tmux kill-session -t iaet-<wave-tag>-<run-id>` para derrubar tudo. Não mate a sessão por conta própria — isso preserva a inspeção.

---

## PROGRESS TRACKING

Esta skill nunca grava no `prd_progress.json` durante os Steps 1–6. O `/implement-and-evaluate` de cada equipe grava na cópia da sua própria branch (ou num arquivo compartilhado sob o Regime B; veja o Step 7.1).

**Dois regimes determinados pelo `progress-path`:**

- **Regime A (default — sem `progress-path`).** A branch de cada worktree tem seu próprio `prd_progress.json`. As escritas por equipe são isoladas por definição; não há contenção entre worktrees. As atualizações das equipes bem-sucedidas chegam à branch padrão quando os PRs são mergeados — commitadas, porque o `implement-and-evaluate` versiona esses artefatos. As das equipes que falharam ficam nas worktrees preservadas até o usuário re-rodá-las. **A Main NÃO toca no `prd_progress.json` no finalize** — tocá-lo criaria estado sujo na main que bloqueia os merges de PR.

- **Regime B (`progress-path=<path absoluto>`).** Todas as equipes gravaram num único arquivo compartilhado. Escritas concorrentes podem produzir lost updates. **A Main reconcilia no Step 7.1**, como escritor único, lendo o Final Verdict de cada equipe e reescrevendo o arquivo inteiro.

Nos dois regimes, o `wave-status.md` é o retrato canônico de nível de wave (sempre gravado pela Main no Step 7.3).

**Modos de falha — continuação silenciosa (só no Regime B):**
- `prd_progress.json` no `<progress-path>` não encontrado ou não parseável → registre em Soft-fails, pule a reconstrução.
- Journal de uma equipe ausente ou malformado → registre em Soft-fails, pule a entrada daquela equipe.

**Os Steps 1.4–1.6 são a única hora em que a skill LÊ o `prd_progress.json`** — para resolver a seleção, validar e checar dependências. Ela nunca grava durante o pre-flight.

**`progress-path` relativo** (ex.: `progress-path=docs/prd_progress.json`) é resolvido por equipe em relação ao CWD de cada equipe (a worktree dela), então cada uma grava na cópia da sua própria branch — mesma semântica do Regime A. Só um `progress-path` **absoluto** produz a semântica de arquivo compartilhado (Regime B). A skill não normaliza relativo → absoluto.

---

## RULES

**Sempre:**

- Resolva a seleção a partir do `prd_progress.json` (campos `wave`, `dependencies`, `status`, `priority`), nunca por parse do PRD. Aborte quando o arquivo não existir ou não fizer parse.
- Valide o trio (`spec.md` + `plan.md` + `contract.md`) de toda feature selecionada no Step 1.6.
- Valide o fechamento de dependências: toda dependência precisa estar `done`. Dependência dentro da mesma wave = abort.
- Leia o Anexo A.3 do PRD (best-effort) e serialize as Foundation Features selecionadas antes do bloco paralelo, salvo `no foundation serialization`. Anuncie a decisão no chat antes de despachar.
- Adquira `.claude/worktrees/.wave-<run-id>/wave.lock` antes de criar qualquer worktree.
- Use `git worktree add -b feat/F<ID>-<slug> <path> <default-branch>` para criar cada worktree numa branch única.
- Rode `<worktree>/scripts/stop.sh --clean` na limpeza do Step 2.3 **apenas quando o arquivo existir e for executável**; qualquer erro dele é engolido e vira soft-fail. É convenção de projeto, não requisito desta skill.
- Use `git worktree remove --force` em toda remoção de worktree (Steps 2.3 e 7.2) — worktrees sempre têm arquivos não rastreados.
- Aplique o throttling: teto 1 enquanto houver Foundation Feature não terminal; `max-parallel` depois disso.
- Aplique o `team-timeout` por equipe comparando o relógio de parede contra o `started_at` da equipe, usando o `iso_to_epoch` do `lib-time.sh` (funciona em Linux e macOS).
- No timeout, mate a janela tmux da equipe e grave `status=timeout` no status file. Preserve a worktree.
- Crie TODA janela de equipe com a sequência completa de 4 comandos do Step 5.2 (new-window + dois split-window + pipe-pane), inclusive as respawnadas da fila no Step 6.
- Copie `lib-time.sh` junto com os demais scripts no Step 3.3 — `team-driver.sh` e `dashboard.sh` dependem dele.
- Depois que toda equipe atingir status terminal, reconcilie o `prd_progress.json` a partir dos journals **somente se `progress-path` foi informado** (Regime B). Sem ele, deixe o `prd_progress.json` do checkout principal intocado.
- Emita o relatório consolidado conforme a seção Chat report do template.
- Deixe a sessão tmux viva depois do Step 7 para inspeção do usuário. Imprima o comando de attach no relatório.

**Nunca:**

- Edite código, commite, faça push ou abra PRs a partir da sessão Main. Tudo isso é feito pelo `/implement-and-evaluate` de cada equipe, de dentro da worktree dela.
- Faça parse do PRD para resolver a seleção. O PRD só é lido no Step 1.7, só para Foundation Features, e só em best-effort.
- Bloqueie numa chamada `Bash` em foreground esperando as equipes. O timeout de 10 minutos do Bash mataria waves longas. Use `Monitor` ou `ScheduleWakeup`.
- Passe o `team-driver.sh` por `| tee` ou qualquer pipe. Isso quebra o TTY do claude e a janela fica sem saída. Use `tmux pipe-pane`.
- Mate uma equipe no meio do ciclo por qualquer motivo que não seja o timeout de relógio de parede. O `/implement-and-evaluate` da equipe é dono da árvore de decisão (circuit-breaker, retry budget). A Main não intervém.
- Mate as equipes num Ctrl-C / abort da Main. Equipes em tmux sobrevivem à morte da sessão Main por design.
- Repasse overrides da Family 4 (`pause between cycles` / `pause between phases`) — aborte de saída.
- Rode duas waves com o mesmo `<run-id>`.
- Modifique entradas do `prd_progress.json` além das features selecionadas.
- Apague a worktree de uma equipe em `timeout`, mesmo com `clean worktrees`. Timeout = precisa de debug.
- Abra um PR de nível de wave numa checagem "tudo verde". Cada equipe é dona do seu próprio PR.
- Reimplemente qualquer lógica do `/implement-and-evaluate`. Correções vão para lá.
- Despache uma Foundation Feature em paralelo com qualquer outra equipe, salvo `no foundation serialization`.

---

## OVERRIDES

| Override | Família | Efeito | Default |
|---|---|---|---|
| `wave <N>` | 1 | Seleção: features com `wave == N` em status válido. | — |
| `F0X,F0Y,...` | 1 | Seleção: IDs explícitos. | — |
| `... except F0X[,...]` | 1 | Filtra para fora da seleção. | — |
| `... only F0X[,...]` | 1 | Restringe a seleção. | — |
| `max-parallel=<N>` | 2 | Teto de equipes concorrentes (ignorado na fase Foundation). | 3 |
| `team-timeout=<N>m` | 2 | Timeout de relógio de parede por equipe. | 90m |
| `permission-mode=<modo>` | 2 | Modo de permissão do claude de cada equipe. | `auto` |
| `keep worktrees` | 2 | Não apaga no sucesso. | off |
| `clean worktrees` | 2 | Apaga mesmo em falha (exceto `timeout`). | off |
| `progress-path=<path>` | 2 | Repassado a todas as equipes; a Main reconcilia no mesmo arquivo se for absoluto. | auto |
| `no foundation serialization` | 2 | Desliga a serialização do Step 5.1. | off |
| `max <N> retries` | 3 | Repassado a cada equipe. | (default da equipe: 3) |
| `no retries` | 3 | Repassado a cada equipe. | — |
| `unlimited retries` | 3 | Repassado a cada equipe. | — |
| `keep eval env` | 3 | Repassado a cada equipe. | off |
| (outros) | 3 | Repassados literalmente ao `/implement-and-evaluate` de cada equipe. | — |
| `pause between cycles` | 4 | **Abort.** | — |
| `pause between phases` | 4 | **Abort.** | — |

**Immutable core (não pode sofrer override):**
- Uma worktree por equipe, numa branch única a partir da branch padrão.
- `max-parallel ≥ 1`; modelo de execução concorrente.
- Sessão tmux preservada depois do finalize.
- Worktree preservada em status diferente de `success`.
- Seleção vem do `prd_progress.json`.

---

## EDGE CASES

- **`prd_progress.json` ausente** → aborte. É a fonte da seleção; sem ele não há wave. Aponte para o `prd-writer-for-complete-project`.
- **Feature selecionada sem campo `wave`** (arquivo de progresso de uma revisão antiga do schema) → ela nunca casa com `wave <N>`; só entra por ID explícito. Registre soft-fail nomeando as entradas sem `wave`.
- **Seleção vazia depois dos filtros** → aborte, imprima o conjunto resolvido para o usuário entender o que foi filtrado.
- **Feature selecionada com dependência na mesma wave** → aborte com o par ofensor. A skill explicitamente NÃO faz ordenação topológica dentro da wave; isso é sinal de uso errado (o PRD deveria ter dividido a wave).
- **Dependências entre waves ainda não `done`** → aborte com a dependência e o status dela.
- **PRD não localizável no Step 1.7** → soft-fail; a wave roda sem serialização de Foundation. Aceitável: nem todo projeto tem Anexo A.3.
- **Anexo A.3 ausente do PRD** → caso normal de PRD que só acrescenta features a um produto maduro. Sem soft-fail, sem serialização.
- **Uma Foundation Feature falha** → a wave **continua** e despacha o resto normalmente. Isso é consistente com o princípio 4 (independência) e com o grafo de dependências: se alguma feature do bloco paralelo dependesse dela, estaria em outra wave e o Step 1.6 já teria abortado. Registre em Soft-fails e destaque no relatório: `"F01 (Foundation) terminou em <status>; as features seguintes rodaram sobre um scaffolding possivelmente incompleto"`.
- **Toda a seleção é Foundation** → a wave roda inteiramente em série. Funciona; só é lenta. O dashboard mostra uma equipe rodando por vez.
- **Worktree existe de uma execução anterior** → prompt interativo (Step 2.3). Se o usuário recusar, aborte a wave inteira.
- **`scripts/stop.sh` não existe na worktree órfã** → pule em silêncio. O `git worktree remove --force` é o que de fato libera o path.
- **`stop.sh --clean` falha dentro de uma worktree obsoleta** → engula o erro, registre soft-fail; o `--force` resolve o path de qualquer jeito.
- **CLI do forge (`gh` ou `glab`) não instalado ou não autenticado** → aborte de saída no Step 2.4. Sem isso, a criação de PR/MR falharia no fim de toda equipe. É a única pré-checagem de forge que aborta no plugin; veja `references/forge.md` § 2.
- **Forge não detectável** (sem remote, ou GitLab auto-hospedado em host sem `gitlab` no nome) → o Step 2.4 assume `github` e registra soft-fail. Se o projeto for GitLab, a wave inteira vai pré-checar o CLI errado e abortar. A saída é declarar `- Forge: gitlab` no `CLAUDE.md` do projeto (`references/forge.md` § 1).
- **`git worktree add` falha** (branch já existe, mudanças não commitadas) → aborte com o erro do git; limpe as worktrees já criadas nesta execução.
- **O `/implement-and-evaluate` de uma equipe aborta pré-fase** (dependência ausente, contrato vazio) → o Final Verdict do journal dela captura isso; o status file recebe `status=aborted`. As outras equipes continuam.
- **Timeout de relógio de parede dispara** → mate a janela tmux da equipe; grave `status=timeout`; worktree preservada. As outras continuam.
- **Todas as equipes dão timeout** → o relatório mostra N timeouts. Status da wave = `all-failed`. O usuário investiga cada worktree.
- **`permission-mode=auto` indisponível na sessão** (plano ou `permissions.disableAutoMode`) → a equipe cai em prompt e fica parada até o timeout. Sintoma: `running` no dashboard com o ciclo sem avançar. Veja **PERMISSÕES** para a saída.
- **O processo claude de uma equipe morre sem gravar o Final Verdict** → o status file fica em `status=running` (o driver não chegou a escrever o terminal). A Main trata como `timeout` quando o relógio estoura; registre `crashed-without-status` nos soft-fails.
- **Colisão de PR: PRs de duas equipes tocam os mesmos arquivos** → não é problema desta skill. Cada `/implement-and-evaluate` resolve seus conflitos no Step 7 dele. Se o usuário mergear os dois PRs/MRs em sequência, o próprio forge cuida do merge humano do segundo.
- **Ctrl-C / SIGTERM na Main** → as equipes continuam no tmux. Nenhum relatório consolidado é emitido. O usuário pode `tmux attach -t iaet-<wave-tag>-<run-id>`. A sessão foi criada destacada (`new-session -d`) precisamente para sobreviver à Main.
- **`max-parallel=1`** → wave totalmente serial; ainda assim roda em worktrees + tmux pelo isolamento.
- **`max-parallel=N` maior que o número de features** → sem throttling; todas as do bloco paralelo sobem de uma vez. Tudo bem.
- **A mesma feature listada duas vezes** (ex.: `wave 3 F03` com F03 na wave 3) → de-duplique em silêncio na seleção.
- **Uma equipe termina em segundos** (feature já pronta, contrato de verdade vacuosa) → o status file vai direto para `success`. A worktree é limpa (salvo `keep worktrees`). Sem caso especial.
- **O usuário faz attach na janela do dashboard e depois detach** → sem impacto. O dashboard roda sob `watch`, independente de attach.
- **O usuário faz attach na janela de uma equipe e digita no prompt do claude** → é prerrogativa dele; o texto injetado entra na interação daquela equipe. Fora do escopo da skill.
- **Branch `feat/F<ID>-<slug>` existe de uma execução anterior mas a worktree já foi removida** → pego pelo Step 2.3 (b); prompt interativo para forçar a exclusão. Recusar aborta a wave.
- **Várias pastas casam com `docs/F<ID>-*/`** (ex.: `F03-video-upload-old/` ao lado de `F03-video-upload/`) → o Step 1.5 aborta com a lista de candidatos.
- **Projeto sem `.pids/` nem `logs/`** → o painel de serviços fica esperando e diz o que procura. Nenhum impacto na equipe; o `ports-tail` continua mostrando as portas, que é o sinal que realmente importa.
- **`lsof` não instalado** → o painel de portas mostra a instrução de instalação e dorme. Nenhum impacto na equipe.
- **Wave acumulando mais de 24h** → não é problema da skill. O `team-timeout` limita cada equipe; a duração da wave = a fase serial + max(durações) do bloco paralelo + tempo de fila. Use `team-timeout=4h` se o build realmente precisar.

---

## BUNDLED FILES

**`scripts/`** — executáveis copiados para o diretório da wave no Step 3.3 e rodados de lá:
- `scripts/lib-time.sh` — helpers de tempo (`now_iso`, `iso_to_epoch`, `fmt_elapsed`). Carregado pelo `team-driver.sh`, pelo `dashboard.sh` e pelo tick do Step 6. A conversão de data tenta a sintaxe GNU e depois a BSD, então o `team-timeout` e os tempos decorridos funcionam em Linux/WSL2 e em macOS.
- `scripts/team-driver.sh` — roda no painel ESQUERDO (.0) da janela de cada equipe. Sobe o `claude /implement-and-evaluate` e grava o status terminal na saída.
- `scripts/services-tail.sh` — roda no painel SUPERIOR DIREITO (.1). Descobre logs de serviço por convenção (`.pids/*.log`, `logs/*.log`) e faz `tail -F`. Degrada com aviso na tela quando o projeto não usa nenhuma das convenções.
- `scripts/ports-tail.sh` — roda no painel INFERIOR DIREITO (.2). Descobre por `lsof` as portas TCP em LISTEN de processos cujo CWD está dentro da worktree. **Agnóstico de projeto** — não lê `.env` nem assume nada do projeto.
- `scripts/dashboard.sh` — roda na janela 0. Lê os journals e os status files e renderiza a tabela de status ao vivo.

**`references/`** — documentos só de leitura que o orquestrador consulta e nunca executa:
- `references/wave-status-template.md` — formato fixado do `wave-status.md` E do relatório consolidado no chat.
- `${CLAUDE_PLUGIN_ROOT}/references/forge.md` (raiz do plugin) — canônico para a resolução do forge, a pré-checagem de CLI e as seis operações de GitHub/GitLab usadas pelo pipeline.
