# AI Use Summary

## Tools used
- **Claude Code** (Anthropic, modelo Claude Opus 5.5), na aplicação desktop, com acesso à pasta do projeto, ao MySQL local e a um browser para testar o protótipo.
- Contexto fornecido em todas as fases: enunciado (`01_Guia_do_Projeto_BD_IA.docx`), rubrica, exemplo ConferenceFlow, template de artefactos e o livro da UC (*Curso Prático de Programação de Banco de Dados*), além dos artefactos já validados de cada fase.

Método seguido: cada artefacto gerado foi **executado ou verificado** antes de servir de contexto à fase seguinte (SQL corrido no MySQL 8.0.46, testes em `data/tests.sql`, protótipo usado no browser).

> **A completar pelo grupo:** acrescentar, em cada caso, quem do grupo reviu e o que verificou pessoalmente; e acrescentar casos próprios se algum colega tiver usado IA (ChatGPT, etc.) noutras partes.

## AI-01 — Definição do tema e dos requisitos
**Tool:** Claude Code
**Input artefacts:** enunciado, rubrica, exemplo ConferenceFlow, template.
**Task requested:** propor temas com complexidade suficiente e redigir `project-brief.md`, `requirements.md` e `business-rules.md`.
**Relevant output:** primeira versão para "Aeronáutica em Aveiro" (escola de aviação); depois, para o tema escolhido pelo grupo (banco alimentar), 12 FR e 12 BR.
**Human validation:** o grupo comparou as propostas e escolheu outro tema (banco alimentar e gestão de doações), mais rico em regras de base de dados; os rascunhos de aviação foram descartados sem entrar no repositório.
**Problem / limitation found:** a IA propôs inicialmente o tema "mais simples de executar", que não era o mais forte para o critério de modelação (35%). O nome "Banco Alimentar" coincidia com uma organização real.
**Correction / decision:** tema alterado pelo grupo; IPSS renomeada para "Despensa Solidária" (fictícia) para não se confundir com uma entidade real.
**Final result:** brief, FR01–FR12 e BR01–BR12 no commit "Tema: banco alimentar".
**Evidence:** histórico de commits do repositório.

## AI-02 — Modelação: onde fica o armazém de um lote
**Tool:** Claude Code
**Input artefacts:** `project-brief.md`, `requirements.md`, `business-rules.md`.
**Task requested:** derivar o modelo relacional (ERD, tabelas, cardinalidades) a partir dos artefactos validados.
**Relevant output:** o brief inicial dizia "cada lote tem um único armazém", o que levaria a uma coluna `lote.id_armazem`.
**Human validation:** análise de dependências funcionais: `id_lote → id_doacao → id_armazem`. Guardar também `lote.id_armazem` cria uma dependência transitiva (viola a 3FN) e permite um lote num armazém diferente do da doação.
**Problem / limitation found:** a suposição do brief estava certa no domínio mas errada como estrutura de tabela.
**Correction / decision:** o armazém fica só na `doacao`; o lote obtém-no por junção. O brief passou a dizer explicitamente que não há transferências entre armazéns (exclusão de âmbito) e BR05 foi reescrita.
**Final result:** `data/schema.sql` (tabela `lote` sem armazém); justificação em `documentation/diagrams/ERD.md`.
**Evidence:** commits "Base de dados…" e "Modelação: ERD, dicionário…".

## AI-03 — Implementação: entrega FEFO com lotes ainda não recebidos
**Tool:** Claude Code
**Input artefacts:** ERD, `schema.sql`, BR01–BR03, BR07, BR08, livro da UC (transações, chaves estrangeiras em MySQL).
**Task requested:** implementar a entrega FEFO como procedimento transacional e os triggers que validam cada linha de entrega.
**Relevant output:** `sp_registar_entrega` (ciclo FEFO com `START TRANSACTION`/`ROLLBACK`) e `trg_linha_entrega_bi`.
**Human validation:** execução do seed com entregas em datas passadas e consulta da tabela `linha_entrega`.
**Problem / limitation found:** (1) a primeira versão escolhia lotes por validade sem verificar se já tinham sido recebidos: numa entrega com data passada podia usar um lote doado depois dessa data. (2) Ao criar os triggers, o MySQL recusou com o erro 1419 (binary log ativo, utilizador sem SUPER). (3) Abater expirados com `INSERT … SELECT FROM lote` daria o erro 1442 (o trigger de desperdício atualiza `lote`).
**Correction / decision:** (1) acrescentada a condição `data_doacao <= data_entrega` no procedimento e no trigger, e BR08 atualizada; (2) `log_bin_trust_function_creators = 1`, documentado no README; (3) `sp_processar_expirados` passou a usar um ciclo.
**Final result:** 28 testes (23 negativos, 5 positivos) passam, incluindo o ROLLBACK de uma entrega sem stock (T23).
**Evidence:** `data/tests.sql`, `documentation/test-results.txt`.

## AI-04 — Protótipo: verificação no browser
**Tool:** Claude Code (com browser integrado)
**Input artefacts:** `technical-stack.md`, mockups UI01–UI04, views e procedimentos da BD.
**Task requested:** gerar o protótipo Flask a partir dos mockups e testá-lo ponta a ponta.
**Relevant output:** aplicação em `application/` com 10 ecrãs.
**Human validation:** login com os utilizadores de demonstração, entrega FEFO do pedido #5, envio de dados inválidos em cada formulário e confirmação de que a mensagem da regra (BR02, BR04, BR09, BR12, CHECK, UNIQUE) chega ao utilizador; acesso de um voluntário a uma página de coordenador.
**Problem / limitation found:** o cartão de login não ficava centrado (especificidade CSS) e os dias da semana dos turnos apareciam em inglês ("Mon", "Tue").
**Correction / decision:** CSS corrigido; dias da semana traduzidos no template. As regras de negócio **não** foram replicadas em Python, para que a base de dados continue a ser a única fonte das regras.
**Final result:** capturas em `documentation/screenshots/`.
**Evidence:** `documentation/screenshots/05-pedido-depois-entrega-fefo.jpg`, `06-turnos-erro-br04.jpg`.
