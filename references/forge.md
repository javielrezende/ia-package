# Forge — abstração de GitHub ⇄ GitLab

Fonte canônica para toda interação do pipeline com a plataforma de hospedagem do
repositório (o *forge*). As skills `spec-writer`, `implement-and-evaluate`,
`implement-and-evaluate-tmux` e `fix-runner` referenciam este arquivo em vez de
embutir comandos de CLI; o `team-driver.sh` reconhece as duas formas de URL.

Referência a partir de uma skill: `${CLAUDE_PLUGIN_ROOT}/references/forge.md`.

O pipeline usa **seis operações** de forge, e nenhuma delas é essencial para o
trabalho em si. Implementação, avaliação, correção e commits acontecem sem forge
nenhum — o forge só entra no anúncio (issue de acompanhamento e PR/MR). Por isso
toda falha aqui é **soft-fail**: registre, imprima o comando manual e siga.

---

## 1. Resolução do forge

Na ordem; o primeiro que responder vence. Resolva **uma vez por execução** e
guarde em cache — nenhuma skill deve resolver o forge duas vezes.

**(1) Declaração explícita no `CLAUDE.md` do projeto.** Procure uma linha

```markdown
- Forge: github
```

ou `- Forge: gitlab`, sob qualquer heading, no `CLAUDE.md` da raiz do projeto.
Comparação *case-insensitive*; linhas comentadas em HTML (`<!-- ... -->`) são
ignoradas. Se houver mais de uma linha não comentada, use a primeira e registre
soft-fail nomeando as duas. Valor diferente de `github`/`gitlab` → ignore a linha
e siga para (2), com soft-fail.

**(2) Auto-detecção pelo remote.** `git remote get-url origin`:

| URL contém | Forge |
|---|---|
| `github.com` | `github` |
| `gitlab.com`, ou host cujo primeiro rótulo é `gitlab` (ex.: `gitlab.tray.net.br`) | `gitlab` |

GitLab auto-hospedado em host sem `gitlab` no nome não é detectável — declare no
`CLAUDE.md`. É exatamente para isso que o passo (1) existe.

**(3) Sem remote, ou remote não reconhecido.** Assuma `github`, registre soft-fail:

```
forge não detectado (remote ausente ou host não reconhecido); assumindo github.
Declare `- Forge: gitlab` no CLAUDE.md do projeto se for o caso.
```

Registre o forge resolvido e a origem da resolução (`CLAUDE.md` | `remote` |
`default`) no journal, em `Overrides applied`, quando a skill tiver journal.

---

## 2. Pré-checagem do CLI

Cada forge tem um CLI. Duas checagens, nesta ordem:

| Forge | Binário | Autenticação |
|---|---|---|
| `github` | `command -v gh >/dev/null 2>&1` | `gh auth status` |
| `gitlab` | `command -v glab >/dev/null 2>&1` | `glab auth status` |

**CLI ausente.** Não é motivo para descartar trabalho. A mensagem nomeia o CLI
que falta, o que fica de fora e como instalar:

```
CLI `glab` não encontrado — a criação de issue/MR depende dele.
Instale: https://gitlab.com/gitlab-org/cli#installation
(Debian/Ubuntu: veja as instruções de pacote no link; ou `brew install glab`.)
```

Para o GitHub, o link é `https://github.com/cli/cli#installation`
(`sudo apt install gh`, `brew install gh`).

**Quem aborta e quem segue:**

- **`implement-and-evaluate-tmux`, Step 2.4** — aborta a wave *antes* de despachar
  qualquer equipe. É a única exceção, e é deliberada: descobrir no fim de 30min de
  ciclos que nenhum MR pode ser aberto custa mais do que falhar na largada. O abort
  cita a instalação.
- **Todo o resto** (`spec-writer` Step 6, `implement-and-evaluate` Step 7,
  `fix-runner` Mode B com `pr=`) — soft-fail. Os arquivos já estão salvos, os
  commits já estão feitos; só o anúncio não sai.

---

## 3. As seis operações

