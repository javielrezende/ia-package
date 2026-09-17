# Rubric

Referência canônica das 4 dimensões, das faixas de nota, das duas calibrações da dimensão 2 e do checklist de AI slop. Carregada de forma lazy pelo Step 6 do `SKILL.md`.

Os rótulos de dimensão e o vocabulário de status ficam em inglês; a descrição das faixas e o raciocínio escrito no relatório são pt-BR.

**Ponderação:** Design Quality e Originality pesam **2x** em relação a Craft e Functionality.

```
Weighted Score = ((Design Quality × 2) + (Originality × 2) + Craft + Functionality) / 6
```

**Postura do avaliador.** Seja cético. Não elogie por default. Toda nota cita evidência específica da tela capturada. Na dúvida sobre uma faixa, escolha a de baixo e explique. O viés natural de um avaliador LLM é a generosidade — as regras de disciplina do Step 6 existem para compensá-lo, e não são opcionais.

---

## 1. Design Quality (peso 2x)

O design parece um todo coerente? Cores, tipografia, layout e imagens devem se combinar num humor e numa identidade visual distintos — não apenas "limpo" ou "moderno", mas algo com um ponto de vista claro.

| Nota | Descrição |
|---|---|
| 9-10 | Identidade visual marcante e coesa. Todo elemento reforça uma direção clara. Passaria por produto desenhado profissionalmente. |
| 7-8 | Identidade visual forte com inconsistências menores. A direção é clara e intencional. |
| 5-6 | Competente, porém genérica. Parece um template bem executado, sem personalidade própria. |
| 3-4 | Inconsistente — alguns elementos parecem pensados, outros parecem defaults. Sem direção unificada. |
| 1-2 | Visualmente incoerente. Estilos brigando entre si, sem intenção de design discernível. |

**O que examinar na evidência:** a paleta se repete com propósito ou cada tela introduz uma cor nova? A tipografia tem uma escala ou os tamanhos foram escolhidos um a um? O espaço em branco é distribuído ou é o que sobrou? Há um elemento que carrega a identidade (uma cor de acento usada com disciplina, uma forma recorrente, um tratamento de imagem) ou a tela é a soma de componentes default?

---

## 2. Originality / Intenção (peso 2x)

**Esta dimensão tem duas calibrações.** O Step 2 do `SKILL.md` detecta qual se aplica e a declara no relatório. Usar a calibração errada inverte o sinal da nota.

### Calibração A — `greenfield`

*Aplica-se quando o projeto não tem design system estabelecido e esta feature é uma das primeiras telas.*

Evidência de decisões próprias, em vez de layouts de template e defaults de biblioteca. Penalize sinais de geração por IA e de "AI slop":

| Nota | Descrição |
|---|---|
| 9-10 | Genuinamente distintiva. Layout, escolhas de cor e interações parecem próprias e surpreendentes. |
| 7-8 | Majoritariamente original, com alguns recuos convencionais. Intenção criativa clara em toda a tela. |
| 5-6 | Alguns toques próprios, mas segue em grande parte padrões comuns. Passaria despercebida entre apps similares. |
| 3-4 | Guiada por template. Grade de cards padrão, estilização default da biblioteca de componentes, layout previsível. |
| 1-2 | Puro default. Indistinguível de um projeto scaffoldado. |

### Calibração B — `design-system`

*Aplica-se quando o projeto tem tokens, biblioteca de componentes ou telas anteriores coerentes.*

Aqui a pergunta muda: **aderir ao sistema é o comportamento correto e não é penalizado.** O que se mede é se as decisões tomadas *dentro* do sistema foram consideradas ou preguiçosas — e desviar do sistema sem motivo passa a custar nota.

| Nota | Descrição |
|---|---|
| 9-10 | Usa o sistema com fluência. Escolhe o componente e o token certos para cada função, compõe soluções novas a partir das peças existentes e estende o sistema de forma coerente onde ele não cobria o caso. |
| 7-8 | Aderente e consistente. Uma ou duas escolhas questionáveis de componente ou token, mas nada que destoe do resto do produto. |
| 5-6 | Aderente de forma mecânica. Empilha componentes default sem adaptá-los ao conteúdo; a tela funciona mas não parece desenhada para este caso de uso. |
| 3-4 | Desvios injustificados: valores hardcoded onde há token, componentes reimplementados à mão, espaçamento fora da escala do sistema. A tela destoa das vizinhas. |
| 1-2 | Ignora o sistema. Cores, tipos e espaçamentos inventados do zero; parece de outro produto. |

