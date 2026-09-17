---
name: design-review
description: Avalia a qualidade visual e a usabilidade da UI de uma feature contra uma rubrica ponderada de 4 dimensões (Design Quality, Originality, Craft, Functionality), capturando screenshots em 3 viewports e nos estados de borda (empty / loading / error / focus), rodando um piso mecânico de acessibilidade e produzindo um `design-report-<ts>.md` com nota por dimensão, evidência citada e uma lista de correções acionável pelo `fix-runner`. Complementa o `evaluator`: aquele decide se a feature FUNCIONA, esta decide se ela está BOA. Keywords: "design review", "revisão de UI", "qualidade visual", "avaliar interface", "AI slop", "design gate".
---

# Design Review

Avalia a **qualidade de design** da UI de uma feature. É o eixo ortogonal ao `evaluator`: aquele exercita o `contract.md` e responde *a feature faz o que prometeu?*; esta olha para a tela renderizada e responde *a feature está apresentável?*.

A separação é deliberada. Um contrato pode passar 100 % com uma tela feia, desalinhada e inacessível — nenhum bullet Given/When/Then captura "isso parece um template scaffoldado". Esta skill captura.

**Agnóstica de stack e de projeto.** Descobre rotas, design system e como subir o ambiente a partir da documentação do projeto e da codebase.

**Somente leitura sobre o projeto, exceto pelo relatório e pela pasta de screenshots.** Nunca edita código, estilos, componentes ou tokens — quem corrige é o `fix-runner`. Nunca faz commit, push nem abre PR. Nunca escreve no `prd_progress.json`: o veredito canônico de uma feature pertence ao `evaluator`, e sobrescrevê-lo com uma nota estética corromperia o registro de estado do pipeline.

## INPUT

Free-form. Resolva um alvo de UI e produza um relatório com nota. Formatos aceitos:

- Feature ID (`F03`, `F12`), pasta da feature (`docs/F03-video-upload/`), arquivo dentro dela, ou nome fuzzy (`video upload`).
- `url=<url>` — revisa uma aplicação **já no ar** nessa URL. Pula todo o bring-up (Step 3). Combinável com `routes=`.
- `routes=/a,/b` — lista explícita de rotas a revisar, sobrepondo a descoberta do Step 2.

Overrides opcionais em linguagem natural, em qualquer lugar do input:

| Override | Efeito |
|---|---|
| `threshold=<N>` | Move a linha de `pass` (default `7.0`). |
| `calibration=greenfield` / `calibration=design-system` | Fixa a calibração da dimensão 2 em vez de detectá-la (Step 2). |
| `only mobile` / `only desktop` / `skip tablet` | Restringe os viewports capturados. Reduz a confiança; registrado no relatório. |
| `skip states` | Pula a captura dos estados de borda (empty / loading / error). Reduz a confiança; registrado no relatório. |
| `keep env` | Pula o tear-down; imprime os detalhes de conexão. |
| `no fixes` | Produz as notas sem a seção `## Design fixes`. |

Se a resolução falhar:

- Nenhuma pasta de feature e nenhum `url=` → aborte pedindo um dos dois.
- Pasta resolvida cujo `contract.md` **não tem seção `## UI` nem `## E2E`** → aborte: `feature <ID> declares no UI surface; design-review has nothing to look at`. A skill não inventa telas para revisar.
- Nenhuma rota descoberta e nenhum `routes=` → aborte listando onde procurou.

## OUTPUT

Artefatos por execução:

1. **Chat report (compacto)** — linha de status, tabela de notas, a nota ponderada, os blockers e os `## Design fixes` de severidade `blocker` / `major`, e o path do relatório.
2. **Relatório em arquivo (completo)** em `<feature-folder>/design-report-<ISO-timestamp>.md` (ou `./design-report-<ISO-timestamp>.md` no modo `url=`). Irmão do `contract.md` e dos `eval-report-*.md`. Formato fixado por `references/report-template.md`. Não fica no gitignore.
3. **Screenshots** em `<feature-folder>/design-screenshots-<ISO-timestamp>/`, nomeados `<rota-slug>--<viewport>--<estado>.png`. Toda nota e todo achado referencia um desses arquivos pelo nome.

Nenhum outro arquivo é gravado. Nenhum commit. Nenhuma mudança de código.

---

## EXECUTION STEPS

