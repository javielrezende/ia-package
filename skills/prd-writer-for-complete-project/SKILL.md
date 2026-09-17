---
name: prd-writer-for-complete-project
description: |
  Gere PRDs (Product Requirements Documents) completos e exclusivamente de negócio, por meio de uma entrevista estruturada. Use quando: (1) Iniciar um novo projeto e precisar de requisitos estruturados, (2) Criar a especificação de produto no formato de PRD de 12 seções, (3) Definir problema, escopo, requisitos funcionais e não funcionais, decisões de produto, dependências, riscos, critérios de aceitação e estratégia de validação a partir de uma descrição ou arquivos de contexto. O PRD NÃO contém decisões técnicas — arquitetura, stack e implementação ficam para HLD/FDD. Escrito em português (pt-BR), mantendo em inglês apenas títulos de seção e labels estruturais. Keywords: "prd", "product requirements", "create PRD", "generate PRD", "new product", "requirements document", "requisitos de produto".
---

# PRD Writer — Documento de Requisitos de Produto (apenas negócio)

Você gera PRDs completos e detalhados por meio de uma entrevista estruturada. Seja direto e objetivo.

**Princípio central:** o PRD descreve **o problema, o público, o valor e o que o produto precisa entregar**. Ele nunca descreve **como** o produto será construído. Toda decisão de arquitetura, tecnologia, stack, modelagem de dados ou implementação pertence ao HLD (`generate-high-level-design`) e ao FDD (`generate-feature-design-doc`), não a este documento.

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
  - Cabeçalhos de tabela e labels do Anexo A: `# | Feature | Priority | Dependencies`, o valor `None`, `Consumes`, `Provides`, `Feature Data Contracts`, `Dependency Graph`, `Foundation Features`, `Execution Waves`, `Priority levels`
- Termos consagrados do domínio (upload, e-mail, dashboard, nomes de formatos) permanecem como são, dentro do texto em português.
- O arquivo de progresso (`prd_progress.json`) não é texto redigido: chaves e valores de `status` seguem exatamente o schema da seção "SCHEMA DO ARQUIVO DE PROGRESSO", em inglês. Apenas o `name` de cada feature é copiado do PRD como está.

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

**Agora escreva o documento seguindo as duas referências abaixo — "AS 12 SEÇÕES DO PRD" e "ANEXO A" — e então prossiga para a FASE 4.**

---

## AS 12 SEÇÕES DO PRD (referência de conteúdo da FASE 3)

### Section 1: Summary and Context

**Resumo** — 2 a 3 parágrafos cobrindo:
- O que é o produto
- Para quem
- Qual é o valor central
- Como se encaixa na operação/negócio hoje (contexto), não como funciona por dentro

**Contexto** — o cenário em que o produto nasce: o que existe hoje, o que muda, quem é afetado, qual o momento do negócio.

**Glossary** (inclua quando o domínio tiver 3+ termos não óbvios) — termo em negrito e definição em uma linha. Use o vocabulário do usuário, não invente sinônimos.

**Assumptions** — lista das premissas assumidas na redação do documento:
```markdown
- **A01** — <premissa> · *Se estiver errada:* <o que muda no PRD>
```
Omita a subseção apenas se não houver nenhuma premissa (raro).

---

### Section 2: Problem and Motivation

**O Problema** — 3 a 5 categorias de dor:
- Título em negrito
- 3-4 bullets, com impacto quantificado quando o usuário forneceu o número (custo, tempo perdido, volume, taxa de erro). Se não forneceu, descreva o impacto qualitativamente ou marque `[A DEFINIR]` — não estime.
- Diga **quem** sente cada dor, ligando à persona da Seção 3

**A Motivação** — por que resolver isso agora:
- O que muda no negócio se for resolvido
- O custo de não fazer nada
- O que já foi tentado e por que não bastou (quando houver)

**A Oportunidade** — conexão problema → resposta do produto:
- Cada categoria de dor mapeada para a capacidade que a endereça
- Seja específico sobre o diferencial

---

### Section 3: Target Audience and Use Scenarios

**Primary Users** — perfis distintos, derivados da diversidade real de uso:
- Nome do perfil em negrito
- 3-4 bullets: contexto de trabalho, necessidade central, o que hoje o impede, frequência de uso
- Gere quantas personas o produto genuinamente exigir — NÃO force um número fixo. Público homogêneo: 1-2 basta. Grupos com jornadas distintas: mais.

**Behavioral Profile** — características comuns a todas as personas (nível de familiaridade digital, dispositivo, ambiente, tolerância a fricção).
- Omita quando houver apenas 1 persona — os bullets dela já cobrem isso.

**Use Scenarios** — os cenários de uso concretos, **o material mais importante desta seção**. Cada cenário descreve uma situação real de ponta a ponta, em linguagem de negócio:

```markdown
#### UC01. <Nome do cenário>
- **Persona:** <perfil>
- **Gatilho:** <o que faz essa situação começar>
- **Objetivo:** <o que a pessoa quer alcançar>
- **Percurso:** <3-6 passos, do gatilho ao desfecho, do ponto de vista da pessoa>
- **Desfecho de sucesso:** <como ela sabe que deu certo>
- **Frequência / criticidade:** <com que frequência acontece e o quanto dói se falhar>
```

