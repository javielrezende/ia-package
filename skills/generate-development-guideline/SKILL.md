---
name: generate-development-guideline
description: |
  Gera um documento extenso de diretrizes de desenvolvimento (1000-1500 linhas) para uma linguagem específica, opcionalmente parametrizado pela stack (ORM, framework web, driver de banco, testes, logging, validação, HTTP, DI, async, serialização). Use quando: (1) Padronizar convenções de código, arquitetura e testes de uma linguagem em um projeto ou time, (2) Criar um guia de referência com exemplos de certo contra errado e comandos executáveis, (3) Documentar a stack escolhida de um serviço novo. Aceita argumentos no formato "<linguagem> --orm=... --web=... --testing=...". Keywords: "diretriz de desenvolvimento", "development guideline", "guia de estilo", "coding standards", "convenções de código", "padronizar código".
---

# Gerar Diretriz de Desenvolvimento

Você tem a tarefa de criar um documento abrangente de diretrizes de desenvolvimento para **{{LANGUAGE}}** seguindo a estrutura do template fornecida no final deste arquivo.

## SINTAXE DO COMANDO

/generate-development-guideline <language> [--param=value ...]

**Parâmetros Suportados** (todos opcionais):

- `-orm=<name>` - ORM ou query builder (ex: prisma, sqlalchemy, sqlc, gorm, hibernate)
- `-web=<name>` - Framework Web (ex: express, fastapi, chi, spring-boot, gin, flask)
- `-framework=<name>` - Framework Principal (ex: laravel, nestjs, langgraph, langchain, spring, django)
- `-db=<name>` - Driver de Banco de Dados (ex: pgx, asyncpg, mysql2, jdbc, psycopg2)
- `-testing=<name>` - Framework de Testes (ex: jest, pytest, testify, junit, vitest)
- `-logging=<name>` - Biblioteca de Logs (ex: winston, structlog, zap, logrus, log4j)
- `-validation=<name>` - Biblioteca de Validação (ex: zod, pydantic, validator, joi)
- `-http=<name>` - Cliente HTTP (ex: axios, requests, resty, okhttp, httpx)
- `-di=<name>` - Injeção de Dependências (ex: inversify, wire, spring, dagger)
- `-async=<name>` - Runtime Assíncrono (ex: tokio, asyncio, async-std, gevent)
- `-serialization=<name>` - Biblioteca de Serialização (ex: serde, jackson, gson, msgpack)

**Exemplos**:
/generate-development-guideline Go --orm=sqlc --web=chi --db=pgx --testing=testify
/generate-development-guideline TypeScript --orm=prisma --web=express --testing=jest --validation=zod
/generate-development-guideline Python --orm=sqlalchemy --web=fastapi --logging=structlog
/generate-development-guideline Rust --orm=diesel --web=axum --async=tokio --serialization=serde

## REQUISITOS DE QUALIDADE

### Alvo do Documento

- **Tamanho**: 1000-1500 linhas no total
- **Blocos de código**: Mínimo 20
- **Exemplos de Certo vs Errado**: Mínimo 5
- **Comandos**: Mínimo 15 exemplos executáveis
- SEM emojis, SEM placeholders (TODO, TBD)

### Estilo de Escrita

- **CONCISO**: Referência rápida, não um livro
- **PRÁTICO**: Mostre código, não apenas teoria
- **FOCADO**: Cubra o essencial, pule casos isolados (edge cases)

### Seções Críticas

Devem ter exemplos de código: 7 (Funções), 8 (Erros), 11 (Testes), 22 (Banco de Dados), 23 (Logs)

## REQUISITOS CRÍTICOS

1. **Siga a estrutura do template**: Leia e adira estritamente à estrutura do template fornecida no final deste arquivo
2. **Numeração correta das seções**: As seções DEVEM ser numeradas sequencialmente (1, 2, 3, ..., N) SEM lacunas
3. **Seções opcionais**: Avalie cada seção `[OPCIONAL]` e inclua APENAS se a linguagem suportar aquele recurso
4. **Ao pular seções**: Ajuste TODA a numeração subsequente para manter a ordem sequencial
5. **Baseado em pesquisa**: TODO o conteúdo deve ser baseado em fontes com autoridade encontradas através de pesquisa na web

## PROCESSO DE EXECUÇÃO

### Fase 0: Parseamento de Parâmetros e Padrões Automáticos (PRIMEIRO PASSO)

**Faça o parse da invocação do comando** para extrair as preferências de bibliotecas/frameworks dos parâmetros.

