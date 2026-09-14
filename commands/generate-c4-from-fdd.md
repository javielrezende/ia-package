---
description: |
    Gere C4 diagrams a partir de um Feature Design Document (FDD). Usage: /generate-c4-from-fdd <path-to-fdd.md> [output-folder] [--no-images]
---

Extraia o file path do FDD, o output folder opcional e a flag opcional --no-images dos argumentos do comando:
- File path do FDD (obrigatório)
- Output folder (opcional, default: "docs/c4")
- Flag --no-images (opcional, se presente: pule a geração de PNG; se ausente: gere imagens PNG por default)

IMPORTANTE: Antes de prosseguir, valide se o file path do FDD fornecido existe e é acessível. Caso não seja, faça um Early Return informando o erro ao usuário para evitar o consumo de recursos desnecessários.

Se a validação passar, você DEVE invocar o agent c4-diagram-generator usando a Task tool com subagent_type="c4-diagram-generator".

Passe o seguinte prompt para o agent:

"Gere C4 diagrams para a feature [feature-name] a partir do Feature Design Document localizado em [FDD_FILE_PATH].

Output folder: [OUTPUT_FOLDER]
Geração de PNG: [PNG_INSTRUCTION]

Execute o seu workflow completo (Fases 1-6) seguindo todas as guidelines internas.

LEMBRETES CRÍTICOS:
- Crie arquivos .puml separados usando a Write tool para CADA diagram (c1, c2, c3, c4) - isso é OBRIGATÓRIO
- Crie UM arquivo .md APENAS com a análise (NENHUM código PlantUML dentro)
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
Substitua [feature-name] pelo nome da feature apropriado extraído do filename do FDD.

Substitua [PNG_INSTRUCTION] e [PNG_BEHAVIOR] com base na flag --no-images:

Se a flag --no-images ESTIVER presente:
- [PNG_INSTRUCTION] = "DISABLED"
- [PNG_BEHAVIOR] = "Pule a geração de PNG (Fase 5.6) inteiramente"

Se a flag --no-images NÃO ESTIVER presente (default):
- [PNG_INSTRUCTION] = "ENABLED"
- [PNG_BEHAVIOR] = "Execute a Fase 5.6: Gere imagens PNG com correção automática de erros (máx 3 tentativas por file)"