**Pistas para classificar a calibração:** `tailwind.config.*` com `theme.extend` preenchido, arquivo de CSS custom properties com escala nomeada, `components/ui/` populado, shadcn/MUI/Chakra instalado e realmente usado, telas anteriores com paleta e tipografia consistentes, guia de marca em `docs/`. Duas ou mais pistas → `design-system`.

### Checklist de AI slop (obrigatório nas duas calibrações)

Preencha **item a item**, com `sim` / `não` e evidência. Cada `sim` precisa aparecer no raciocínio escrito de Originality. Não resuma, não pule, não responda em bloco.

| # | Sinal | Presente? |
|---|---|---|
| S1 | Gradiente roxo/índigo sobre cards brancos | sim / não |
| S2 | Hero section genérica com copy de stock | sim / não |
| S3 | Grade de cards cookie-cutter, todos do mesmo tamanho, sem hierarquia | sim / não |
| S4 | Glassmorphism / vidro fosco como default, sem função | sim / não |
| S5 | Layout simétrico demais, sem tensão visual nenhuma | sim / não |
| S6 | CTAs carregados de gradiente | sim / não |
| S7 | Microcopy de placeholder ("Welcome to [App]", "Get started today", "Lorem ipsum") | sim / não |
| S8 | Emojis como ícones em interface de produto | sim / não |
| S9 | Ícones de três bibliotecas diferentes na mesma tela | sim / não |
| S10 | Sombra `0 4px 6px rgba(0,0,0,0.1)` aplicada uniformemente a tudo | sim / não |

Referência de custo: 0–1 `sim` não impede nota 9-10. 2–3 `sim` limitam Originality a 7. 4 ou mais limitam a 5.

---

## 3. Craft (peso 1x)

Execução técnica do design visual: hierarquia tipográfica, consistência de espaçamento, harmonia cromática, razões de contraste, alinhamento, comportamento responsivo.

> **Nota:** esta é uma checagem de **competência**, não de criatividade. A maioria das implementações tira 5+ aqui por default. Nota baixa indica problema técnico sério, não falta de ambição.

| Nota | Descrição |
|---|---|
| 9-10 | Execução impecável. Escala tipográfica perfeita, sistema de espaçamento consistente, alinhamento exato. |
| 7-8 | Imperfeições menores que não atrapalham a experiência. Atenção sólida ao detalhe. |
| 5-6 | Adequado. Nenhum problema gritante, mas inconsistências são perceptíveis de perto. |
| 3-4 | Espaçamento desleixado, tamanhos de tipo inconsistentes, elementos desalinhados. Parece inacabado. |
| 1-2 | Nenhuma atenção ao detalhe. Layouts quebrados, elementos sobrepostos, texto ilegível. |

**Tetos impostos pelo piso mecânico (Step 5 do `SKILL.md`) — não negociáveis, e só limitam por cima:**

| Condição | Teto de Craft |
|---|---|
| Qualquer `✗` em M1–M6 (acessibilidade) | 6 — e a execução inteira vira `fail` |
| 1–2 `✗` em M7–M10 | 7 |
| ≥ 3 `✗` em M7–M10 | 5 |

---

## 4. Functionality (peso 1x)

Usabilidade independente da estética. O usuário entende a interface, localiza as ações primárias e completa tarefas intuitivamente?

| Nota | Descrição |
|---|---|
| 9-10 | Instantaneamente intuitiva. Hierarquia de informação clara, CTAs óbvios, zero confusão. |
| 7-8 | Fácil de usar, com fricção mínima. Uma ou duas áreas poderiam ser mais claras. |
| 5-6 | Usável, mas exige adivinhação. Ações importantes não são imediatamente óbvias. |
| 3-4 | Navegação ou layout confusos. O usuário teria dificuldade em completar tarefas básicas. |
| 1-2 | Inutilizável. Ações críticas escondidas, affordances enganosas, fluxos quebrados. |

**Os estados de borda pesam aqui, não só o caminho feliz.** Uma tela que resolve bem o caso com dados e deixa o `empty` sem explicação, o `loading` sem indicação e o `error` mostrando uma string crua **não passa de 6**, por melhor que seja o caminho feliz. É o modo de falha mais comum de UI gerada por IA.

---

## Hard threshold

**Qualquer dimensão com nota ≤ 3 reprova a execução, independentemente da nota ponderada.** O relatório precisa dizer especificamente o que corrigir — é o que o `## Design fixes` entrega.
