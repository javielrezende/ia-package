---
name: prd-writer-for-complete-project
description: |
  Gere PRDs (Product Requirements Documents) completos e exclusivamente de negócio, por meio de uma entrevista estruturada. Use quando: (1) Iniciar um novo projeto e precisar de requisitos estruturados, (2) Criar a especificação de produto no formato de PRD de 12 seções, (3) Definir problema, escopo, requisitos funcionais e não funcionais, decisões de produto, dependências, riscos, critérios de aceitação e estratégia de validação a partir de uma descrição ou arquivos de contexto. O PRD NÃO contém decisões técnicas — arquitetura, stack e implementação ficam para HLD/FDD. Escrito em português (pt-BR), mantendo em inglês apenas títulos de seção e labels estruturais. Keywords: "prd", "product requirements", "create PRD", "generate PRD", "new product", "requirements document", "requisitos de produto".
---

# PRD Writer — Documento de Requisitos de Produto (apenas negócio)

Você gera PRDs completos e detalhados por meio de uma entrevista estruturada. Seja direto e objetivo.

**Princípio central:** o PRD descreve **o problema, o público, o valor e o que o produto precisa entregar**. Ele nunca descreve **como** o produto será construído. Toda decisão de arquitetura, tecnologia, stack, modelagem de dados ou implementação pertence ao desenho técnico — o HLD, o FDD ou o `spec.md` da feature —, não a este documento.

---

## PARÂMETROS DE ENTRADA (INPUT PARAMETERS)

A partir do comando de invocação, você recebe:
- `PROJECT_NAME`: Nome do projeto
- `OUTPUT_FOLDER`: Pasta onde salvar o PRD
- `PRD_PATH`: Caminho completo (full path) para o arquivo do PRD
- `PROGRESS_PATH`: Caminho completo para o arquivo de progresso. Quando não informado, o padrão é `{OUTPUT_FOLDER}/prd_progress.json`.
- `PRODUCT_DESCRIPTION`: Conteúdo combinado do contexto (arquivo ou pasta) e/ou descrição

---

## FRONTEIRA DE NEGÓCIO (BUSINESS BOUNDARY)

Esta é a regra mais importante da skill. Ela vale para as **Seções 1 a 12** do PRD. O Anexo A é a única exceção e está explicitamente marcado como não fazendo parte do PRD.

### Teste do "o quê vs. como"

Antes de escrever qualquer frase, pergunte:

- A frase responde **O QUE** o usuário obtém, observa, precisa ou exige? → **é negócio, entra no PRD**
- A frase responde **COMO** o sistema faz aquilo internamente? → **é técnica, não entra**

Exemplos do teste:
- ✅ "O relatório mensal fica disponível até o 5º dia útil" — o quê
- ❌ "Um job agendado roda todo dia 5 e grava na tabela `reports`" — como
- ✅ "O usuário envia arquivos de até 2 GB e vê o progresso do envio" — o quê
- ❌ "O upload usa multipart em chunks de 5 MB para o S3" — como
- ✅ "O usuário faz login e permanece autenticado por 30 dias no mesmo dispositivo" — o quê
- ❌ "Autenticação via JWT com refresh token em cookie httpOnly" — como

### PROIBIDO nas Seções 1-12

- Linguagens, frameworks, bibliotecas, runtimes, versões
- Bancos de dados, ORMs, schemas, tabelas, colunas, tipos de dado, índices
- Estilo de arquitetura: monolito, microservices, filas, cache, CDN, serverless, event-driven
- APIs, endpoints, payloads, protocolos, contratos técnicos, formatos de transporte
- Cloud, infraestrutura, containers, CI/CD, deploy, ambientes técnicos
- Nomes de produtos de fornecedores de tecnologia (Redis, Postgres, S3, Whisper, Kafka...) — a exceção está abaixo
- Estrutura de código, arquivos, módulos, camadas, padrões de projeto
- Estimativas em story points, sprints, sequenciamento de implementação

### PERMITIDO (isto é negócio, não técnica)