Regras:
- Gere um cenário por jornada realmente distinta — tipicamente 3 a 8.
- Cubra ao menos um cenário por persona e ao menos um cenário de exceção (o caso em que algo dá errado e a pessoa precisa se recuperar).
- Cenários atravessam features. É esperado e desejável — eles são a base dos critérios de `Cross-Feature Integration` na Seção 11.
- Não descreva telas, cliques em componentes ou navegação interna do sistema. Descreva a intenção e o resultado.

---

### Section 4: Objectives and Success Metrics

**Objetivos do Produto** (3-5):
- Verbo de ação em negrito
- Específico, verificável, e ligado a pelo menos uma categoria de dor da Seção 2

**Success Metrics** — para cada objetivo, uma ou mais métricas no formato:

| Métrica | Baseline atual | Meta | Como medir | Quando avaliar |
|---|---|---|---|---|

Regras:
- Toda métrica precisa de **origem**: baseline vem do usuário ou é `[A DEFINIR]`. Nunca estime baseline.
- "Como medir" descreve a fonte da informação em nível de negócio ("relatório mensal de atendimentos", "pesquisa de satisfação pós-uso"), não instrumentação técnica.
- Se o usuário não definiu meta, escreva `[A DEFINIR]` e crie a `Q<NN>` correspondente na Seção 8.
- Distinga métricas de **resultado** (o negócio melhorou) de métricas de **adoção** (as pessoas usaram). Um PRD bom tem as duas.

---

### Section 5: Scope

**In Scope** — o que esta versão entrega, agrupado por feature:
```markdown
- **F01 <Nome>** — <uma linha sobre o que entra>
```
Toda feature da Seção 6 aparece aqui, exatamente uma vez.

**Out of Scope** — o que o produto **não fará nesta versão**, agrupado por categoria, cada item com o motivo (adiado por prazo, depende de X, baixo valor agora) e, quando existir, a versão-alvo.

**Non-Goals** — o que o produto **nunca** pretende ser, mesmo em versões futuras. Isso é diferente de Out of Scope: aqui é uma decisão de posicionamento, não um adiamento. Omita a subseção se não houver não-objetivos declarados.

---

### Section 6: Functional Requirements

Estrutura por feature: `F01`, `F02`, `F03`... Toda feature tem, no mínimo, `Capabilities` e `Experience`. Os demais blocos são condicionais — omita quando vazios.

```markdown
### F01. <Nome da Feature>

**Priority:** Must have | Should have | Could have

**Core Scope:** (condicional)
**Full Scope additions:** (condicional)

**Capabilities:**
- **RF01.1** — <regra de negócio, limite ou comportamento específico>
- **RF01.2** — ...

**Experience:**
<fluxo do usuário em linguagem de negócio>

**Error Handling:** (condicional)
```

**Priority** — prioridade de negócio da versão mínima viável da feature:
- `Must have` = o produto não cumpre seu propósito sem ela
- `Should have` = agrega valor significativo, mas o produto funciona sem
- `Could have` = melhoria incremental, primeira a cair sob pressão de prazo

**Core Scope** (omita se a feature inteira for essencial): o conjunto mínimo de capacidades para a feature cumprir seu propósito. Inclua apenas quando a feature tiver capacidades de prioridades mistas.

**Full Scope additions** (omita se `Core Scope` foi omitido): capacidades que aprimoram a feature além do core.

**Capabilities** — os requisitos funcionais propriamente ditos, cada um com seu ID `RF<feature>.<n>`:
- Limites ESPECÍFICOS (tamanhos, quantidades, prazos), formatos, regras de negócio, permissões por perfil
- Um requisito por bullet, verificável isoladamente
- Números vêm do usuário. Se não vierem e não forem seguramente deriváveis, `[A DEFINIR]` + `Q<NN>`.

**Experience** — o fluxo do usuário: ordem dos passos, campos que ele informa, validações que ele percebe, mensagens que ele lê, estados que ele vê (vazio, carregando, concluído, erro). Descreva a experiência, não a interface interna.

**Error Handling** (APENAS para features críticas) — 3 a 5 cenários de falha com a mensagem específica que o usuário vê e o que ele consegue fazer em seguida.
- Inclua quando a feature envolver PELO MENOS UM de: (a) autenticação/autorização, (b) pagamento ou operação financeira, (c) risco de perda de dados, (d) operação sensível à segurança ou privacidade, (e) operação longa ou irreversível com falha parcial possível.
- Pule para features somente de leitura ou exibição, onde falhar significa recarregar: navegação, visualização, filtro, ordenação, busca em dados já carregados.
- Na dúvida: "se isso falhar em silêncio, o usuário perde dado, dinheiro ou segurança?" Sim → inclua. Não → pule.

**OBRIGATÓRIO:**
- NUNCA descrições genéricas ("gerenciar usuários", "processar dados") — diga exatamente o que acontece
- SEMPRE fluxo detalhado com campos, validações e ordem
- SEMPRE aplique a Fronteira de Negócio: descreva o comportamento observável, nunca o mecanismo

---

### Section 7: Non-Functional Requirements

Requisitos de **qualidade**, sempre expressos como algo que o negócio ou o usuário consegue observar e medir. O PRD define **o alvo**; o HLD define **como atingir**.

Formato:
```markdown
| ID | Categoria | Requisito | Alvo mensurável | Como verificar | Prioridade |
|---|---|---|---|---|---|
| RNF01 | Desempenho percebido | O resultado da busca aparece sem que o usuário sinta espera | 95% das buscas respondem em até 2s | Medição sobre a operação real, amostra mensal | Must have |
```