**Crie uma configuração de "Stack do Projeto" com padrões automáticos**:

1. Extraia todos os parâmetros `-key=value` do comando
2. **Preencha automaticamente as categorias essenciais** se não especificadas:
    - `testing`: Selecione automaticamente o framework mais popular para a linguagem
    - `formatting`: Selecione automaticamente o formatador padrão (black, gofmt, prettier, rustfmt)
    - `linting`: Selecione automaticamente o linter padrão para a linguagem
    - `logging`: Selecione automaticamente o log da stdlib se for bom, ou a biblioteca mais popular
    - `build_tool`: Selecione automaticamente a ferramenta de build nativa quando aplicável (make, cargo, gradle)
3. **NÃO preencha automaticamente categorias opinativas** (orm, framework web, driver de db)
4. Construa o objeto final da stack com as bibliotecas especificadas + preenchidas automaticamente

**Regras de Padrão Automático por Linguagem**:

**Go**:
testing: "testing (stdlib) + testify para asserções"
formatting: "gofmt, goimports"
linting: "go vet, staticcheck, golangci-lint"
logging: "log/slog (Go 1.21+)"
build_tool: "go build, make"

**Python**:
testing: "pytest (mais popular) ou unittest (stdlib)"
formatting: "black"
linting: "flake8, pylint"
type_checking: "mypy"
logging: "logging (stdlib)"
build_tool: "pip, poetry"

**TypeScript/JavaScript**:
testing: "jest ou vitest"
formatting: "prettier"
linting: "eslint"
type_checking: "tsc"
logging: "winston ou pino"
build_tool: "npm, pnpm, yarn"

**Rust**:
testing: "cargo test (stdlib)"
formatting: "rustfmt"
linting: "clippy"
logging: "tracing ou crate log"
build_tool: "cargo"

**Exemplo de parseamento com padrões automáticos**:
Comando: /generate-development-guideline Go --orm=sqlc --web=chi --db=pgx

Resultado:
{
"language": "Go",
"stack": {
"orm": "sqlc",              // Especificado pelo usuário
"web": "chi",               // Especificado pelo usuário
"db": "pgx",                // Especificado pelo usuário
"testing": "testify",       // PREENCHIDO AUTOMATICAMENTE
"logging": "log/slog",      // PREENCHIDO AUTOMATICAMENTE
"formatting": "gofmt",      // PREENCHIDO AUTOMATICAMENTE
"linting": "staticcheck",   // PREENCHIDO AUTOMATICAMENTE
"build_tool": "make",       // PREENCHIDO AUTOMATICAMENTE
"validation": null,         // Não aplicável para Go
"http": null,               // Não especificado, não preenchido
"di": null,                 // Não especificado, não preenchido
"async": null,              // N/A para Go (sem runtime assíncrono)
"serialization": null       // Não especificado, não preenchido
}
}

**Relatório de Saída da Fase 0**:
CONFIGURAÇÃO DA STACK DO PROJETO
Linguagem: {{LANGUAGE}}

Bibliotecas Especificadas pelo Usuário:

- ORM: {{orm}}
- Framework Web: {{web}}
- Driver de Banco de Dados: {{db}}

Ferramentas Essenciais Preenchidas Automaticamente:

- Testes: {{testing}} (selecionado automaticamente)
- Formatação: {{formatting}} (selecionado automaticamente)
- Linting: {{linting}} (selecionado automaticamente)
- Logs: {{logging}} (selecionado automaticamente)
- Ferramenta de Build: {{build_tool}} (selecionado automaticamente)

Não Especificado (usará diretrizes genéricas da linguagem ou fallback padrão):

- Cliente HTTP
- Injeção de Dependências
- [... outras categorias]

NOTA: Se o usuário especificou bibliotecas na Stack, os exemplos de código DEVERÃO utilizar essas bibliotecas. Caso nenhuma tenha sido especificada, use estritamente os recursos nativos/stdlib da linguagem.

### Fase 1: Pesquisa (OBRIGATÓRIO)

Use **WebSearch** extensivamente para encontrar e analisar. **Mínimo de 5 fontes oficiais requeridas.**

**1. Documentação Oficial** (OBRIGATÓRIO - mínimo 3 fontes):

- Documentação oficial da linguagem e tutoriais
- Guias de estilo oficiais e padrões de codificação
- Documentação oficial de melhores práticas
- Documentos de especificação da linguagem

**2. Diretrizes Autorizadas da Indústria** (mínimo 2 fontes):