- Limites observáveis pelo usuário: tamanho máximo de arquivo, quantidade de itens, prazo de conclusão, tempo de resposta percebido
- Formatos que o usuário escolhe ou recebe: PDF, CSV, XLSX, MP4
- Canais e plataformas como decisão de produto: web, app mobile, e-mail, WhatsApp — porque definem onde o usuário está, não como o código roda
- Integrações descritas pelo valor de negócio: "emitir nota fiscal junto à prefeitura", "cobrar no cartão do cliente" — sem detalhar o mecanismo
- Fornecedores quando são **decisão comercial já contratada** (custo, contrato, SLA fornecido) — nesse caso aparecem na Seção 9 (Dependencies), descritos pelo que entregam ao negócio, nunca pelo modo de integração
- Requisitos de conformidade legal e regulatória
- Volumes e metas de negócio: número de usuários, transações por mês, janela de indisponibilidade tolerada

### Regra de redirecionamento durante a entrevista

Se o usuário trouxer uma decisão técnica, **não discuta e não recuse**. Registre e redirecione em uma frase:

> "Anotei — isso é decisão técnica e vai para o HLD/FDD. Para o PRD, o que o usuário precisa ver ou obter por causa disso?"

Mantenha uma lista interna **"Notas técnicas para o HLD"** com tudo que o usuário trouxe e que foi deixado de fora. Na Fase 5, apresente essa lista ao usuário no chat e ofereça salvá-la em `{OUTPUT_FOLDER}/PRD-technical-notes.md`. Ela **nunca** entra no arquivo do PRD.

---

## PROCESSO DE TRABALHO (5 FASES)

### FASE 1: Entendimento Inicial

**Passo 1: Confirmar Entendimento**

Confirme seu entendimento em uma frase clara resumindo a descrição do produto e o contexto do projeto.

**Passo 2: Explorar o Contexto do Projeto**

Analise o diretório atual em busca de material de **negócio** já existente:
- Procure por: PRDs anteriores, documentos de visão, pesquisa de usuário, glossários de domínio, regras de negócio documentadas (docs/, .codekit/, etc.)
- Extraia: personas já definidas, vocabulário do domínio, regras de negócio, métricas já acompanhadas, integrações de negócio existentes
- Se houver código, use-o **apenas** para inferir capacidades e vocabulário de domínio já existentes. Não traga stack, arquitetura ou estrutura de código para o PRD.
- Resuma: "Contexto do projeto: [novo projeto / produto existente que já cobre X, Y, Z]"
- Se for greenfield: "Contexto do projeto: novo projeto — sem contexto existente"

---

### FASE 2: Entrevista Estruturada (Mandatory Clarification)

Conduza uma entrevista **uma pergunta por vez**, percorrendo a agenda de 12 blocos abaixo, na ordem. A entrevista é adaptativa:

- **Pule** o que a `PRODUCT_DESCRIPTION` ou o contexto do projeto já responderam de forma inequívoca. Diga o que assumiu e siga.
- **Aprofunde** quando a resposta for genérica, ambígua ou contraditória com algo já dito.
- **Máximo de 3 perguntas por bloco.** Se após 3 perguntas o bloco ainda estiver aberto, registre o que falta como *Open Question* (Seção 8) e avance. Não interrogue o usuário.
- Sempre que fizer sentido, **ofereça uma resposta recomendada** ("Sugiro X porque Y — confirma?"). É mais rápido confirmar do que redigir do zero.
- Aplique a **Regra de redirecionamento** da Fronteira de Negócio sempre que a conversa derivar para técnica.

**Agenda da entrevista (blocos → seções do PRD):**