Categorias a considerar (inclua as aplicáveis, omita as que não fazem sentido para o produto):
- **Desempenho percebido** — tempo até o usuário ver o resultado; nunca throughput interno
- **Disponibilidade e continuidade** — janela de indisponibilidade tolerada, horário crítico de operação, tempo aceitável de recuperação
- **Capacidade e volume** — usuários simultâneos, volume de registros, pico sazonal esperado
- **Segurança e privacidade** — quem pode ver o quê, o que é registrado, por quanto tempo o dado é retido, o que acontece quando o titular pede exclusão
- **Conformidade legal e regulatória** — LGPD, exigências setoriais, obrigações fiscais, retenção obrigatória
- **Acessibilidade** — nível exigido e público atendido
- **Usabilidade** — tempo/tentativas para um usuário novo concluir a tarefa principal
- **Auditabilidade** — que ações precisam ficar rastreáveis e por quanto tempo
- **Suporte e operação** — SLA de atendimento, janela de manutenção aceitável, quem opera
- **Internacionalização** — idiomas, moedas, fusos, formatos regionais

Regras:
- Todo RNF precisa de **alvo mensurável**. Sem número ou condição binária verificável, não é requisito — é desejo. Se o alvo não foi definido: `[A DEFINIR]` + `Q<NN>`.
- NUNCA nomeie tecnologia, mecanismo ou estratégia de implementação no requisito. "O sistema suporta 500 usuários simultâneos" é RNF. "Usar cache distribuído para suportar 500 usuários" é HLD.
- Cada RNF relevante para o lançamento precisa aparecer na Seção 12 com a forma de validação correspondente.

---

### Section 8: Key Decisions and Trade-offs

Decisões de **produto e negócio** já tomadas, com o que se aceitou perder. Isto documenta *por que o produto é assim* — não *como ele é construído*.

Escopo válido de decisão: recorte de escopo, priorização, público atendido primeiro, canal, modelo de cobrança, nível de automação vs. curadoria manual, comprar vs. construir **do ponto de vista de custo/prazo/dependência**, política de dados, grau de rigor de um processo, sequência de lançamento por segmento.

Fora de escopo: escolha de linguagem, framework, banco, arquitetura, provedor de infraestrutura, padrão de integração.

```markdown
### D01. <Decisão em uma frase>
- **Contexto:** <o que forçou a decisão>
- **Opções consideradas:** <A, B, C — uma linha cada>
- **Decisão:** <o que foi escolhido>
- **Motivo:** <por que>
- **Trade-off aceito:** <o que se ganha / do que se abre mão, explicitamente>
- **Impacto:** <em quem e no quê — personas, métricas, escopo>
- **Reversibilidade:** <fácil / custosa / praticamente definitiva — e até quando dá para mudar>
```

Regras:
- Uma decisão só entra aqui se houve **alternativa real descartada**. Se não havia escolha, não é decisão — é restrição, e pertence à Seção 9.
- Todo trade-off precisa nomear o que se perde. "Escolhemos X, que é melhor em tudo" não é trade-off.
- Gere de 3 a 8 decisões. Um produto sem nenhuma decisão registrada normalmente significa que a entrevista não aprofundou o bloco B8.

**Open Questions** — subseção final, com o que ainda não foi decidido:
```markdown
| ID | Pergunta em aberto | Impacto se não for respondida | Quem decide | Prazo |
|---|---|---|---|---|
| Q01 | Qual a meta de conversão do primeiro trimestre? | Seção 4 fica sem alvo verificável | Product Owner | Antes do kickoff |
```
Toda ocorrência de `[A DEFINIR]` no documento tem uma linha correspondente aqui. Omita a subseção somente se não houver nenhum `[A DEFINIR]`.

---

### Section 9: Dependencies

Aquilo de que o produto depende para existir e operar, **fora do controle do time de produto**. Dependências entre features não entram aqui — ficam no Anexo A.

Agrupe por categoria; omita as categorias vazias.

```markdown
### External Dependencies
| ID | Dependência | O que entrega ao produto | Impacto se faltar | Responsável | Criticidade |
|---|---|---|---|---|---|
| DEP01 | Emissor de nota fiscal municipal | Emissão fiscal das vendas | Nenhuma venda pode ser faturada | Financeiro | Bloqueante |
```

Categorias:
- **External Dependencies** — fornecedores, parceiros, serviços contratados, órgãos externos. Descreva pelo valor de negócio entregue, nunca pelo mecanismo de integração.
- **Organizational Dependencies** — times, áreas, stakeholders, aprovações necessárias. Inclua aqui quem são os decisores do produto e o que cada um precisa aprovar.
- **Legal and Regulatory Dependencies** — licenças, contratos, pareceres, adequações obrigatórias, prazos regulatórios.
- **Data and Content Dependencies** — dados, conteúdo ou cadastros que precisam existir antes do produto funcionar, e de onde vêm.

Regras:
- Criticidade: `Bloqueante` (sem ela nada acontece), `Alta` (parte do escopo cai), `Média` (contorno existe).
- Toda dependência bloqueante precisa de um risco correspondente na Seção 10.

---

### Section 10: Risks and Mitigation

Riscos de **negócio**: adoção, mercado, operação, regulação, dependência externa, prazo, capacidade de equipe, mudança de contexto.

Riscos puramente técnicos de implementação pertencem ao HLD/FDD. Um risco técnico só entra aqui quando tem consequência material de negócio — e então é descrito pelo efeito de negócio, não pela causa técnica.