Cada operação está definida pela **semântica**, não pelo comando. O comando é a
implementação de cada forge. Quando a saída de um forge não casar exatamente com
a do outro, a diferença está anotada na linha — e o chamador filtra do lado dele,
nunca confiando em qualifier de busca específico de plataforma.

### 3.1 — Checar autenticação

Ver a tabela da seção 2. Saída ignorada; só o *exit code* importa.

### 3.2 — Listar issue aberta por prefixo de título

> **Semântica:** encontrar as issues **abertas** cujo título começa com
> `[F<ID>]`. Devolver número e URL de cada uma, no máximo 5.

| Forge | Comando |
|---|---|
| `github` | `gh issue list --search "[F<ID>] in:title" --state open --json number,url,title --limit 5` |
| `gitlab` | `glab issue list --search "[F<ID>]" --per-page 5 -F json` |

**Filtre o resultado no chamador**: mantenha apenas as entradas cujo título de
fato começa com `[F<ID>]`. O `--search` do `glab` varre título *e* descrição, e
nem toda versão do `glab` aceita `--in title`; o filtro do lado do chamador torna
a operação idêntica nos dois forges e dispensa o qualifier. O `glab issue list`
já lista só as abertas por padrão.

Campos na saída JSON: `github` → `number`, `url`, `title`; `gitlab` → `iid`,
`web_url`, `title`. **O número da issue é o `iid` no GitLab**, não o `id` (que é
global da instância).

### 3.3 — Criar issue

> **Semântica:** criar uma issue com título e corpo em Markdown. Sem labels,
> assignees, milestones ou projects. Devolver a URL.

| Forge | Comando |
|---|---|
| `github` | `gh issue create --title "<title>" --body "$(cat <<'EOF'`<br>`<body>`<br>`EOF`<br>`)"` |
| `gitlab` | `glab issue create --title "<title>" --description "$(cat <<'EOF'`<br>`<body>`<br>`EOF`<br>`)" --yes` |

O `glab` chama o corpo de `--description` e abre prompts interativos sem `--yes`.
Em ambiente não interativo (é o caso de toda invocação do pipeline), a ausência
do `--yes` trava a execução até o timeout — ele não é opcional.

### 3.4 — Listar PR/MR pela branch de origem

> **Semântica:** existe PR/MR aberto cuja branch de origem é `<branch>`?
> Devolver número e URL do primeiro.

| Forge | Comando |
|---|---|
| `github` | `gh pr list --head <branch> --json url,number --limit 1` |
| `gitlab` | `glab mr list --source-branch <branch> --per-page 1 -F json` |

Campos: `github` → `number`, `url`; `gitlab` → `iid`, `web_url`.

### 3.5 — Criar PR/MR

> **Semântica:** abrir um PR/MR da branch atual para a branch padrão, com título
> e corpo em Markdown, sem prompt interativo. Devolver a URL.

| Forge | Comando |
|---|---|
| `github` | `gh pr create --title "<title>" --body "$(cat <<'EOF'`<br>`<body>`<br>`EOF`<br>`)"` |
| `gitlab` | `glab mr create --title "<title>" --description "$(cat <<'EOF'`<br>`<body>`<br>`EOF`<br>`)" --source-branch <branch> --target-branch <default-branch> --yes` |

O `gh pr create` infere origem e destino da branch atual e do upstream; o
`glab mr create` é explícito nas duas pontas e, como no 3.3, exige `--yes` para
não abrir prompt.

**Auto-fechamento da issue no merge.** A palavra-chave `Closes #<N>` no corpo
funciona nos dois forges (GitLab também aceita `Closes #<N>` referenciando o
`iid` do mesmo projeto). A seção `## Closes` do body é montada igual nos dois.

### 3.6 — Ver metadados de um PR/MR

> **Semântica:** dado `<URL|número|branch>`, devolver branch de destino, branch de
> origem, estado, título, corpo e URL.

| Forge | Comando |
|---|---|
| `github` | `gh pr view <ref> --json baseRefName,headRefName,state,title,body,url` |
| `gitlab` | `glab mr view <ref> -F json` |