| Bloco | Tema | Alimenta |
|---|---|---|
| B1 | O que é o produto, para quem, qual o valor central, vocabulário do domínio | Seção 1 |
| B2 | Qual dor existe hoje, quem sente, qual o custo de não resolver, o que já foi tentado | Seção 2 |
| B3 | Quem são os perfis de usuário, quais jornadas reais eles percorrem, quais cenários de uso são críticos | Seção 3 |
| B4 | O que o negócio quer alcançar, como saberá que deu certo, qual o baseline atual e a meta | Seção 4 |
| B5 | O que está dentro desta versão, o que fica de fora, o que é não-objetivo declarado | Seção 5 |
| B6 | Quais capacidades o produto precisa entregar, quais regras de negócio e limites concretos, o que é essencial vs. incremento | Seção 6 |
| B7 | Que qualidades o produto precisa ter para ser aceitável: desempenho percebido, disponibilidade, volume, privacidade, conformidade, acessibilidade, suporte | Seção 7 |
| B8 | Que decisões de produto já foram tomadas, quais alternativas foram descartadas, o que se aceitou perder | Seção 8 |
| B9 | De quem/do quê o produto depende para existir: fornecedores, times, aprovações, dados, exigências legais | Seção 9 |
| B10 | O que pode dar errado no nível de negócio, qual a probabilidade e o impacto, o que se faz a respeito | Seção 10 |
| B11 | Como se comprova, objetivamente, que cada capacidade foi entregue | Seção 11 |
| B12 | Como o produto será validado antes e depois do lançamento, quem valida, o que define "aprovado" | Seção 12 |

**Regra de encerramento:** só encerre a entrevista quando todos os 12 blocos tiverem sido visitados (respondidos, inferidos com aviso, ou registrados como *Open Question*).

**Fechamento da entrevista (obrigatório):**

Apresente ao usuário, antes de gerar o PRD:

1. **Resumo do entendimento** — 5 a 10 bullets cobrindo produto, problema, público, escopo e objetivos
2. **Assumptions** — a lista explícita do que você **inferiu** e o usuário não confirmou, cada uma com o que muda no PRD se estiver errada
3. **Open Questions** — o que ficou sem resposta e será marcado `[A DEFINIR]` no documento
4. **Notas técnicas para o HLD** — o que o usuário trouxe e ficou de fora por ser técnico

Peça confirmação. Só então informe que está pronto para gerar o PRD.

---

### FASE 3: Construção do PRD

Gere o PRD com base nas respostas da FASE 2 + contexto do projeto. Não peça aprovação seção por seção. Escreva e apresente o documento inteiro de uma vez.

**Regra de Idioma (obrigatória):**
- Escreva TODO o conteúdo em **português (pt-BR)**, com acentuação correta.
- Mantenha em **inglês** apenas os elementos estruturais, porque outras skills (`spec-writer`, `implement-feature`) localizam essas âncoras no documento:
  - Os títulos das 12 seções (`## 1. Summary and Context` ... `## 12. Validation and Test Strategy`) e o título `# Appendix A: Implementation Planning`
  - Subtítulos e labels: `Glossary`, `Assumptions`, `Primary Users`, `Behavioral Profile`, `Use Scenarios`, `In Scope`, `Out of Scope`, `Non-Goals`, `Core Scope`, `Full Scope additions`, `Capabilities`, `Experience`, `Error Handling`, `Open Questions`, `Cross-Feature Integration`
  - Cabeçalhos de tabela e labels do Anexo A: `# | Feature | Priority | Dependencies`, o valor `None`, `Consumes`, `Provides`, `Feature Data Contracts`, `Dependency Graph`, `Foundation Features`, `Execution Waves`, `Priority levels`, `Use Scenario Coverage`, `UC | Features | Owner`
- Termos consagrados do domínio (upload, e-mail, dashboard, nomes de formatos) permanecem como são, dentro do texto em português.
- O arquivo de progresso (`prd_progress.json`) não é texto redigido: chaves e valores de `status` seguem exatamente o schema de `${CLAUDE_PLUGIN_ROOT}/references/progress-schema.md`, em inglês. Apenas o `name` de cada feature é copiado do PRD como está.

**Regra de Ouro (Golden Rule) — três casos, não dois:**

1. **O usuário respondeu** → USE a resposta dele, literalmente.
2. **Não respondeu, mas o valor é derivável com segurança do domínio** (ex.: formatos usuais, fluxos padrão de cadastro, categorias óbvias de erro) → INFIRA de forma específica **e registre em `Assumptions` (Seção 1)** com o identificador `A<NN>`.
3. **Não respondeu e o valor NÃO é derivável com segurança** — metas de métrica, SLAs, volumes esperados, prazos legais, limites contratuais, preços, capacidade de equipe → **NÃO INVENTE**. Escreva `[A DEFINIR]` no lugar do valor e registre a pendência em `Open Questions` (Seção 8) com o identificador `Q<NN>`.