```markdown
| ID | Risco | Categoria | Probabilidade | Impacto | Severidade | Mitigação | Plano de contingência | Responsável |
|---|---|---|---|---|---|---|---|---|
| R01 | Usuários continuam usando planilha em paralelo | Adoção | Alta | Alto | Crítica | Migrar os dados históricos e treinar as equipes antes do go-live | Manter planilha como fonte oficial por mais um ciclo | Operações |
```

Regras:
- Probabilidade e Impacto em `Baixa/Média/Alta`. Severidade derivada: Alta×Alto = `Crítica`; qualquer Alta = `Alta`; Média×Média = `Média`; o restante = `Baixa`.
- **Mitigação** reduz a chance de acontecer. **Contingência** é o que se faz depois que aconteceu. Preencha as duas — são coisas diferentes.
- Todo risco `Crítica` ou `Alta` precisa de responsável nomeado (papel, não pessoa).
- Gere de 4 a 10 riscos. Cubra ao menos um de adoção, um de dependência externa (se a Seção 9 tiver dependências bloqueantes) e um de conformidade (se a Seção 7 tiver requisitos regulatórios).

---

### Section 11: Acceptance Criteria

Critérios verificáveis, organizados por feature, usando os IDs das Seções 6 e 7.

```markdown
### F01. <Nome da Feature>
- [ ] (RF01.1) <critério verificável — passa ou não passa>
- [ ] (RF01.2) <critério de falha correspondente>
```

Regras por feature:
- **Verificável**: alguém consegue executar e dizer "passou" ou "não passou", sem interpretação
- **Específico**: sem ambiguidade, sem "adequadamente", "rapidamente", "de forma amigável"
- **Cobrir sucesso E falha**: todo caminho feliz tem pelo menos um caminho de erro correspondente
- **Rastreável**: cada critério referencia o `RF` que atende; todo `RF` da Seção 6 é coberto por pelo menos um critério
- Escrito do ponto de vista observável do usuário, nunca de estado interno do sistema

**Critérios de requisitos não funcionais:**
```markdown
### Non-Functional Acceptance
- [ ] (RNF01) <critério com o alvo mensurável da Seção 7>
```
Todo RNF de prioridade `Must have` gera pelo menos um critério aqui.

**Cross-Feature Integration** — bloco final da seção:
- Derive um critério de cada cenário de uso da Seção 3 que atravessa mais de uma feature
- Cada critério verifica a jornada ponta a ponta, do gatilho ao desfecho, do ponto de vista da pessoa
- Referencie o cenário: `(UC01)`

---

### Section 12: Validation and Test Strategy

Como se comprova que o produto resolve o problema da Seção 2 e atinge as metas da Seção 4. Esta seção é sobre **validação de negócio**, não sobre engenharia de testes: frameworks, cobertura de código, testes unitários, pipeline e automação pertencem ao FDD.

**Abordagem de Validação**
- Como a hipótese central do produto será comprovada
- O que precisa ser verdadeiro no lançamento para o produto ser considerado bem-sucedido

**Níveis de Validação** — o que é validado, por quem, com que evidência:

| Nível | O que valida | Quem executa | Evidência de aprovação |
|---|---|---|---|
| Validação funcional | Cada `RF` da Seção 6 contra os critérios da Seção 11 | Time de qualidade | Checklist da Seção 11 integralmente marcado |
| Validação de cenário | Cada `UC` da Seção 3 ponta a ponta | Usuário-chave de cada persona | Cenário concluído sem intervenção externa |
| Validação não funcional | Cada `RNF` Must have da Seção 7 | Time de qualidade | Alvo mensurável atingido e registrado |
| Aceite do usuário (UAT) | Que o produto resolve a dor real | Representantes das personas | Aprovação formal dos responsáveis |

**Massa de Dados e Ambiente de Validação** — em nível de negócio:
- Que volume e variedade de dados representativos são necessários
- Dados reais, anonimizados ou sintéticos — e a restrição de privacidade que determina a escolha
- Que cadastros ou integrações externas precisam estar disponíveis para validar

**Critérios de Entrada e Saída**
- **Entrada:** o que precisa estar pronto para a validação começar
- **Saída (definição de "aprovado para lançar"):** condições objetivas — tipicamente 100% dos critérios `Must have`, nenhum defeito crítico aberto, RNFs `Must have` atingidos, UAT aprovado

**Rollout e Validação Pós-Lançamento**
- Estratégia de liberação: piloto, lançamento por segmento ou lançamento total — e o porquê
- Público e duração da primeira fase
- Métricas da Seção 4 monitoradas na janela pós-lançamento, com a frequência de leitura
- **Critérios de reversão de negócio:** o que faz o time voltar atrás (queda de métrica, falha de conformidade, volume de reclamações), expresso em números

**Responsabilidades** — quem valida o quê e quem tem a palavra final sobre o lançamento (papéis, não pessoas).

---

## ANEXO A (fora do PRD — referência de conteúdo da FASE 3)

Após a Seção 12, emita o Anexo A, precedido de um separador `---` e do aviso abaixo, literal:

```markdown
# Appendix A: Implementation Planning

> Este anexo **não faz parte do PRD**. Ele não contém requisitos de produto e não deve ser usado como fonte de escopo de negócio. Existe para registrar o grafo de dependências entre features e o sequenciamento de construção. Decisões de arquitetura e tecnologia permanecem fora daqui — elas pertencem ao HLD e ao FDD.
```

O anexo tem cinco partes. A numeração `A.1` a `A.5` é fixa: quando `A.3 Foundation Features` não se aplica e é omitida, as demais mantêm seus números — não renumere.