- Guias de estilo de grandes empresas (Google, Uber, Airbnb, Microsoft, Meta, Netflix, etc.)
- Diretrizes de projetos open-source proeminentes
- Padrões de comunidade e convenções bem estabelecidas

**3. Ferramentas Essenciais do Ecossistema** (pesquise para TODAS as linguagens):

- Gerenciadores de pacotes/dependências oficiais
- Formatadores e linters de código padrão
- Frameworks de teste nativos ou mais populares
- Ferramentas de build e executores de tarefas (quando aplicável)
- Ferramentas de profiling e debugging

**4. Características da Linguagem** (análise profunda necessária):

- Sistema de tipos: estático/dinâmico, forte/fraco
- Modelo de concorrência: threads, async/await, goroutines, actors, etc.
- Mecanismos de interface/abstração: interfaces, traits, protocols, duck typing
- Gerenciamento de memória: garbage collection, manual, reference counting, ownership
- Abordagens padrão de conectividade de banco de dados (drivers, padrões de conexão)

**5. Exemplos do Mundo Real** (encontre pelo menos 3 codebases de produção):

- Estruturas de projeto em nível de produção
- Convenções de nomenclatura padrão da indústria
- Padrões e anti-padrões comuns com exemplos

**6. Pesquisa de Bibliotecas** (para especificadas pelo usuário E preenchidas automaticamente):

Para **TODAS as bibliotecas na Stack do Projeto**:

- URL da documentação oficial ou URL do repositório no GitHub
- Breve descrição do propósito (máximo de 1-2 frases)
- Último número de versão estável

**Verificação de Completude da Pesquisa**:

- [ ]  Mínimo de 5 fontes oficiais documentadas
- [ ]  Pelo menos 3 exemplos de codebase de produção encontrados
- [ ]  Todas as ferramentas essenciais identificadas (formatador, linter, testes, build)
- [ ]  Todas as bibliotecas da Stack do Projeto possuem: nome, versão, propósito, link

### Fase 2: Análise e Planejamento

Com base nas descobertas da sua pesquisa, determine:

**1. Quais seções `[OPCIONAL]` incluir**:

Avalie cada seção opcional:

- **Seção 4 (Docker)**: Inclua se o desenvolvimento em contêiner for uma prática comum no ecossistema da linguagem.
- **Seção 6 (Tipos)**: Inclua se a linguagem tiver tipagem estática ou sistema de tipos forte.
- **Seção 9 (Concorrência)**: Inclua se a linguagem possuir primitivas nativas de concorrência.
- **Seção 10 (Interfaces)**: Inclua se a linguagem possuir interfaces, traits, protocolos ou abstrações similares.
- **Seção 12 (Mocks)**: Inclua se existirem ferramentas ou padrões maduros de mocking.
- **Seção 14 (Teste de Carga)**: Inclua se ferramentas ou práticas específicas de teste de carga forem estabelecidas na linguagem.
- **Seção 15 (Profiling)**: Inclua se existirem ferramentas maduras de profiling.
- **Seção 16 (Benchmarks)**: Inclua se existir um framework nativo ou bem estabelecido para benchmarking.
- **Seção 17 (Otimização)**: Inclua se técnicas de otimização específicas da linguagem estiverem documentadas.

**2. Calcule o número final de seções e crie o mapeamento da numeração**:

- Conte todas as seções, garanta a numeração sequencial com NENHUMA lacuna e remova as tags de opcionalidade.

**3. Finalize a Stack do Projeto**:

- Verifique se as bibliotecas especificadas (se houver) são apropriadas para {{LANGUAGE}}.

### Fase 3: Geração de Conteúdo em Múltiplas Fases

**CRÍTICO**: A geração do documento é dividida em 4 subfases para permanecer sob o limite de saída.

**REGRAS DE CONCISÃO** (aplica-se a TODAS as subfases):

- Cada seção: Máximo de 30-50 linhas
- Máximo de 3 subseções por seção
- Um exemplo de código por conceito
- Direto e prático, não verboso

**Regras Globais de Geração** (aplica-se a TODAS as subfases):

**1. Numeração**:

- Use APENAS números sequenciais: 1, 2, 3, 4, ..., N sem lacunas.

**2. Qualidade do Conteúdo**:

- Preencha cada seção com conteúdo substancial e prático, usando exemplos REAIS.

**3. Autenticidade Específica da Linguagem**:

- Use código idiomático para a linguagem. Siga convenções do ecossistema.

**4. Estratégia de Integração de Bibliotecas** (CRÍTICO):

**Filosofia dos Exemplos de Código**:

- Se o usuário **ESPECIFICOU** uma biblioteca ou framework nos parâmetros (ex: `-orm=prisma`, `-web=chi`), **VOCÊ DEVE OBRIGATORIAMENTE utilizar essa ferramenta nos exemplos de código**.
- Para categorias **NÃO ESPECIFICADAS** pelo usuário, use recursos da Standard Library (stdlib) nativos da linguagem como fallback.

**Abordagem de Exemplo por Seção**:

- **Banco de Dados (Seção 22)**: Use a biblioteca/ORM especificada (ex: Prisma, Gorm). Se vazia, use o driver nativo (ex: database/sql).
- **Testes (Seção 11)**: Use a ferramenta de testes fornecida/calculada (ex: Jest, Testify).
- **Logs (Seção 23)**: Use a ferramenta de log especificada (ex: Winston, Zap). Se vazia, use a stdlib.
- **Web/HTTP**: Use o framework especificado (ex: Express, FastAPI). Se vazio, use o servidor padrão nativo.

**Seção Stack do Projeto** (apenas referência):

**SEMPRE inclua a seção "Stack do Projeto"** quando QUALQUER biblioteca estiver na stack:

## Stack do Projeto

As seguintes bibliotecas formam a base tecnológica deste guia:

**Bibliotecas Especificadas pelo Usuário**:

- **ORM/Banco de Dados**: {{orm}} (v{{version}}) - {{purpose}} - {{link}}
- **Framework Web**: {{web}} (v{{version}}) - {{purpose}} - {{link}}

**Ferramentas Essenciais Preenchidas Automaticamente**:

- **Testes**: {{testing}} (v{{version}}) - {{purpose}} - {{link}}
- **Formatação**: {{formatting}} - {{purpose}} - {{link}}
- **Linting**: {{linting}} - {{purpose}} - {{link}}
- **Logs**: {{logging}} (v{{version}}) - {{purpose}} - {{link}}

> **Nota**: Os exemplos de código a seguir priorizarão as tecnologias definidas na Stack. Para camadas não especificadas, adotaremos os padrões nativos e idiomáticos da linguagem.
> 

**Posição**: Posicione a seção Stack do Projeto imediatamente após o título, antes da Seção 1.

### Fase 3.1: Geração da Fundação (Seções 1-8)

Gere as seções 1-8 (Princípios Principais até Tratamento de Erros).

### Fase 3.2: Geração da Implementação Core (Seções 9-16)

Gere as seções 9-16 (Concorrência até Benchmarks).

### Fase 3.3: Geração de Práticas & Padrões (Seções 17-21)

Gere as seções 17-21 (Otimização até Comentários).

### Fase 3.4: Geração de Banco de Dados, Logs & Finalização (Seções 22-26)

Gere as seções 22-26 (Banco de Dados até Referências).

### Fase 3.5: Validação Rápida

Conte o total de linhas. Mantenha o arquivo final entre 1000-1500 linhas reduzindo introduções ou consolidando código se necessário. Garanta que frameworks do usuário constem nos códigos (se informados).

### Fase 4: Validação Final

- [ ]  Seções numeradas sequencialmente.
- [ ]  NENHUM marcador `[OPCIONAL]`.
- [ ]  Exemplos de código utilizam a biblioteca especificada (ou stdlib se vazia).

## ENTREGÁVEIS (OUTPUT)

Forneça o seguinte:

**1. Saída da Fase 0**: Configuração da Stack e parâmetros processados.
**2. Resumo da Pesquisa**: Fontes consultadas e ecossistema básico.
**3. Relatório de Inclusão de Seções**: Quais foram incluídas/excluídas e o porquê.
**4. Relatório Final da Stack**.
**5. Documento Final**: O guia completo markdown consolidado com "Stack do Projeto" (se pertinente), salvo virtualmente como `{{LANGUAGE}}-development-guidelines.md`.
**6. Relatório de Validação**.

## ANTI-PADRÕES A EVITAR

**NÃO**:

- Deixe lacunas na numeração das seções.
- Mantenha marcadores `[OPCIONAL]`.
- Ignore as bibliotecas especificadas pelo usuário nos exemplos de código (se o usuário enviou uma stack, use-a).
- Copie e cole de outras linguagens sem adaptação idiomática.

**FAÇA**:

- Renumere TODAS as seções ao excluir as opcionais.
- Adote o framework ou lib passada pelo usuário como o padrão do documento para aquela camada.
- Forneça exemplos práticos e não abstrações vagas.

---

# ESTRUTURA DO TEMPLATE

## 1. Princípios Principais

