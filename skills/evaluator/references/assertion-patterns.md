# Assertion Patterns

Frases reconhecidas nos bullets do `then` dos itens do contrato que o evaluator traduz **mecanicamente** para asserções executáveis. Quando um bullet dá match com um destes padrões, a skill executa a tradução diretamente, sem interpretação por LLM. Quando um bullet NÃO dá match, o modelo o interpreta livremente e o item é **marcado com `*`** no relatório (a interpretação é registrada no raciocínio do item).

Este arquivo é a **fronteira** entre a tradução mecânica confiável e a interpretação por LLM marcada. Adicionar um padrão aqui tira uma frase do território do LLM e a leva para a execução mecânica. Padrões só devem ser adicionados depois de aparecerem em contratos reais ao menos duas vezes.

A gramática é intencionalmente informal — um pequeno conjunto de formatos reconhecíveis, não um parser estrito. Quando um julgamento em tempo de avaliação conclui que um bullet "obviamente" dá match com um padrão mesmo com redação ligeiramente diferente, ele pode ser traduzido mecanicamente e o match leniente é anotado na evidência. Na dúvida, prefira marcar com `*`.

**Idioma.** Os contratos são escritos em pt-BR, com status HTTP, nomes de headers, cookies, rotas, códigos de erro e comandos mantidos como são. Cada padrão lista frases em inglês e em pt-BR; as duas formas são equivalentes e produzem a mesma tradução. Formas neutras de idioma (`201 Created`, `body.<path> === <literal>`, `Content-Type: <value>`) aparecem uma vez só, na lista em inglês.

---

## HTTP

### Status code

Frases em inglês:
- `<N> <Reason>` (`201 Created`, `413 Payload Too Large`, `422 Unprocessable Entity`)
- `responds with status <N>`
- `HTTP <N>`

Frases em pt-BR:
- `responde com status <N>`

Tradução: `assert response.status === <N>`.

### Body field equality

Frases em inglês:
- `body.<path> === <literal>`
- `<field>: "<literal>"` dentro de uma forma inline de body
- `<field>` set to `<literal>`

Frases em pt-BR:
- `<field>` definido como `<literal>`
- `<field>` igual a `<literal>`

Tradução: `assert get(response.body, "<path>") === <literal>`.

### Body field type / shape

Frases em inglês:
- `<field>` (uuid)
- `<field>` (ISO 8601)
- `<field>` is a non-empty string / number / boolean / null
- `<field>` (= <handle>.<attribute>) — igualdade contra um handle de Persistent state

Frases em pt-BR:
- `<field>` é uma string não vazia / um número / um booleano / null
- `<field>: não nulo`

Tradução: checagem de tipo / forma correspondente ao tipo nomeado (`não nulo` → o campo está presente e não é null). A forma `(= <handle>.<attribute>)` resolve o handle a partir do Persistent state e verifica a igualdade.

### Body field comparison

Frases em inglês:
- `<field>` ≈ `<value>` (dentro de uma tolerância, default 5 % quando não declarada; recomendado para durações, tamanhos)
- `<field>` `> | < | >= | <=` `<value>`
- `<field>` matches `<regex>` or matches `/pattern/`

Frases em pt-BR:
- `<field>` maior que | menor que | maior ou igual a | menor ou igual a `<value>`
- `<field>` corresponde a `<regex>` / corresponde a `/pattern/`

Tradução: comparação numérica com a tolerância declarada, ou match de regex.

### Body shape

Frases em inglês:
- `body { field1, field2, ... }` (forma anônima — verifica que cada campo está presente, com checagem de tipo quando anotado)
- `response body matches { ... }` (campos nomeados com tipos ou valores)

Frases em pt-BR:
- `o body da resposta corresponde a { ... }`
- `<N> <Reason> com body { ... }` — status e forma no mesmo bullet; aplique a tradução de **Status code** e a desta seção

Tradução: verifique que cada campo nomeado está presente; verifique os tipos ou valores declarados quando anotados.

### Headers

Frases em inglês:
- `Content-Type: <value>`
- header `<name>` is `<value>`
- header `<name>` matches `<regex>`

Frases em pt-BR:
- header `<name>` é `<value>`
- header `<name>` corresponde a `<regex>`

Tradução: verifique que o header da resposta é igual ou dá match.

---