### A.1 Feature Data Contracts

Para cada feature que troca dados funcionais com outra:

```markdown
### F03. Processamento de Pedidos
**Consumes:**
- F02: identificador do pedido, itens, valor total

**Provides:**
- Situação do pedido e data de conclusão (used by F04, F06)
```

Regras:
- Nível semi-técnico: nomeie os objetos de negócio e seus campos-chave ("caminho do arquivo, duração, formato"), nunca tipos de programação ("string", "int", "interface").
- NÃO liste autenticação/sessão em `Consumes` nem em `Provides` — auth é assumida para todas as features.
- Liste apenas dependências de dados **funcionais** (dados que fluem entre features).
- Agrupamento: mesmos dados consumidos por várias features viram uma entrada só — `(used by F04, F06)`. Dados diferentes para features diferentes viram entradas separadas.
- Omita a feature inteira desta parte se ela não consome nem fornece dados funcionais.

### A.2 Dependency Graph

**Tabela de dependências:**

| # | Feature | Priority | Dependencies |
|---|---------|----------|--------------|

Regras:
- Cada feature da Seção 6 aparece exatamente uma vez.
- **Ordem topológica:** toda dependência referenciada deve aparecer em uma linha ACIMA. O leitor nunca encontra forward reference.
- `Dependencies`: IDs separados por vírgula, sempre com semântica AND. Use `None` para features raiz.
- Existe dependência quando a feature B não pode funcionar sem a feature A implementada antes. Inclui dependências de dados funcionais (que aparecem em `Consumes`) e de infraestrutura (ex.: auth). `Dependencies` é sempre um superset de `Consumes`.
- `Priority`: inteiro 1-3, derivado mecanicamente da `Priority` da Seção 6 — `Must have` = 1, `Should have` = 2, `Could have` = 3. Reflete a versão mínima viável (`Core Scope` quando definido). `Full Scope additions` não aparecem na tabela.
- Desempate topológico pelo feature ID (mais baixo primeiro) quando não há restrição de ordem.
- Dependência alternativa (semântica OR): escolha a opção principal e registre a alternativa na descrição da feature na Seção 6. A tabela suporta apenas AND.

**Diagrama Mermaid:**
```mermaid
graph TD
  F01[Auth] --> F02[Upload]
```
- Direção `graph TD`; labels com ID + nome curto (1-2 palavras)
- `A --> B` significa "A é pré-requisito de B"
- As edges correspondem exatamente à coluna `Dependencies`; a tabela é a fonte da verdade

### A.3 Foundation Features

Inclua APENAS quando uma ou mais features trouxerem infraestrutura compartilhada de projeto — scaffolding, layout base, configuração de persistência, integração de autenticação, convenções de rotas, estilo global, setup de CI. Essas features não podem ser executadas em paralelo em um projeto greenfield porque tocam os mesmos arquivos fundacionais.

```markdown
### Foundation Features
Estas features configuram a infraestrutura compartilhada do projeto. Em um projeto greenfield, elas devem ser implementadas sequencialmente, antes ou em conjunto com qualquer feature que dependa delas:
- **F<ID> <Nome>** — <o que contribui para a infraestrutura compartilhada>
```

Regras:
- Omita inteiramente quando nenhuma feature carregar responsabilidade de fundação (ex.: PRD que adiciona features a um produto já maduro).
- **Critério:** é Foundation quando o **propósito principal** da feature é configurar infraestrutura compartilhada. NÃO é Foundation quando o propósito principal é uma capacidade de domínio voltada ao usuário, mesmo que ela crie estrutura de UI no caminho.
- Teste útil: se implementar a feature significa rodar comandos de bootstrapping/scaffolding ou configurar uma biblioteca central que as features seguintes consomem sem citá-la em `Consumes`, é Foundation. O critério é agnóstico de stack.
- Liste em ordem topológica, igual à tabela A.2.

### A.4 Execution Waves

Features da mesma wave podem ser construídas em paralelo; uma wave só começa quando todas as anteriores terminam.

Cálculo (mecânico, derivado da tabela A.2):
- **Wave 1**: toda feature com `Dependencies: None`
- **Wave N** (N ≥ 2): `wave(feature) = max(wave(dep) for dep in dependencies) + 1`

Ordenação dentro da wave: `Priority` ascendente (1, 2, 3); empate pelo feature ID mais baixo.

```markdown
### Execution Waves
As features de uma mesma wave podem ser construídas em paralelo. Uma wave só começa depois que todas as features das waves anteriores estiverem concluídas.

**Nota:** As foundation features (ver acima) não podem ser executadas em paralelo em um projeto greenfield, mesmo que apareçam juntas em uma wave — elas compartilham arquivos de scaffolding e devem ser implementadas sequencialmente até que a base esteja pronta.

- **Wave 1**: F01
- **Wave 2**: F02
```

A linha "Nota:" só é incluída quando `A.3 Foundation Features` foi emitida.

### A.5 Priority levels

Sempre inclua:
```markdown
### Priority levels
- **1** = Must have — o produto não funciona sem ela
- **2** = Should have — agrega valor significativo
- **3** = Could have — melhoria incremental
```

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
- [ ] As âncoras estruturais permanecem em inglês (títulos das 12 seções e do Anexo A; `Glossary`, `Assumptions`, `Primary Users`, `Behavioral Profile`, `Use Scenarios`, `In Scope`, `Out of Scope`, `Non-Goals`, `Core Scope`, `Full Scope additions`, `Capabilities`, `Experience`, `Error Handling`, `Open Questions`, `Cross-Feature Integration`, `Consumes`, `Provides`, `Feature Data Contracts`, `Dependency Graph`, `Foundation Features`, `Execution Waves`, `Priority levels`; cabeçalhos da tabela de dependências e `None`)

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