> Nunca fabrique um número que soe preciso para preencher um espaço. Um `[A DEFINIR]` visível vale mais do que um SLA inventado que alguém vai tratar como compromisso.

**Sistema de identificadores:**

| Prefixo | O que identifica | Onde é usado |
|---|---|---|
| `F01`…`F99` | Feature (agrupador funcional) | Seções 5, 6, 11 e Anexo A |
| `RF<feature>.<n>` | Requisito funcional individual (ex.: `RF01.3`) | Seção 6, referenciado na Seção 11 |
| `RNF<NN>` | Requisito não funcional | Seção 7, referenciado nas Seções 11 e 12 |
| `D<NN>` | Decisão de produto | Seção 8 |
| `Q<NN>` | Questão em aberto | Seção 8 |
| `DEP<NN>` | Dependência | Seção 9 |
| `R<NN>` | Risco | Seção 10 |
| `A<NN>` | Premissa (assumption) | Seção 1 |

Todos os IDs são zero-padded para 2 dígitos, sequenciais, sem lacunas. PRDs típicos têm de 5 a 15 features. Menos de 3 sugere agrupamento largo demais; mais de 20 sugere consolidar capacidades relacionadas.

**Agora carregue `references/prd-sections.md`** (carregamento lazy, aqui na FASE 3) — ele é a fonte canônica do conteúdo das 12 seções e do Anexo A: o que cada seção carrega, o formato de cada bloco e as regras de cada uma. Escreva o documento seguindo esse arquivo e então prossiga para a FASE 4.

---

### FASE 4: Validação (INTERNA)

> Retomando o processo de 5 fases, após a redação do documento na FASE 3.

ANTES de salvar, valide internamente.

**Fronteira de negócio (bloqueante):**
- [ ] Nenhuma das Seções 1-12 nomeia linguagem, framework, biblioteca, banco de dados, ORM, schema, endpoint, protocolo, provedor de infraestrutura, container ou padrão de arquitetura
- [ ] Nenhum requisito das Seções 6 e 7 descreve COMO o sistema faz algo internamente — todos descrevem o resultado observável
- [ ] Fornecedores de tecnologia aparecem apenas na Seção 9, descritos pelo valor de negócio entregue
- [ ] A Seção 8 contém apenas decisões de produto/negócio, nenhuma decisão de arquitetura ou stack
- [ ] A Seção 12 não menciona frameworks de teste, cobertura de código, CI ou automação de pipeline
- [ ] O Anexo A está presente com o aviso literal de que não faz parte do PRD

**Idioma:**
- [ ] Todo o conteúdo redigido está em português (pt-BR) com acentuação correta
- [ ] As âncoras estruturais permanecem em inglês (títulos das 12 seções e do Anexo A; `Glossary`, `Assumptions`, `Primary Users`, `Behavioral Profile`, `Use Scenarios`, `In Scope`, `Out of Scope`, `Non-Goals`, `Core Scope`, `Full Scope additions`, `Capabilities`, `Experience`, `Error Handling`, `Open Questions`, `Cross-Feature Integration`, `Consumes`, `Provides`, `Feature Data Contracts`, `Dependency Graph`, `Foundation Features`, `Execution Waves`, `Priority levels`, `Use Scenario Coverage`; cabeçalhos da tabela de dependências, da tabela `UC | Features | Owner` e `None`)

**Rastreabilidade ponta a ponta:**
- [ ] Cada categoria de dor (Seção 2) tem ao menos uma feature (Seção 6) que a endereça
- [ ] Cada objetivo (Seção 4) tem ao menos uma métrica com baseline, meta e forma de medição — ou `[A DEFINIR]` registrado
- [ ] Cada persona (Seção 3) aparece em ao menos um cenário de uso
- [ ] Cada cenário de uso (Seção 3) é coberto pelas features da Seção 6
- [ ] Cada feature da Seção 6 aparece em `In Scope` (Seção 5) exatamente uma vez
- [ ] Cada `RF` da Seção 6 tem ao menos um critério na Seção 11 que o referencia
- [ ] Cada `RNF` Must have da Seção 7 tem critério em `Non-Functional Acceptance` (Seção 11) e forma de validação na Seção 12
- [ ] Cada cenário multi-feature da Seção 3 gera um critério em `Cross-Feature Integration`
- [ ] Sem contradição entre `In Scope` e `Out of Scope`

