---
description: |
    Gere C4 diagrams a partir de um Feature Design Document (FDD). Usage: /generate-c4-from-fdd <path-to-fdd.md> [output-folder] [--no-images]
---

Extraia o file path do FDD, o output folder opcional e a flag opcional --no-images dos argumentos do comando:
- File path do FDD (obrigatório)
- Output folder (opcional, default: "docs/c4")
- Flag --no-images (opcional, se presente: pule a geração de PNG; se ausente: gere imagens PNG por default)

IMPORTANTE: Antes de prosseguir, valide se o file path do FDD fornecido existe e é acessível. Caso não seja, faça um Early Return informando o erro ao usuário para evitar o consumo de recursos desnecessários.

NOME BASE DOS ARQUIVOS: resolva-o a partir do path do FDD. A primeira linha que casar vale:

| FDD recebido | Nome base |
|---|---|
| `FDD.md` ou `FDD-*.md` dentro de uma pasta de feature `F<ID>-<slug>/` — `docs/F03-video-upload/FDD.md`, `docs/F03-video-upload/FDD-2026-09-19.md` | o nome da pasta: `F03-video-upload` |
| `FDD.md` ou `FDD-<AAAA-MM-DD>.md` fora de pasta de feature — `docs/FDD.md`, `docs/FDD-2026-09-19.md` | nenhum: o nome não identifica a feature. Pergunte ao usuário, sugerindo o nome da feature do título do FDD em minúsculas, sem acento e com hifens |
| `FDD-<slug>.md` fora de pasta de feature — `docs/FDD-upload-de-video.md` | o `<slug>`: `upload-de-video` |
| qualquer outro nome — `ratelimiter-fdd.md` | o nome do arquivo sem a extensão e sem o sufixo `-fdd`: `ratelimiter` |

Nunca derive o nome base de um arquivo chamado `FDD.md` ou `FDD-<data>.md`: no layout por feature todo FDD se chama assim, e a segunda feature sobrescreveria os diagramas da primeira.

ANTES DE DESPACHAR: se algum de `<output folder>/<nome>-c[1-4].puml` ou `<output folder>/<nome>-c4.md` já existir, não invoque o agent ainda. Liste os arquivos encontrados e pergunte ao usuário:
- **sobrescrever** — apague antes o conjunto antigo (`<nome>-c[1-4].puml`, `<nome>-c[1-4].png` e `<nome>-c4.md`), para que um nível que desta vez saia SKIPPED não deixe o diagrama antigo no lugar;
- **gravar com data** — o nome base passa a ser `<nome>-<AAAA-MM-DD>`, com a data de hoje;
- **cancelar** — encerre sem invocar o agent.

Só prossiga depois da resposta.

Você DEVE invocar o agent c4-diagram-generator usando a Agent tool com subagent_type="c4-diagram-generator".

Passe o seguinte prompt para o agent:

"Gere C4 diagrams para a feature [NOME_BASE] a partir do Feature Design Document localizado em [FDD_FILE_PATH].

Output folder: [OUTPUT_FOLDER]
Nome base dos arquivos: [NOME_BASE]
Geração de PNG: [PNG_INSTRUCTION]

Execute o seu workflow completo (Fases 1-6) seguindo todas as guidelines internas.

LEMBRETES CRÍTICOS:
- Crie arquivos .puml separados usando a Write tool para CADA diagram (c1, c2, c3, c4) - isso é OBRIGATÓRIO
- Crie UM arquivo .md APENAS com a análise (NENHUM código PlantUML dentro)
- Use o nome base literalmente em todos os arquivos ([NOME_BASE]-c1.puml ... [NOME_BASE]-c4.puml, [NOME_BASE]-c4.md) - nunca o derive do nome do arquivo do FDD
- Gere diagrams apenas com informação suficiente do FDD - nunca fabrique dados
- Escreva diagrams e o arquivo .md em português (pt-BR), mantendo os termos técnicos em inglês
- [PNG_BEHAVIOR]

O REPORT deve incluir:
- Idioma do FDD e confirmação de que a saída está em pt-BR
- Lista explícita de TODOS os arquivos criados (.puml, .md e .png, se aplicável)
- Número de diagrams gerados com breve justificativa
- Diagrams pulados (skipped) com razões específicas
- Verificação: 'Created N .puml files for N diagrams'
- Resultados da geração de PNG (se aplicável)"

Substitua [FDD_FILE_PATH] pelo file path real dos argumentos do comando.
Substitua [OUTPUT_FOLDER] pelo output folder especificado ou "docs/c4" se não for fornecido.
Substitua [NOME_BASE] pelo nome base resolvido acima (já com a data, se o usuário escolheu gravar com data).

Substitua [PNG_INSTRUCTION] e [PNG_BEHAVIOR] com base na flag --no-images:

Se a flag --no-images ESTIVER presente:
- [PNG_INSTRUCTION] = "DISABLED"
- [PNG_BEHAVIOR] = "Pule a geração de PNG (Fase 5.6) inteiramente"

Se a flag --no-images NÃO ESTIVER presente (default):
- [PNG_INSTRUCTION] = "ENABLED"
- [PNG_BEHAVIOR] = "Execute a Fase 5.6: Gere imagens PNG com correção automática de erros (máx 3 tentativas por file)"