Monte o JSON de `{PROGRESS_PATH}` seguindo a seção "SCHEMA DO ARQUIVO DE PROGRESSO" abaixo. Use o timestamp atual em RFC 3339 UTC (ex.: `2026-05-02T14:30:00Z`); chame-o de `now`.

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

3. Sugira o próximo passo: `generate-high-level-design` para a arquitetura, depois `spec-writer` por feature.

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
- Tente `mkdir -p {OUTPUT_FOLDER}`; se falhar, retorne "Cannot create output folder: {OUTPUT_FOLDER}"

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

**Feature com 4+ dependências:**
- Verifique se cada uma é requisito genuíno de dado funcional, não apenas "seria bom ter antes". Mantenha só aquelas sem as quais a feature não funciona.

**Arquivo de progresso existente corrompido:**
- Se `{PROGRESS_PATH}` existe mas não é um JSON válido: NÃO sobrescreva em silêncio. Renomeie para `{PROGRESS_PATH}.broken-<unix-timestamp>` e crie um arquivo novo a partir do PRD, como no Caso A. Informe ao usuário que o arquivo anterior foi preservado com o novo nome.

**`schema_version` do arquivo de progresso mais novo do que esta skill conhece:**
- Se o arquivo existente tiver `schema_version` maior que `1`: pare e reporte ao usuário. Estado gravado por uma versão futura da skill não pode sofrer downgrade. Não grave nada.

---

## SCHEMA DO ARQUIVO DE PROGRESSO (PROGRESS FILE SCHEMA)

O arquivo de progresso (`prd_progress.json`) é um registro determinístico, legível por máquina, da situação de implementação de cada feature. Esta skill cria o arquivo e faz o merge; as skills seguintes do pipeline (`implement-feature`, `evaluator`, `fix-runner`, `implement-and-evaluate`, `implement-and-evaluate-tmux`) leem e gravam nele durante suas próprias execuções.

**Estrutura de primeiro nível:**

```json
{
  "schema_version": 1,
  "prd_path": "<caminho do PRD>",
  "generated_at": "<timestamp RFC 3339 UTC, definido só na primeira criação>",
  "features": {
    "F01": { ... },
    "F02": { ... }
  }
}
```

**Estrutura por feature:**

```json
{
  "name": "Acesso e Identificação",
  "priority": 1,
  "wave": 1,
  "dependencies": [],
  "status": "pending",
  "cycles": 0,
  "failure_reason": null,
  "report_path": null,
  "started_at": null,
  "updated_at": "2026-05-02T14:30:00Z",
  "completed_at": null
}
```

**Semântica dos campos:**

- `name` / `priority` / `dependencies` — copiados da tabela A.2 `Dependency Graph` do Anexo A; `wave` — copiado de A.4 `Execution Waves`. Atualizados a cada regeneração do PRD.
- `status` — um de:
  - `pending` (terminal) — não iniciada
  - `implementing` (transitório) — `implement-feature` está em execução. Definido no início do Passo 5 da `implement-feature`; substituído por `implemented` quando ela termina com sucesso (ou por `fail` em caso de aborto). Raramente aparece num JSON parado — só persiste enquanto a `implement-feature` roda.
  - `implemented` (checkpoint terminal) — `implement-feature` concluiu seu trabalho; a feature está no loop implementar → avaliar → corrigir, aguardando o veredito terminal do `evaluator`. Persiste entre invocações de skills.
  - `done` (terminal) — o `evaluator` aprovou; o contrato foi cumprido
  - `fail` (terminal) — o `evaluator` reprovou de forma terminal OU a `implement-feature` abortou sem recuperação OU o orquestrador esgotou o orçamento de tentativas / acionou o circuit breaker
  - `pr-blocked` (terminal) — a feature foi implementada e validada com sucesso (avaliação limpa), mas o orquestrador não conseguiu abrir o pull request porque o merge da branch padrão do projeto na branch da feature gerou conflitos que o `fix-runner` não resolveu automaticamente. É diferente de `fail` porque a implementação em si está correta — só a integração com a main está bloqueada. A resolução é humana: fazer rebase/merge manual, push, e então reinvocar ou abrir o PR à mão.
  - `removed` (terminal) — a feature existia numa revisão anterior do PRD, mas não está mais no PRD atual
- `cycles` — quantidade de ciclos do `fix-runner` consumidos pela feature. Usado pela `implement-and-evaluate` para aplicar o orçamento de tentativas.
- `failure_reason` — obrigatório quando `status: "fail"` ou `status: "pr-blocked"`. Texto curto (menos de 200 caracteres) com a causa da falha (ex.: `"3 contract item(s) failed; first: API-UPLOAD-03 — endpoint returned 500"`, `"cycle budget exhausted (5 cycles); last eval: ..."`, `"unresolvable merge conflict in apps/web/lib/session.ts, apps/backend/src/main.ts"`). Pode permanecer em `status: "removed"` como registro forense da falha anterior. `null` para os demais status (`pending`, `implementing`, `implemented`, `done`).
- `report_path` — ponteiro opcional para o `eval-report-<ts>.md` mais recente da feature. Pode ser definido em `done` (última avaliação aprovada) ou `fail` (última avaliação reprovada) e persiste em `removed` como registro forense. `null` quando nenhuma avaliação rodou.
- `started_at` — timestamp RFC 3339 UTC do momento em que o status saiu de `pending` pela primeira vez. `null` até lá. Volta a `null` apenas quando uma feature `removed` é ressuscitada numa nova revisão do PRD (começa um novo ciclo de vida).
- `updated_at` — timestamp RFC 3339 UTC da última escrita nesta entrada. Sempre preenchido.
- `completed_at` — timestamp RFC 3339 UTC definido quando o status passa a `done`. `null` nos demais casos.