**Honestidade dos dados:**
- [ ] Toda ocorrência de `[A DEFINIR]` tem linha correspondente em `Open Questions` (Seção 8), e vice-versa
- [ ] Toda premissa inferida está registrada em `Assumptions` (Seção 1) com o efeito de estar errada
- [ ] Nenhum número de baseline, meta, SLA, volume ou prazo foi inventado sem confirmação do usuário ou registro como premissa

**Qualidade das seções novas:**
- [ ] Toda decisão da Seção 8 nomeia alternativas descartadas e o que se perde no trade-off
- [ ] Toda dependência bloqueante da Seção 9 tem risco correspondente na Seção 10
- [ ] Todo risco da Seção 10 tem mitigação E contingência preenchidas, e severidade coerente com probabilidade × impacto
- [ ] Todo RNF da Seção 7 tem alvo mensurável (número ou condição binária)
- [ ] A Seção 12 define critérios objetivos de saída e critérios numéricos de reversão

**Anexo A — integridade do grafo:**
- [ ] Sem dependências órfãs — todo ID em `Dependencies` existe na coluna `#`
- [ ] Sem ciclos — o grafo é um DAG
- [ ] Ordem topológica — nenhuma linha referencia dependência que aparece abaixo dela
- [ ] Desempate topológico pelo ID mais baixo
- [ ] Edges do Mermaid correspondem exatamente à coluna `Dependencies`
- [ ] `Dependencies` é superset de `Consumes` (A.1)
- [ ] `Priority` numérica bate com a `Priority` MoSCoW da Seção 6 (Must=1, Should=2, Could=3)
- [ ] Cobertura de waves — toda feature aparece exatamente em uma wave
- [ ] Cálculo de waves — `max(wave das dependências) + 1`; Wave 1 tem exatamente as features sem dependências
- [ ] Ordenação dentro da wave por priority ascendente, empate por ID
- [ ] `Full Scope additions` só aparece em features que também têm `Core Scope`
- [ ] Consistência de campos — todo dado nomeado em `Consumes` é coberto pela entrada `Provides` correspondente (mesmo nome, ou termo claramente mais amplo que o contém). Se não houver correspondência explícita, expanda o `Provides` para nomeá-lo em vez de depender de cobertura implícita
- [ ] `Foundation Features` (quando presente): toda feature listada existe na tabela, em ordem topológica, com descrição da contribuição; a nota de serialização está em `Execution Waves`

**Anexo A — cobertura dos cenários (A.6):**
- [ ] `A.6 Use Scenario Coverage` está presente se, e somente se, a Seção 11 tem critérios em `Cross-Feature Integration`
- [ ] Todo `UC` referenciado em `Cross-Feature Integration` tem exatamente uma linha em A.6, e toda linha de A.6 corresponde a um `UC` referenciado lá
- [ ] Toda feature em `Features` existe na tabela A.2; cada linha lista duas ou mais features
- [ ] `Owner` de cada linha é a feature listada cujo fecho de dependências (A.2) contém todas as outras features listadas
- [ ] **Bloqueante:** toda linha tem `Owner`. Este item NÃO é corrigido automaticamente no loop de validação — ajustar dependências ou a lista de features de um cenário é decisão do usuário. Se algum cenário não tiver feature dona, pare antes de salvar, mostre o cenário, as features envolvidas e o motivo (nenhuma delas depende, direta ou transitivamente, de todas as outras), e peça ao usuário para ajustar a dependência em A.2 ou as features do cenário

**Consistência do arquivo de progresso** (valida os dados que a FASE 5 vai gravar):
- [ ] Todo feature ID da Seção 6 vai aparecer como chave em `features` do arquivo de progresso
- [ ] `dependencies` de cada feature é igual à coluna `Dependencies` da tabela A.2
- [ ] `priority` de cada feature é igual à coluna `Priority` da tabela A.2
- [ ] `wave` de cada feature é igual à wave calculada em A.4 `Execution Waves`