A skill prescreve a **estrutura** da avaliação (o que capturar, o que medir mecanicamente, como pontuar, o que registrar). É permissiva quanto à **tática** (qual driver de navegador, qual comando sobe o app) — o modelo descobre o que se encaixa no projeto.

### Step 1 — Resolve input

Faça o parsing free-form. Identifique o alvo (pasta da feature **ou** `url=`), os overrides e a lista de rotas se explícita. Calcule `<feature-id>` como o segmento inicial `F<N>` do nome da pasta, em minúsculas e apenas alfanumérico — **a mesma definição de marcador do `evaluator`**, para que a limpeza de órfãos case byte a byte. No modo `url=` sem feature, use `adhoc` como marcador.

Determine `<run-id>` = timestamp ISO 8601 seguro para nome de arquivo (`2026-05-01T17-32-04Z`). A mesma string nomeia o relatório, a pasta de screenshots e o tmpdir.

### Step 2 — Discovery

Leia o projeto em três frentes. Registre a fonte de cada decisão — a seção Discovery do relatório precisa ser auditável.

**a) Ambiente.** Como subir, semear e derrubar. Siga as mesmas 7 camadas de descoberta do `evaluator` (Step 2 daquela skill é canônico; não as reproduzimos aqui): Prerequisites do contrato → docs do projeto (`CLAUDE.md`, `harness/`, `README*`) → `spec.md` Seção 4 → contratos irmãos → inspeção da stack → defaults da stack → abort com diagnóstico. No modo `url=`, pule esta frente inteira.

**b) Rotas a revisar.** Na ordem; a primeira que responder vence:

1. `routes=` no input.
2. Paths de URL citados nos itens `## UI` / `## E2E` do `contract.md` (o `when` de um item de UI quase sempre nomeia a tela).
3. O router do projeto (arquivos de rota, file-based routing, config de router) filtrado pelos componentes que a feature tocou — cruze com os arquivos citados no `plan.md`.

**c) Baseline de design.** Determina a **calibração** da dimensão Originality e o que conta como "fora do padrão". Procure por: tokens de design (`tailwind.config.*`, arquivos de CSS custom properties, `theme.*`), biblioteca de componentes (shadcn/ui, MUI, Chakra, componentes internos em `components/ui/`), guia de marca ou de estilo em `docs/`, e as telas **já existentes** do projeto.

Classifique em um de dois modos e **declare-o no relatório**:

- **`greenfield`** — o projeto não tem design system estabelecido; esta feature é uma das primeiras telas. A dimensão 2 mede **originalidade** no sentido do rubric original: decisões próprias valem, defaults de biblioteca custam.
- **`design-system`** — existe um sistema (tokens, componentes, telas anteriores coerentes). A dimensão 2 é recalibrada para **Intenção e Conformidade**: aderir ao sistema é o comportamento correto e **não** é penalizado; o que se mede é se as decisões dentro do sistema foram consideradas ou preguiçosas, e desviar do sistema sem motivo passa a ser **penalizado**.

> Esta calibração é a correção mais importante sobre o rubric original. Sem ela, a skill premia telas que brigam com o próprio design system do projeto — exatamente o oposto do que se quer num produto real.

### Step 3 — Bring-up

Pulado no modo `url=`. Caso contrário, e com a mesma disciplina de marcador do `evaluator`:

1. Limpe órfãos de execuções anteriores cujos nomes casem com `design-review-<feature-id>-*` (tmpdirs) e `dsg_<feature-id>_*` (DBs). **Nunca remova nada que não case com o marcador.** Se um `processes.lock` candidato tiver PID vivo, aborte: outra execução é dona dele.
2. Instale dependências, crie o DB efêmero `dsg_<feature-id>_<run-id>`, rode migrations.
3. **Semeie dados realistas.** Uma tela vazia não pode ser avaliada — listas com um registro de lorem ipsum escondem problemas de densidade, truncamento e hierarquia. Use os seeds do projeto; se o contrato declara `Persistent state`, semeie-o. Registre o que foi semeado.
4. Suba os runtime services e faça health-check.

Se o bring-up não completar, aborte com status `aborted at step 3` e o que falhou.

### Step 4 — Captura

Para **cada rota** × **cada viewport**, navegue e capture um screenshot de página inteira. Viewports (a menos que restritos por override):