**Invariantes:**

- Todo feature ID presente na Seção 6 do PRD DEVE existir como chave em `features`. O inverso não é exigido (entradas `removed` persistem além do PRD atual).
- `cycles >= 0`.
- Todo ID em `dependencies` deve existir como chave em `features` (atual ou `removed`).
- Todos os timestamps são UTC, RFC 3339 (`2026-05-02T14:30:00Z`).

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

Mais o `Appendix A: Implementation Planning` (partes A.1 a A.5), separado por `---` e marcado como fora do PRD.

**Exemplo de estrutura (títulos e labels em inglês, conteúdo em português):**

````markdown
# Nome do Produto

## 1. Summary and Context

[2-3 parágrafos de resumo + contexto...]

### Glossary
- **Trecho** — bloco contínuo de transcrição com início e fim marcados

### Assumptions
- **A01** — O público inicial é interno à empresa · *Se estiver errada:* a Seção 3 ganha uma persona externa e a Seção 7 ganha requisitos de acessibilidade pública

## 2. Problem and Motivation

**Revisão manual consome o dia da equipe**
- Cada gravação de 1h leva 3h para ser revisada
- Sentido por: Analista de Conteúdo

**A Motivação**
[...]

**A Oportunidade**
[...]

## 3. Target Audience and Use Scenarios

### Primary Users

**Analista de Conteúdo**
- Revisa 12 gravações por semana
- Precisa localizar trechos específicos sem reassistir
- Hoje depende de anotações manuais

### Behavioral Profile
[...]

### Use Scenarios

#### UC01. Localizar um trecho citado em reunião
- **Persona:** Analista de Conteúdo
- **Gatilho:** Alguém pergunta em que momento um assunto foi tratado
- **Objetivo:** Encontrar e compartilhar o momento exato
- **Percurso:** Abre a gravação → busca o termo → identifica o trecho → salta para o momento → compartilha o link
- **Desfecho de sucesso:** Envia a referência em menos de 2 minutos
- **Frequência / criticidade:** Diária · alta

## 4. Objectives and Success Metrics

**Reduzir o tempo de revisão de conteúdo**

| Métrica | Baseline atual | Meta | Como medir | Quando avaliar |
|---|---|---|---|---|
| Tempo médio de revisão por hora gravada | 3h | 45min | Apontamento de horas da equipe | Mensal, a partir do 2º mês |

## 5. Scope

### In Scope
- **F01 Acesso e Identificação** — cadastro, login e recuperação de conta
- **F02 Envio de Gravação** — envio de arquivos e acompanhamento do progresso

### Out of Scope
**Colaboração**
- Comentários em trechos — adiado para a próxima versão, depende de validar a adoção básica

### Non-Goals
- O produto não pretende ser uma ferramenta de edição de vídeo

## 6. Functional Requirements

### F01. Acesso e Identificação

**Priority:** Must have

**Capabilities:**
- **RF01.1** — O usuário se cadastra com e-mail corporativo e senha de no mínimo 10 caracteres
- **RF01.2** — A sessão permanece ativa por 30 dias no mesmo dispositivo

**Experience:**
[Fluxo em linguagem de negócio...]

**Error Handling:**
- Credenciais incorretas: "E-mail ou senha inválidos" — sem revelar qual dos dois falhou; após 5 tentativas, o acesso é bloqueado por 15 minutos

### F02. Envio de Gravação

**Priority:** Must have

**Capabilities:**
- **RF02.1** — Aceita arquivos de até 2 GB nos formatos MP4, MOV e MP3
- **RF02.2** — Exibe percentual e tempo restante estimado durante o envio

**Experience:**
[...]

## 7. Non-Functional Requirements

| ID | Categoria | Requisito | Alvo mensurável | Como verificar | Prioridade |
|---|---|---|---|---|---|
| RNF01 | Desempenho percebido | A busca dentro de uma transcrição retorna sem espera perceptível | 95% das buscas em até 2s | Amostra mensal sobre uso real | Must have |
| RNF02 | Segurança e privacidade | Cada usuário acessa apenas as gravações da sua equipe | Nenhum acesso cruzado em auditoria trimestral | Auditoria de acessos | Must have |

## 8. Key Decisions and Trade-offs

### D01. A primeira versão atende apenas o público interno
- **Contexto:** Abrir para clientes exigiria adequação de acessibilidade e suporte externo
- **Opções consideradas:** Lançar interno primeiro · Lançar para todos · Beta fechado com clientes
- **Decisão:** Lançar apenas para times internos
- **Motivo:** Permite validar a hipótese central sem carregar o custo de suporte externo
- **Trade-off aceito:** Ganha-se velocidade de validação; abre-se mão de receita e de sinal de mercado real no primeiro ciclo
- **Impacto:** Seção 3 tem apenas personas internas; Seção 7 não exige acessibilidade pública nesta versão
- **Reversibilidade:** Custosa após o lançamento — reabrir exige revisar privacidade e suporte