## Persistence (DB)

### Row count

Frases em inglês:
- `exactly <N> row(s) exist in <table>` [`for <column> = <value>`]
- `<N> rows in <table>`
- `zero rows in <table>` [`for <column> = <value>`]

Frases em pt-BR:
- `existe(m) exatamente <N> linha(s) em <table>` [`com <column> = <value>`]
- `<N> linhas em <table>`
- `zero linhas em <table>` [`com <column> = <value>`]

Tradução: `SELECT count(*) FROM <table> [WHERE ...] === <N>`. A cláusula `WHERE` é montada a partir do predicado `for` / `com` (resolução de handle permitida: `for owner_id = alice.id` resolve o id de alice a partir do Persistent state).

### Row values

Frases em inglês:
- `the row in <table> has <column> = <value>`
- `the persisted row's <column> equals <handle>.<attribute>`
- `<column> IS NULL` / `<column> IS NOT NULL`
- `whose values match the response body` (cross-check: cada coluna é igual ao campo de nome equivalente capturado da resposta)

Frases em pt-BR:
- `a linha em <table> tem <column> = <value>`
- `o <column> da linha persistida é igual a <handle>.<attribute>`
- `cujos valores batem com o body da resposta`

Tradução: `SELECT * FROM <table> WHERE ...` e então verifique igualdade por coluna, nulidade ou match entre fontes.

### Row absence

Frases em inglês:
- `no row exists in <table>` [`for <column> = <value>`]
- `<table> is empty` [`for <column> = <value>`]

Frases em pt-BR:
- `nenhuma linha existe em <table>` [`com <column> = <value>`]
- `<table> está vazia` [`com <column> = <value>`]

Tradução: `SELECT count(*) ... === 0`.

---

## Filesystem

### File existence

Frases em inglês:
- `the file at <path> exists`
- `<path> is a non-empty <type>` (ex.: `JPEG`, `PNG`, `MP4`)

Frases em pt-BR:
- `o arquivo em <path> existe`
- `<path> é um <type> não vazio`

Tradução: `stat(path)` tem sucesso e `size > 0`. Para conteúdo tipado, um sniff de magic bytes ou `file <path>` confirma o tipo.

### File absence

Frases em inglês:
- `no file is left under <directory>`
- `<directory> is empty`
- `no <kind> was persisted under <directory>`

Frases em pt-BR:
- `nenhum arquivo fica em <directory>`
- `<directory> está vazio`
- `nenhum <kind> foi persistido em <directory>`

Tradução: `readdir(directory)` retorna vazio (ou filtrado pelo tipo nomeado).

### File size

Frases em inglês:
- `the file at <path> has the same byte count as <fixture>`
- `size of <path> equals <N>`

Frases em pt-BR:
- `o arquivo em <path> tem o mesmo número de bytes que <fixture>`
- `o tamanho de <path> é <N>`

Tradução: `stat(path).size === stat(fixture).size`, ou igualdade numérica.

### Indirect path (path discovered from a row)

Frases em inglês:
- `the file referenced by that row's <column>`

Frases em pt-BR:
- `o arquivo referenciado pela coluna <column> dessa linha`

Tradução: leia `<column>` da linha verificada anteriormente e aplique as checagens de existência / tamanho de arquivo no path resultante.

---

## UI / DOM (superfícies `UI` e `E2E` conduzindo um navegador)

### Element presence

Frases em inglês:
- `the page contains a <region | element> with the heading text "<text>"`
- `a "<label>" button is rendered and enabled`
- `a queue row appears whose label includes <quoted text>`

Frases em pt-BR:
- `a página contém um(a) <região | elemento> com o título "<text>"`
- `um botão "<label>" é renderizado e está habilitado`
- `aparece uma linha da fila cujo rótulo inclui <texto entre aspas>`

Tradução: query selector ou busca por accessible name; verifique a presença e (para botões) que o atributo `disabled` está ausente.

### Element text

Frases em inglês:
- `the row's <element> reads "<text>"`
- `<region> displays "<text>"`
- contains tokens `<token1>` and `<token2>`

Frases em pt-BR:
- `o <elemento> da linha diz "<text>"`
- `<região> exibe "<text>"` / `<região> diz "<text>"`
- contém os tokens `<token1>` e `<token2>`