| Nome | Dimensões |
|---|---|
| `mobile` | 390 × 844 |
| `tablet` | 768 × 1024 |
| `desktop` | 1440 × 900 |

Depois, **por rota**, alcance e capture os **estados de borda** que forem atingíveis sem editar código (a menos que `skip states`):

- `empty` — a lista/coleção sem registros (limpe a tabela relevante e recarregue).
- `loading` — o estado transitório (throttle da rede, ou intercepte a requisição e atrase a resposta).
- `error` — a falha (derrube a rota de API ou devolva 500 por interceptação).
- `focus` — a navegação por teclado: dê `Tab` do topo da página até o último elemento interativo.
- `hover` — sobre a ação primária.

Estados inalcançáveis sem tocar no código são registrados como `not reachable` e **reduzem a confiança**, nunca a nota: a skill nunca pune a feature por uma limitação do próprio harness de captura.

> É aqui que a maioria das UIs geradas por IA se desfaz. O caminho feliz em desktop quase sempre está aceitável; o que quebra é a lista vazia sem mensagem, o `error` que renderiza `[object Object]`, o `focus` invisível e a tela em 390 px com scroll horizontal.

### Step 5 — Piso mecânico

Checagens **determinísticas** — nada de julgamento. Rode todas contra cada rota capturada, no viewport `desktop` e no `mobile`. Cada uma é `✓` ou `✗` com o elemento e o valor medido.

| # | Checagem | Critério de `✓` |
|---|---|---|
| M1 | Contraste de texto | Razão ≥ 4.5:1 (texto normal) / ≥ 3:1 (≥ 24 px ou ≥ 19 px bold) — WCAG 2.2 AA |
| M2 | Foco visível | Todo elemento interativo tem indicador de foco discernível ao `Tab` (não `outline: none` sem substituto) |
| M3 | Alvo de toque | Todo controle interativo ≥ 24 × 24 px (AA); registre os < 44 px como observação |
| M4 | Rótulo acessível | Todo input tem `<label>`, `aria-label` ou `aria-labelledby`; todo botão só de ícone tem nome acessível |
| M5 | Alternativa textual | Toda imagem com conteúdo tem `alt` significativo; decorativas têm `alt=""` |
| M6 | Overflow horizontal | `document.scrollWidth <= window.innerWidth` em 390 px |
| M7 | Escala tipográfica | O conjunto de `font-size` distintos na rota é ≤ 8 valores e consistente entre rotas |
| M8 | Sistema de espaçamento | Margens e paddings caem num passo consistente (múltiplo de 4 px ou os tokens do projeto) em ≥ 90 % dos elementos medidos |
| M9 | Hierarquia de headings | Sem nível pulado (`h1` → `h3`); exatamente um `h1` por rota |
| M10 | Movimento | Se há animação, `prefers-reduced-motion: reduce` a suprime |

**Efeito na nota (não negociável).** O piso mecânico limita a dimensão **Craft** por cima — ele não pode elevá-la:

- Qualquer `✗` em M1–M6 é um **blocker de acessibilidade**: Craft fica limitado a **6**, e o status da execução é `fail` independentemente da nota ponderada.
- 1–2 `✗` em M7–M10: Craft limitado a **7**.
- 3 ou mais `✗` em M7–M10: Craft limitado a **5**.

Isso torna metade da avaliação **objetiva**. O rubric original deixava contraste e espaçamento como impressão subjetiva dentro de Craft, onde uma nota generosa os apagava.

### Step 6 — Pontuação

Carregue `references/rubric.md` (lazy, na primeira pontuação). Ele é canônico para as 4 dimensões, as faixas de nota, as duas calibrações da dimensão 2 e o checklist de AI slop.

Pontue cada dimensão de 1 a 10:

```
Weighted Score = ((Design Quality × 2) + (Originality × 2) + Craft + Functionality) / 6
```

**Regras de disciplina de pontuação — aplicadas a toda nota, sem exceção:**