Mapeamento dos campos — **é aqui que os dois forges mais divergem**:

| Semântica | `gh` | `glab` |
|---|---|---|
| branch de destino | `baseRefName` | `target_branch` |
| branch de origem | `headRefName` | `source_branch` |
| estado | `state` | `state` |
| título | `title` | `title` |
| corpo | `body` | `description` |
| URL | `url` | `web_url` |

**Literal de estado aberto:** `OPEN` no GitHub, `opened` no GitLab. Quem checa
"o PR/MR está aberto?" precisa aceitar os dois — comparar com `OPEN` literal
rejeita todo MR do GitLab.

---

## 4. Branch padrão — não é operação de forge

A branch padrão do projeto **não** passa pelo forge. O git sabe responder, e a
resposta é idêntica nos dois:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD   # → origin/main
```

Remova o prefixo `origin/`. Se o comando falhar (clone sem `origin/HEAD` local — é
comum em clone raso ou em worktree criada de um remote novo), o fallback é:

```bash
git remote show origin | sed -n 's/.*HEAD branch: //p'   # → main
```

Ele fala com o remote, então é mais lento e pode falhar sem rede. Se **os dois**
falharem, não aborte: registre soft-fail e trate a branch padrão como
desconhecida. O que depende dela degrada, não trava.

Resolva **uma vez por execução** e guarde em cache.

---

## 5. Invariantes — o que NÃO muda com o forge

> 🔴 Nenhum literal de schema muda. `prd_progress.json` e journals gravados antes
> desta mudança continuam parseáveis, e os dois scripts bash continuam funcionando.

| Literal | Onde | Por quê |
|---|---|---|
| `status: "pr-blocked"` | `prd_progress.json`, journal | lido pelo `team-driver.sh` (`is_terminal`) e pelo `dashboard.sh` |
| `**Pull request:**` | header do bloco final do journal | é âncora de seção, não texto para o usuário |
| `pr_url=` | status file das equipes do tmux | lido pelo `dashboard.sh:81` e pelo template de wave |
| `feat(F<ID>): <Feature Name>` | título do PR/MR | convenção de commit, independente de forge |
| `## Closes` / `Closes #<N>` | body do PR/MR | funciona nos dois forges |

O `team-driver.sh` extrai a URL do journal com um padrão que aceita as duas
formas — `…/pull/<N>` e `…/-/merge_requests/<N>`, em qualquer host, o que cobre
GitLab auto-hospedado. O nome do campo continua `pr_url`.

---

## 6. Vocabulário

"Pull request" e "merge request" são **só texto para o usuário ler**. Use o termo
do forge resolvido em prompts, avisos e relatórios de chat: *"Abrindo o merge
request…"* num projeto GitLab. Quando o forge ainda não foi resolvido, ou quando
o texto vale para os dois, escreva **"PR/MR"**.

Isso **não** vale para âncoras, chaves de schema, nomes de campo nem nomes de
step (`Step 7 — PR creation flow` continua com esse nome). A regra é a mesma da
"Regra de Idioma" do `README.md`: o que carrega peso não muda; o que só é lido
por gente, sim.

---

## 7. Estado de validação dos comandos

> ⚠️ **Os comandos `gh` estão em uso e validados pelo pipeline. Os comandos `glab`
> foram escritos a partir da documentação oficial e NÃO foram executados contra um
> binário local.** Flags do `glab` variam entre versões — em especial `-F json`
> (saída JSON), `--yes` e `--per-page`.
>
> **Na primeira execução real num projeto GitLab**, confirme com
> `glab <comando> --help` antes de confiar num flag. Se um flag não existir na
> versão instalada, a operação cai no soft-fail normal: o trabalho está salvo, e a
> mensagem imprime o comando manual para abrir a issue/MR à mão. Nada se perde —
> só o anúncio sai pelas mãos do usuário.
>
> Ao confirmar um comando contra um `glab` real, atualize a linha aqui e remova
> esta ressalva para o comando conferido.