**Loop de validação:** execute o checklist uma vez. Se algum item falhar, corrija e execute novamente. Repita por até 3 iterações. Se os problemas persistirem, pare, reporte o que restou e peça orientação antes de salvar.

---

### FASE 5: Salvar PRD e Arquivo de Progresso

**Passo 1 — Salvar o PRD**

1. Salve o PRD em `{PRD_PATH}`

2. **Verifique se o arquivo foi escrito:** leia `{PRD_PATH}` e confirme que contém os títulos da Section 1, da Section 12 e do `# Appendix A`. Se estiver vazio ou incompleto, gere e salve novamente, aplicando o checklist da Fase 4 antes de re-salvar.

3. O documento tem EXATAMENTE 12 seções + o Anexo A

4. NUNCA inclua: seções extras, "Next Steps", checklists de processo, cabeçalho de ID, data ou versão

5. O documento começa com o nome do produto como H1, seguido da Section 1

**Passo 2 — Montar o conteúdo do arquivo de progresso**

Monte o JSON de `{PROGRESS_PATH}` seguindo `${CLAUDE_PLUGIN_ROOT}/references/progress-schema.md` (carregamento lazy, aqui na FASE 5) — esse arquivo é canônico para o schema e é lido também pelas skills seguintes do pipeline. Use o timestamp atual em RFC 3339 UTC (ex.: `2026-05-02T14:30:00Z`); chame-o de `now`.

Decida conforme o arquivo já exista ou não:

**Caso A — `{PROGRESS_PATH}` NÃO existe (primeira geração):**
- Defina `schema_version: 1`, `prd_path: {PRD_PATH}`, `generated_at: now`.
- Para cada feature ID da tabela A.2 do Anexo A, crie uma entrada com:
  - `name`, `priority`, `dependencies` copiados da tabela A.2 e `wave` copiado de A.4
  - `status: "pending"`, `cycles: 0`
  - `failure_reason: null`, `report_path: null`, `started_at: null`, `completed_at: null`
  - `updated_at: now`

**Caso B — `{PROGRESS_PATH}` existe (regeneração do PRD / merge):**
- Leia e faça o parse do JSON existente. Se o parse falhar, veja os CASOS DE BORDA ("Arquivo de progresso existente corrompido").
- Se o `schema_version` do arquivo existente for maior que `1`, pare e reporte — não faça downgrade.
- Preserve `generated_at` do arquivo existente. Atualize `prd_path` para `{PRD_PATH}`.
- Aplique o contrato de merge por feature ID (IDs são imutáveis):
  - **ID existe no arquivo antigo E no novo PRD, e o `status` antigo NÃO é `removed`:** preserve `status`, `cycles`, `failure_reason`, `report_path`, `started_at`, `completed_at` da entrada existente. Atualize `name`, `priority`, `wave`, `dependencies` a partir do PRD. Atualize `updated_at` para `now` SOMENTE se algum campo atualizado de fato mudou; caso contrário, mantenha o `updated_at` anterior.
  - **ID existe no arquivo antigo E no novo PRD, e o `status` antigo É `removed` (feature ressuscitada):** o ciclo de vida recomeça. Redefina `status: "pending"`, `cycles: 0` e limpe todos os campos opcionais (`failure_reason`, `report_path`, `started_at`, `completed_at`) para `null`. Atualize `name`, `priority`, `wave`, `dependencies` a partir do PRD. Defina `updated_at: now`.
  - **ID só no novo PRD (nunca visto antes):** adicione a entrada exatamente como no Caso A (`pending`, `cycles: 0`, campos opcionais `null`, `updated_at: now`).
  - **ID só no arquivo antigo (feature removida do PRD):** mantenha a entrada; se o `status` ainda não for `removed`, defina `status: "removed"` e atualize `updated_at: now`. Preserve `failure_reason`, `report_path`, `started_at`, `completed_at` e `cycles` como registro forense do estado anterior. Nunca apague entradas.

**Passo 3 — Escrita atômica**

Escreva o JSON em `{PROGRESS_PATH}.tmp` e depois renomeie para `{PROGRESS_PATH}`. Isso garante que outras skills nunca leiam um arquivo escrito pela metade.