1. **Nota sem evidência é inválida.** Toda nota cita ≥ 1 screenshot pelo nome do arquivo. Quando a evidência não sustenta a faixa, desça para a faixa de baixo.
2. **Toda nota abaixo de 9 nomeia ≥ 2 deficiências concretas**, cada uma com screenshot + elemento (seletor, região ou componente). "Poderia ser mais polido" não é uma deficiência; "o espaçamento entre os cards varia entre 12 px e 20 px na mesma grade — `desktop/default`, `.card-grid`" é.
3. **Vocabulário proibido como justificativa.** `clean`, `modern`, `sleek`, `polished`, `professional`, `moderno`, `limpo`, `elegante` não justificam nota nenhuma sozinhos. Descreva o que está na tela.
4. **Na dúvida entre duas faixas, escolha a de baixo** e explique por quê. O viés natural de um avaliador LLM é elogiar; esta regra o compensa.
5. **O checklist de AI slop é preenchido item a item**, com `sim` / `não` e evidência. Não é opcional e não pode ser resumido — cada `sim` precisa aparecer no raciocínio de Originality.
6. **Confiança declarada.** Se estados foram pulados ou viewports restritos, a linha `**Confidence:**` do relatório desce para `medium` (1 restrição) ou `low` (2+). Uma avaliação `low` nunca produz status `pass` — no máximo `pass-with-findings`.

### Step 7 — Design fixes

A menos que `no fixes`, converta **cada deficiência citada** numa entrada acionável. Sem esta seção o relatório é uma nota sem próximo passo, e o `fix-runner` não tem o que consumir.

Formato por entrada (fixado em `references/report-template.md`):

```
### DSG-<NN> — <título curto>

**Severity:** blocker | major | minor
**Dimension:** Design Quality | Originality | Craft | Functionality
**Evidence:** `<arquivo-do-screenshot>` — `<seletor ou região>`
**Observed:** <o que está na tela hoje, com o valor medido quando houver>
**Change:** <a mudança concreta a fazer, no vocabulário do projeto>
```

Severidade:

- `blocker` — qualquer `✗` de M1–M6, ou qualquer coisa que impeça o uso.
- `major` — custa nota em uma dimensão ponderada 2x, ou quebra em um viewport inteiro.
- `minor` — polimento.

**`Change` precisa ser executável por outra skill sem adivinhação.** "Melhorar a hierarquia visual" é inútil. "Subir o título do card de `text-sm`/400 para `text-base`/600 e baixar o metadado para `text-xs`/`--color-text-muted`, para que o card tenha dois níveis em vez de um" é acionável.

### Step 8 — Veredito e relatório

**Status da execução:**

| Status | Condição |
|---|---|
| `pass` | Ponderada ≥ `threshold` (default 7.0), nenhuma dimensão ≤ 3, nenhum blocker de acessibilidade, confiança `high` |
| `pass-with-findings` | Ponderada ≥ 6.0, nenhuma dimensão ≤ 3, nenhum blocker de acessibilidade |
| `fail` | Qualquer dimensão ≤ 3 **ou** qualquer blocker de acessibilidade (M1–M6) **ou** ponderada < 6.0 |
| `aborted at step <N>` | Falha de infraestrutura nos Steps 1–4 |

O **hard threshold do rubric original é preservado**: uma dimensão ≤ 3 reprova sozinha, por melhor que esteja a média ponderada. Uma feature com Functionality 3 não é salva por ser bonita.

**Delta.** Se existir um `design-report-*.md` anterior para esta feature, acrescente uma linha de delta por dimensão (`Craft 5 → 7 (+2)`). É o que torna o loop de correção legível.

Grave o relatório seguindo `references/report-template.md` e imprima a projeção compacta no chat.

### Step 9 — Tear-down

Idempotente, na ordem: mate os PIDs do `processes.lock`, remova o DB `dsg_<feature-id>_<run-id>`, `rm -rf` no tmpdir. Best-effort — uma falha aqui vira aviso, nunca derruba o relatório. Pulado sob `keep env` (imprima os detalhes de conexão e o comando de limpeza).

---

## INTEGRAÇÃO COM O PIPELINE

Onde esta skill se encaixa entre as outras do `ia-package`:

| Skill | Relação |
|---|---|
| `evaluator` | **Ortogonal e independente.** O `evaluator` verifica o contrato e roda uma *baseline visual* que pega quebra mecânica (imagem quebrada, overlay cortado, layout colapsado). Esta skill começa onde aquela para: uma tela pode passar na baseline visual inteira e ainda assim ser feia. O `evaluator` não referencia esta skill e não deve passar a referenciar. |
| `fix-runner` | **Consumidora.** O `design-report-<ts>.md` alimenta o **Mode C** do `fix-runner`, que lê os `## Design fixes` e aplica as mudanças num commit `style(F<ID>): design pass <N> — …`. |
| `implement-and-evaluate` | **Orquestradora opcional.** Com o override `with design review`, o orquestrador roda esta skill depois do veredito `clean` do `evaluator` e, se ela reprovar, alterna `fix-runner` (Mode C) + `design-review` dentro do seu próprio retry budget. Sem o override, nada muda. |
| `spec-writer` | Nenhum acoplamento. O `contract.md` é lido apenas para descobrir rotas de UI e decidir se a feature tem superfície visual. |

