---
description: Gerar diagramas Mermaid a partir de um Documento de Design de Funcionalidade (FDD). Usage: /generate-mermaid-diagram-from-fdd <path-to-fdd.md> [output-folder]
---

Você DEVE invocar o agente gerador de diagramas Mermaid usando a Agent tool com subagent_type="mermaid-diagram-generator".

Extraia o caminho do arquivo do FDD e a pasta de saída opcional dos argumentos do comando:
- Caminho do arquivo FDD (obrigatório)
- Pasta de saída (opcional, padrão: "docs/mermaid")

Passe a seguinte instrução detalhada para o agente:

"Gere diagramas Mermaid a partir do Documento de Design de Funcionalidade localizado em [FDD_FILE_PATH].

Pasta de saída: [OUTPUT_FOLDER]

O agente executará seu fluxo de trabalho completo (Fases 1-9). Sua tarefa é garantir que o agente receba o caminho do FDD e a pasta de saída corretos.

Requisitos principais que o agente seguirá:

ANÁLISE E SELEÇÃO:
- Leia o FDD completamente (se não estiver em português, traduza o conteúdo ao gerar)
- Extraia elementos explícitos e identifique o que é central para o sucesso do sistema
- Avalie a importância rigorosamente usando 5 critérios (fluxo principal, partes complexas, decisões de arquitetura, contratos públicos, relacionamentos)
- Selecione os tipos de diagramas apropriados (Sequência, Fluxograma TD/LR, Classe, Entidade-Relacionamento)
- Filtre para os diagramas mais valiosos (típico: 6-8, até 10 no máximo se genuinamente justificado)

GERAÇÃO:
- Crie UM arquivo markdown: [OUTPUT_FOLDER]/[feature-name]-diagrams.md
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
Substitua [feature-name] pelo nome da funcionalidade apropriado extraído do nome do arquivo FDD (ex: "ratelimiter" de "ratelimiter-fdd.md").