### 1.1 Filosofia e Estilo

### 1.2 Clareza acima da Brevidade

## 2. Inicialização do Projeto

### 2.1 Criando um Novo Projeto

### 2.2 Gerenciamento de Dependências

## 3. Estrutura do Projeto

## [OPCIONAL] 4. Desenvolvimento em Contêiner (Docker)

### 4.1 Filosofia de Contêiner

### 4.2 Estrutura de Arquivos do Docker

### 4.3 Dockerfile para Desenvolvimento

### 4.4 Docker Compose

### 4.5 .dockerignore

### 4.6 Comandos Essenciais

### [OPCIONAL] 4.7 Makefile

### 4.8 Boas Práticas

## 5. Convenções de Nomenclatura

## [OPCIONAL] 6. Tipos e Sistema de Tipos

### 6.1 Declaração de Tipos

### 6.2 Segurança de Tipos (Type Safety)

### 6.3 Alocação e Inicialização

## 7. Funções e Métodos

### 7.1 Assinaturas

### 7.2 Retornos e Erros (Inclua exemplo de Certo vs Errado)

### 7.3 Boas Práticas

## 8. Tratamento de Erros

### 8.1 Filosofia

### 8.2 Convenções (Inclua exemplo de Certo vs Errado)

### 8.3 Boas Práticas

## [OPCIONAL] 9. Concorrência e Paralelismo

### 9.1 Modelo de Concorrência

### 9.2 Sincronização

### 9.3 Boas Práticas

### 9.4 Armadilhas Comuns (Pitfalls)

## [OPCIONAL] 10. Interfaces e Abstrações

### 10.1 Design de Interface

### 10.2 Implementação

### 10.3 Composição

## 11. Testes Unitários

### 11.1 Estrutura (Use biblioteca de testes especificada)

### 11.2 Testes Baseados em Tabelas

### 11.3 Asserções

### 11.4 Comandos executáveis

## [OPCIONAL] 12. Mocks e Testabilidade

### 12.1 Estratégias de Mock

### 12.2 Injeção de Dependências

### 12.3 Dublês de Teste (Test Doubles)

## 13. Testes de Integração

### 13.1 Estrutura e Organização

### 13.2 Execução Seletiva

### 13.3 Dependências Reais

## [OPCIONAL] 14. Testes de Carga e Stress

### 14.1 Ferramentas

### 14.2 Benchmarks de Carga

### 14.3 Testes de Concorrência

## [OPCIONAL] 15. Profiling e Diagnósticos

### 15.1 Profiling de CPU e Memória

### 15.2 Ferramentas de Diagnóstico

### 15.3 Análise de Performance

## [OPCIONAL] 16. Benchmarks

### 16.1 Escrevendo Benchmarks

### 16.2 Sub-benchmarks

### 16.3 Execução e Análise

## [OPCIONAL] 17. Otimização

### 17.1 Princípios

### 17.2 Otimizações Comuns

### 17.3 Otimização de Memória

### 17.4 Performance Básica

## 18. Segurança

### 18.1 Práticas Essenciais

### 18.2 Ferramentas

### 18.3 Segurança em Bordas de API

## 19. Padrões de Código (Code Patterns)

### 19.1 Retorno Antecipado (Early Return)

### 19.2 Separação de Responsabilidades

### 19.3 DRY (Don't Repeat Yourself)

### 19.4 Escopo de Variáveis

## 20. Gerenciamento de Dependências

### 20.1 Princípios

### 20.2 Comandos

## 21. Comentários e Documentação

### 21.1 Comentários de Código

### 21.2 Documentação de API

### 21.3 Documentação de Pacote

## 22. Banco de Dados

### 22.1 Abordagem

### 22.2 Conexão e Driver

**CRÍTICO: Use a biblioteca/ORM especificada nos parâmetros. Se nenhuma foi fornecida, use a biblioteca padrão/driver oficial.**

### 22.3 Migrations

### 22.4 Boas Práticas

## 23. Logs e Observabilidade

### 23.1 Níveis de Log

### 23.2 Logs Estruturados

### 23.3 Implementação de Logging

**CRÍTICO: Implemente logging usando a biblioteca especificada (ou standard library se vazia).**

### 23.4 Métricas e Observabilidade

## 24. Regras de Ouro

1. Simplicidade 2. Erros explícitos 3. Testes 4. Documentação 5. Performance medida

## 25. Checklist Pré-Commit

### Código / Testes / Qualidade / Documentação / Docker

## 26. Referências

Documentação Oficial / Ferramentas / Comunidade