**Por que é opt-in no orquestrador.** A maioria das features de um PRD não tem UI, e qualidade de design é uma decisão de produto, não uma invariante de correção. Transformar isso num gate obrigatório bloquearia PRs de backend por causa de uma nota estética. O gate existe; quem o liga é quem quer.

---

## RULES

**Sempre:**

- Capture antes de pontuar. Nenhuma nota é atribuída a partir da leitura do código-fonte — a avaliação é sobre o que renderiza.
- Cite um screenshot pelo nome do arquivo em toda nota e em todo achado.
- Nomeie ≥ 2 deficiências concretas em toda dimensão abaixo de 9.
- Semeie dados realistas antes de capturar. Uma lista vazia não é uma tela avaliável.
- Detecte a calibração (`greenfield` / `design-system`) e declare-a no relatório antes de pontuar Originality.
- Rode as 10 checagens mecânicas e aplique os tetos que elas impõem a Craft, mesmo quando a tela parecer ótima.
- Preencha o checklist de AI slop item a item.
- Na dúvida entre duas faixas, desça.
- Converta toda deficiência num `## Design fixes` com `Change` executável.
- Preserve o hard threshold: dimensão ≤ 3 reprova sozinha.
- Limpe apenas recursos que casem com os marcadores da skill (`design-review-<feature-id>-*`, `dsg_<feature-id>_*`).

**Nunca:**

- Edite código, estilos, componentes, tokens ou configs. A correção é do `fix-runner`.
- Escreva no `prd_progress.json`. O veredito canônico de uma feature é do `evaluator`.
- Faça commit, push ou abra PR.
- Justifique nota com `clean`, `modern`, `sleek`, `polished`, `moderno`, `limpo` ou `elegante`.
- Atribua nota a uma dimensão sem evidência capturada — desça de faixa em vez de arredondar para cima.
- Penalize a aderência ao design system do projeto sob a calibração `design-system`.
- Puna a feature por um estado que o harness não conseguiu alcançar. Registre como `not reachable` e baixe a confiança.
- Emita `pass` numa execução de confiança `low`.
- Revise uma feature sem superfície de UI declarada. Aborte.
- Edite à mão um relatório gerado. Re-execuções produzem novos arquivos com timestamp.

---

## EDGE CASES

- **Feature sem superfície de UI.** Aborte no Step 1. Não é falha da feature — é alvo errado.
- **Projeto sem design system (primeira tela).** Calibração `greenfield`; o rubric de originalidade vale integralmente.
- **Projeto com design system forte.** Calibração `design-system`; aderir é correto, desviar custa. Registre qual sistema foi detectado e por qual pista.
- **Rota exige autenticação.** Autentique com o usuário semeado do contrato. Se não houver, marque a rota `BLOCKED — no seeded credentials` e reduza a confiança; não invente um bypass de auth.
- **Estado `error` inalcançável sem editar código.** `not reachable`; confiança desce. A skill não adiciona um hook de teste para produzi-lo.
- **App só renderiza no cliente e o screenshot sai em branco.** Espere pelo sinal de prontidão do projeto (network idle, seletor conhecido) antes de capturar. Se ainda assim vier vazio, `aborted at step 4` com o que foi tentado — um relatório sobre uma tela branca não vale nada.
- **Nota alta e blocker de acessibilidade.** Status `fail`. A ponderada não sobrepõe M1–M6. Isso é intencional: uma tela linda que não pode ser navegada por teclado não está pronta.
- **Sem execução anterior.** A linha de delta é omitida, não zerada.
- **Dois relatórios no mesmo segundo.** Impossível na prática (run-id com timestamp); se colidir, sufixe `-b`.
- **`url=` apontando para um app que morreu no meio.** Aborte em `aborted at step 4` nomeando a rota em que a conexão caiu; não pontue com captura parcial.
