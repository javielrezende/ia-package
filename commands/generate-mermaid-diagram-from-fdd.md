---
description: Gerar diagramas Mermaid a partir de um Documento de Design de Funcionalidade (FDD). Usage: /generate-mermaid-diagram-from-fdd <path-to-fdd.md> [output-folder]
---

Você DEVE invocar o agente gerador de diagramas Mermaid usando a Agent tool com subagent_type="mermaid-diagram-generator".

Extraia o caminho do arquivo do FDD e a pasta de saída opcional dos argumentos do comando:
- Caminho do arquivo FDD (obrigatório)
- Pasta de saída (opcional, padrão: "docs/mermaid")

NOME BASE DO ARQUIVO: resolva-o a partir do caminho do FDD. A primeira linha que casar vale:

| FDD recebido | Nome base |
|---|---|
| `FDD.md` ou `FDD-*.md` dentro de uma pasta de feature `F<ID>-<slug>/` — `docs/F03-video-upload/FDD.md`, `docs/F03-video-upload/FDD-2026-09-19.md` | o nome da pasta: `F03-video-upload` |
| `FDD.md` ou `FDD-<AAAA-MM-DD>.md` fora de pasta de feature — `docs/FDD.md`, `docs/FDD-2026-09-19.md` | nenhum: o nome não identifica a feature. Pergunte ao usuário, sugerindo o nome da feature do título do FDD em minúsculas, sem acento e com hifens |
| `FDD-<slug>.md` fora de pasta de feature — `docs/FDD-upload-de-video.md` | o `<slug>`: `upload-de-video` |
| qualquer outro nome — `ratelimiter-fdd.md` | o nome do arquivo sem a extensão e sem o sufixo `-fdd`: `ratelimiter` |

Nunca derive o nome base de um arquivo chamado `FDD.md` ou `FDD-<data>.md`: no layout por feature todo FDD se chama assim, e a segunda feature sobrescreveria os diagramas da primeira.

ANTES DE DESPACHAR: se `<pasta de saída>/<nome>-diagrams.md` já existir, não invoque o agente ainda. Mostre o caminho e pergunte ao usuário:
- **sobrescrever** — o agente grava por cima do arquivo existente;
- **gravar com data** — o nome base passa a ser `<nome>-<AAAA-MM-DD>`, com a data de hoje;
- **cancelar** — encerre sem invocar o agente.

Só prossiga depois da resposta.

Passe a seguinte instrução detalhada para o agente:

"Gere diagramas Mermaid a partir do Documento de Design de Funcionalidade localizado em [FDD_FILE_PATH].

Pasta de saída: [OUTPUT_FOLDER]
Nome base dos arquivos: [NOME_BASE]

O agente executará seu fluxo de trabalho completo (Fases 1-9). Sua tarefa é garantir que o agente receba o caminho do FDD, a pasta de saída e o nome base corretos.

Requisitos principais que o agente seguirá:

ANÁLISE E SELEÇÃO:
- Leia o FDD completamente (se não estiver em português, traduza o conteúdo ao gerar)
- Extraia elementos explícitos e identifique o que é central para o sucesso do sistema
- Avalie a importância rigorosamente usando 5 critérios (fluxo principal, partes complexas, decisões de arquitetura, contratos públicos, relacionamentos)
- Selecione os tipos de diagramas apropriados (Sequência, Fluxograma TD/LR, Classe, Entidade-Relacionamento)
- Filtre para os diagramas mais valiosos (típico: 6-8, até 10 no máximo se genuinamente justificado)

GERAÇÃO:
- Crie UM arquivo markdown: [OUTPUT_FOLDER]/[NOME_BASE]-diagrams.md - use o nome base literalmente, nunca o derive do nome do arquivo do FDD
- Escreva TODO o documento em português (pt-BR), incluindo os cabeçalhos de seção, com a acentuação adequada
- Mantenha os termos técnicos em inglês (Service, Gateway, Redis, etc.)
- Escreva parágrafos concisos (3-5 frases) para cada diagrama
- Use rótulos concisos (máximo de 3 palavras por nó)
- Use acentuação adequada EM TODA PARTE (texto em markdown E rótulos dos nós do diagrama)
- Aplique validação de sintaxe do Mermaid e mecanismos de proteção automaticamente

GARANTIA DE QUALIDADE:
- Revisão interna obrigatória: releia o FDD e o documento, identifique e corrija TODAS as inconsistências
- Valide: documento em pt-BR, 1-10 diagramas (típico: 6-8), critérios de importância atendidos, sem redundância/invenção/itens excluídos
- Crie um arquivo completo e autossuficiente
- Relatório: idioma do FDD, caminho do arquivo, número de diagramas, justificativa, resultados da validação

REGRAS CRÍTICAS:
- Nunca invente informações que não estejam no FDD
- Gere diagramas em português (pt-BR) com a acentuação adequada EM TODA PARTE
- É melhor 6 diagramas excelentes do que 10 medíocres
- Revisão interna obrigatória antes da conclusão
- Mantenha os termos técnicos em inglês
- Sem emojis em lugar nenhum
- Use acentuação adequada nos rótulos dos nós (Mermaid suporta UTF-8)
- Mantenha os rótulos dos nós simples; evite expressões complexas
- Coloque os detalhes técnicos na seção de notas abaixo do diagrama, não nos rótulos
- O agente lida com toda a validação de sintaxe e mecanismos de proteção automaticamente"

Substitua [FDD_FILE_PATH] pelo caminho real do arquivo fornecido nos argumentos do comando.
Substitua [OUTPUT_FOLDER] pela pasta de saída especificada ou "docs/mermaid" se não for fornecida.
Substitua [NOME_BASE] pelo nome base resolvido acima (já com a data, se o usuário escolheu gravar com data).