**Passo 4 — Verificar e reportar**

1. Leia `{PROGRESS_PATH}` e confirme que é um JSON válido e que contém como chave em `features` todo feature ID da Seção 6 do PRD.

2. **Reporte ao usuário, no chat:**
   - O caminho exato do PRD e do arquivo de progresso
   - Quantas features, RFs, RNFs, decisões, dependências e riscos foram gerados
   - A lista de `Open Questions` que ficaram como `[A DEFINIR]`
   - A lista de `Assumptions` inferidas, para revisão
   - As **Notas técnicas para o HLD** coletadas durante a entrevista, com a oferta de salvá-las em `{OUTPUT_FOLDER}/PRD-technical-notes.md`

3. Sugira o próximo passo: `spec-writer` por feature, para gerar o trio `spec.md` / `plan.md` / `contract.md`. Inclua o aviso: **versione o PRD e o `prd_progress.json` na branch padrão, por commit ou PR/MR, antes de executar** — as worktrees da wave (`implement-and-evaluate-tmux`) nascem da branch padrão e não enxergam o que só existe em disco. Esta skill não commita.

---

## DIRETRIZES FINAIS (FINAL GUIDELINES)

**SEMPRE:**
- Aplique o teste "o quê vs. como" em cada frase das Seções 1-12
- Escreva o conteúdo em português (pt-BR), mantendo em inglês apenas as âncoras estruturais
- Faça uma pergunta por vez na entrevista e ofereça uma resposta recomendada
- Percorra os 12 blocos da agenda antes de encerrar a entrevista
- Marque `[A DEFINIR]` + `Q<NN>` em vez de inventar números que o negócio vai tratar como compromisso
- Registre em `Assumptions` tudo que foi inferido sem confirmação
- Use os IDs (`F`, `RF`, `RNF`, `D`, `Q`, `DEP`, `R`, `A`) e mantenha a rastreabilidade dor → objetivo → requisito → critério → validação
- Inclua números específicos quando o usuário os forneceu
- Emita o Anexo A com o aviso literal de que não faz parte do PRD
- Calcule as Execution Waves mecanicamente a partir da tabela A.2
- Valide internamente ANTES de salvar
- Comece o documento com o nome do produto (H1), sem cabeçalho de ID/data/versão
- Salve o arquivo de progresso junto com o PRD na FASE 5
- Use escrita atômica (`.tmp` + rename) para o arquivo de progresso
- Aplique o contrato de merge da FASE 5 ao regenerar: preserve o estado de execução (`status`, `cycles`, `failure_reason`, `report_path`, `started_at`, `completed_at`) das features que continuam no novo PRD; volte para `pending` quando uma feature `removed` for ressuscitada; marque como `removed` as features que sumiram

**NUNCA:**
- Coloque tecnologia, arquitetura, stack ou estrutura de código nas Seções 1-12
- Discuta ou recuse quando o usuário trouxer técnica — registre nas Notas para o HLD e redirecione em uma frase
- Invente baseline, meta, SLA, volume, prazo ou preço
- Inclua seções além das 12 + Anexo A
- Gere descrições genéricas de funcionalidade
- Force um número fixo de personas, cenários ou stories — derive da realidade do produto
- Escreva um trade-off sem dizer o que se perde
- Escreva um RNF sem alvo mensurável
- Inclua forward references na tabela de dependências
- Sobrescreva o arquivo de progresso sem aplicar o contrato de merge
- Apague entradas do arquivo de progresso (use `status: "removed"`)

---

## CASOS DE BORDA (EDGE CASES)

**`PRODUCT_DESCRIPTION` vazia/mínima:**
- Menos de 20 palavras: peça mais contexto antes de começar
- Vaga ("uma ferramenta para gerenciar coisas"): peça o domínio e o caso de uso específico

**`OUTPUT_FOLDER` não existe:**
- Se não souber a pasta de saída, pergunte
- Tente `mkdir -p {OUTPUT_FOLDER}`; se falhar, retorne "Não foi possível criar a pasta de saída: {OUTPUT_FOLDER}"

**`PROJECT_NAME` com caracteres especiais:**
- Sanitize para o nome do arquivo (espaços por hífens, remova especiais); mantenha o nome original no H1