### Open Questions
| ID | Pergunta em aberto | Impacto se não for respondida | Quem decide | Prazo |
|---|---|---|---|---|
| Q01 | Qual o volume esperado de gravações por mês? | RNF de capacidade fica sem alvo | Operações | Antes do kickoff |

## 9. Dependencies

### External Dependencies
| ID | Dependência | O que entrega ao produto | Impacto se faltar | Responsável | Criticidade |
|---|---|---|---|---|---|
| DEP01 | Serviço de transcrição contratado | Transcrição automática das gravações | O produto perde sua capacidade central | Time de Produto | Bloqueante |

### Organizational Dependencies
| ID | Dependência | O que entrega ao produto | Impacto se faltar | Responsável | Criticidade |
|---|---|---|---|---|---|
| DEP02 | Aprovação do time de Privacidade | Parecer sobre retenção de gravações | O lançamento não pode ocorrer | Jurídico | Bloqueante |

## 10. Risks and Mitigation

| ID | Risco | Categoria | Probabilidade | Impacto | Severidade | Mitigação | Plano de contingência | Responsável |
|---|---|---|---|---|---|---|---|---|
| R01 | A transcrição automática não atinge qualidade aceitável no vocabulário do domínio | Dependência externa | Média | Alto | Alta | Validar com 20 gravações reais antes do lançamento | Permitir correção manual do texto | Time de Produto |

## 11. Acceptance Criteria

### F01. Acesso e Identificação
- [ ] (RF01.1) O cadastro é concluído com e-mail corporativo válido e senha de 10+ caracteres
- [ ] (RF01.1) O cadastro é recusado com mensagem específica quando a senha tem menos de 10 caracteres
- [ ] (RF01.2) O usuário permanece autenticado ao retornar no mesmo dispositivo dentro de 30 dias

### F02. Envio de Gravação
- [ ] (RF02.1) Um arquivo MP4 de 2 GB é enviado com sucesso
- [ ] (RF02.1) Um arquivo de 2,1 GB é recusado com mensagem informando o limite
- [ ] (RF02.2) O progresso exibe percentual e tempo restante durante todo o envio

### Non-Functional Acceptance
- [ ] (RNF01) Em uma amostra de 100 buscas reais, ao menos 95 respondem em até 2s
- [ ] (RNF02) Uma auditoria de acessos não encontra nenhum acesso a gravação de outra equipe

### Cross-Feature Integration
- [ ] (UC01) O analista localiza um trecho por busca e chega ao momento correto da gravação em menos de 2 minutos, partindo da lista de gravações

## 12. Validation and Test Strategy

**Abordagem de Validação**
[...]

**Níveis de Validação**
| Nível | O que valida | Quem executa | Evidência de aprovação |
|---|---|---|---|
| Validação funcional | Cada RF da Seção 6 | Time de qualidade | Checklist da Seção 11 marcado |
| Validação de cenário | UC01 a UC05 | Usuário-chave de cada persona | Cenário concluído sem apoio |

**Massa de Dados e Ambiente de Validação**
[...]

**Critérios de Entrada e Saída**
[...]

**Rollout e Validação Pós-Lançamento**
[...]

**Responsabilidades**
[...]

---

# Appendix A: Implementation Planning

> Este anexo **não faz parte do PRD**. Ele não contém requisitos de produto e não deve ser usado como fonte de escopo de negócio. Existe para registrar o grafo de dependências entre features e o sequenciamento de construção. Decisões de arquitetura e tecnologia permanecem fora daqui — elas pertencem ao HLD e ao FDD.

## A.1 Feature Data Contracts

### F02. Envio de Gravação
**Provides:**
- Identificador da gravação, duração e formato (used by F03)

### F03. Transcrição
**Consumes:**
- F02: identificador da gravação, duração e formato

**Provides:**
- Trechos com marcação de início e fim, idioma detectado (used by F04)

## A.2 Dependency Graph

| # | Feature | Priority | Dependencies |
|---|---------|----------|--------------|
| F01 | Acesso e Identificação | 1 | None |
| F02 | Envio de Gravação | 1 | F01 |
| F03 | Transcrição | 1 | F02 |
| F04 | Consulta e Navegação | 2 | F03 |

```mermaid
graph TD
  F01[Acesso] --> F02[Envio]
  F02 --> F03[Transcrição]
  F03 --> F04[Consulta]
```

## A.3 Foundation Features

### Foundation Features
Estas features configuram a infraestrutura compartilhada do projeto. Em um projeto greenfield, elas devem ser implementadas sequencialmente, antes ou em conjunto com qualquer feature que dependa delas:
- **F01 Acesso e Identificação** — estabelece a base da aplicação e a camada de identificação de usuário

## A.4 Execution Waves

### Execution Waves
As features de uma mesma wave podem ser construídas em paralelo. Uma wave só começa depois que todas as features das waves anteriores estiverem concluídas.

**Nota:** As foundation features (ver acima) não podem ser executadas em paralelo em um projeto greenfield, mesmo que apareçam juntas em uma wave — elas compartilham arquivos de scaffolding e devem ser implementadas sequencialmente até que a base esteja pronta.

- **Wave 1**: F01
- **Wave 2**: F02
- **Wave 3**: F03
- **Wave 4**: F04

## A.5 Priority levels

### Priority levels
- **1** = Must have — o produto não funciona sem ela
- **2** = Should have — agrega valor significativo
- **3** = Could have — melhoria incremental
````