Tradução: extração de texto; igualdade, substring ou match de todos os tokens presentes.

### Element absence

Frases em inglês:
- `no <region> is rendered`
- `no <element> outside of <other element> accepts <kind> drops on <route>`

Frases em pt-BR:
- `nenhum(a) <região> é renderizado(a)`
- `nenhum(a) <elemento> fora de <outro elemento> aceita drops de <kind> em <route>`

Tradução: a query retorna vazio.

### URL navigation

Frases em inglês:
- `the URL becomes <path>`
- `navigate to <path>`

Frases em pt-BR:
- `a URL passa a ser <path>`
- `a página navega para <path>`

Tradução: verifique a location do navegador.

### Network observed

Frases em inglês:
- `no network request is made to <pattern>`
- `the navigation succeeds without canceling the in-flight request (no aborted XHR)`

Frases em pt-BR:
- `nenhuma requisição de rede é feita para <pattern>`
- `a navegação tem sucesso sem cancelar a requisição em andamento (nenhum XHR abortado)`

Tradução: capture o log de rede durante a ação e verifique ausência / presença.

### Progress / dynamic value

Frases em inglês:
- `progress percentage advances from 0 to 100`
- `bytes transferred alongside total bytes (e.g., "X.X MB / X.X MB")`

Frases em pt-BR:
- `o percentual de progresso avança de 0 a 100`
- `bytes transferidos junto do total de bytes (ex.: "X.X MB / X.X MB")`

Tradução: faça polling do elemento DOM relevante ao longo de uma janela de tempo; verifique progressão monotônica com valor final no limite superior ou próximo dele.

---

## Service (superfície `Service`)

### Function call result

Frases em inglês:
- `<function>(<args>) returns <value>`
- `<function>(<args>) throws <error type>`

Frases em pt-BR:
- `<function>(<args>) retorna <value>`
- `<function>(<args>) lança <error type>`

Tradução: invoque a função no runtime do projeto (o modelo descobre o path de import a partir do item do contrato mais o spec.md ou a codebase); verifique o valor retornado ou o tipo do erro lançado.

---

## Cross-cutting

### Error envelope

Frases em inglês:
- `body { code: "<CODE>", message }` — envelope de erro comum
- `body.code === "<CODE>"`
- `details.<field>: <value>`

Frases em pt-BR:
- `<N> <Reason> com code <CODE>` — status e código de erro no mesmo bullet; aplique a tradução de **Status code** e a desta seção
- `com code <CODE>`

Tradução: verifique `body.code === "<CODE>"`; quando `message` é nomeado sem valor, verifique que é uma string não vazia; verifique `details.<field>` aninhado conforme sua anotação.

### Time and ordering

Frases em inglês:
- `createdAt (ISO 8601)`
- `<field>` happens before `<field>`

Frases em pt-BR:
- `<field>` acontece antes de `<field>`

Tradução: parse ISO 8601 + comparação monotônica.

### Cross-source match (response ↔ DB ↔ filesystem)

Frases em inglês:
- `the persisted row's values match the response body`
- `the file at <path> has the same byte count as <fixture>`

Frases em pt-BR:
- `os valores da linha persistida batem com o body da resposta`
- `o arquivo em <path> tem o mesmo número de bytes que <fixture>`

Tradução: capture primeiro o body da resposta / as estatísticas da fixture; depois verifique que a linha / o arquivo nomeado corresponde à fonte capturada.

---

## Anti-patterns (NÃO traduza mecanicamente)

Estas frases não podem ser verificadas automaticamente de forma confiável. Itens contendo apenas bullets desse tipo são `MANUAL`. Itens que os misturam com bullets mecânicos são parcialmente mecânicos + o bullet não verificável é registrado como não verificável, levando o item a `MANUAL` no geral.

- "feels right", "looks correct", "matches the design system" / "parece certo", "parece correto", "segue o design system" sem um seletor concreto ou especificação de cor — subjetivo.
- "eventually" / "after some time" / "em algum momento" / "depois de algum tempo" sem um limite — não determinístico.
- "the user understands" / "is clear to the user" / "o usuário entende" / "fica claro para o usuário" — subjetivo.
- referências a características de performance (latência, throughput) sem um limite mensurável.
- "approximately" / "aproximadamente" sem tolerância e sem valor de referência contra o qual o evaluator possa calcular.