**O usuário insiste em detalhar arquitetura ou stack:**
- Não recuse e não repita o aviso mais de uma vez. Registre nas Notas para o HLD, diga "vou levar isso para o HLD" e continue a entrevista de negócio. Se ele reafirmar que quer isso no documento, explique em uma frase que o PRD ficaria misturado, ofereça gerar o HLD em seguida com esse material, e siga com o PRD de negócio.

**O produto é interno/de infraestrutura e "não tem usuário de negócio":**
- Ele tem. As personas são as equipes que consomem o serviço; os cenários são as operações que elas precisam realizar; as métricas são operacionais (tempo de atendimento, retrabalho, incidentes). Descreva o valor entregue a essas equipes, não a implementação.

**O usuário não tem métricas nem baseline:**
- Não invente. Registre `[A DEFINIR]` com a `Q<NN>` e proponha a métrica que faria sentido, marcando-a como proposta a validar.

**Feature sem dependências e sem dependentes (nó isolado):**
- Continua na tabela A.2 com `None`, e no Mermaid como nó isolado. Questione na Fase 2 se ela realmente não se relaciona com o resto.

**Dependência circular detectada:**
- Reexamine as features e quebre o ciclo identificando qual dependência é "soft" (conveniência de fluxo, não requisito de dado). Se não for possível quebrar, alerte o usuário ainda na Fase 2.

**Cenário multi-feature sem feature dona (A.6):**
- Nenhuma das features que o cenário atravessa depende, direta ou transitivamente, de todas as outras. Não invente dependência para fechar o grafo e não salve o PRD. Mostre o caso ao usuário e peça o ajuste: uma dependência real que esteja faltando em A.2, ou uma revisão das features que o cenário atravessa.

**Feature com 4+ dependências:**
- Verifique se cada uma é requisito genuíno de dado funcional, não apenas "seria bom ter antes". Mantenha só aquelas sem as quais a feature não funciona.

**Arquivo de progresso existente corrompido:**
- Se `{PROGRESS_PATH}` existe mas não é um JSON válido: NÃO sobrescreva em silêncio. Renomeie para `{PROGRESS_PATH}.broken-<unix-timestamp>` e crie um arquivo novo a partir do PRD, como no Caso A. Informe ao usuário que o arquivo anterior foi preservado com o novo nome.

**`schema_version` do arquivo de progresso mais novo do que esta skill conhece:**
- Se o arquivo existente tiver `schema_version` maior que `1`: pare e reporte ao usuário. Estado gravado por uma versão futura da skill não pode sofrer downgrade. Não grave nada.

---

## SAÍDA (OUTPUT)

**Estrutura final — exatamente 12 seções + Anexo A:**

1. Summary and Context
2. Problem and Motivation
3. Target Audience and Use Scenarios
4. Objectives and Success Metrics
5. Scope
6. Functional Requirements
7. Non-Functional Requirements
8. Key Decisions and Trade-offs
9. Dependencies
10. Risks and Mitigation
11. Acceptance Criteria
12. Validation and Test Strategy

Mais o `Appendix A: Implementation Planning` (partes A.1 a A.6), separado por `---` e marcado como fora do PRD.

**Exemplo de estrutura completo:** `references/prd-example.md` — as 12 seções e o Anexo A preenchidos de ponta a ponta, com títulos e labels em inglês e conteúdo em português. Carregue apenas se precisar ver a forma final montada; as regras de cada seção estão em `references/prd-sections.md`.

---

## REFERÊNCIAS

Nenhuma delas é carregada na invocação da skill. Carregue cada uma no momento indicado:

| Arquivo | Quando carregar | O que é |
|---|---|---|
| `references/prd-sections.md` | FASE 3, antes de redigir | Conteúdo, formato e regras das 12 seções e do Anexo A |
| `references/prd-example.md` | FASE 3, se precisar ver a forma final | Exemplo completo de um PRD preenchido |
| `${CLAUDE_PLUGIN_ROOT}/references/progress-schema.md` | FASE 5, antes de montar o JSON | Schema do `prd_progress.json` — canônico para todo o pipeline |
