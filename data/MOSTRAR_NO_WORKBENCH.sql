-- =====================================================================
-- Despensa Solidária — o que mostrar no MySQL Workbench se o professor pedir
-- Como usar: clicar dentro de um bloco e carregar Ctrl+Enter
-- (corre só esse comando; o resultado aparece em baixo).
-- =====================================================================

USE despensa_solidaria;
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. "Mostrem os dados" — conteúdo das tabelas principais
-- ---------------------------------------------------------------------
SELECT * FROM lote;            -- 44 lotes: produto, quantidade inicial/disponível, validade
SELECT * FROM doacao;          -- 15 doações
SELECT * FROM pedido;          -- 7 pedidos (concluídos, parcial, pendentes, cancelado)
SELECT * FROM instituicao;     -- 6 instituições (uma suspensa)
SELECT * FROM voluntario;      -- 10 voluntários (2 coordenadores, 1 inativo)

-- ---------------------------------------------------------------------
-- 2. "Quantos registos há em cada tabela?"
-- ---------------------------------------------------------------------
SELECT 'categoria' AS tabela, COUNT(*) AS linhas FROM categoria
UNION ALL SELECT 'produto', COUNT(*) FROM produto
UNION ALL SELECT 'armazem', COUNT(*) FROM armazem
UNION ALL SELECT 'doador', COUNT(*) FROM doador
UNION ALL SELECT 'doacao', COUNT(*) FROM doacao
UNION ALL SELECT 'lote', COUNT(*) FROM lote
UNION ALL SELECT 'instituicao', COUNT(*) FROM instituicao
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'linha_pedido', COUNT(*) FROM linha_pedido
UNION ALL SELECT 'entrega', COUNT(*) FROM entrega
UNION ALL SELECT 'linha_entrega', COUNT(*) FROM linha_entrega
UNION ALL SELECT 'desperdicio', COUNT(*) FROM desperdicio
UNION ALL SELECT 'voluntario', COUNT(*) FROM voluntario
UNION ALL SELECT 'turno', COUNT(*) FROM turno
UNION ALL SELECT 'inscricao_turno', COUNT(*) FROM inscricao_turno;

-- ---------------------------------------------------------------------
-- 3. "Mostrem o código que criou uma tabela" (PK, FK, CHECK)
--    No resultado: clicar com o botão direito na célula → Open Value in Viewer
-- ---------------------------------------------------------------------
SHOW CREATE TABLE lote;
SHOW CREATE TABLE linha_entrega;

-- ---------------------------------------------------------------------
-- 4. "Mostrem os triggers / procedimentos / views"
-- ---------------------------------------------------------------------
SHOW TRIGGERS FROM despensa_solidaria;                         -- os 10 triggers
SHOW PROCEDURE STATUS WHERE Db = 'despensa_solidaria';         -- sp_registar_entrega, sp_processar_expirados
SHOW FUNCTION STATUS WHERE Db = 'despensa_solidaria';          -- fn_stock_disponivel
SHOW CREATE PROCEDURE sp_registar_entrega;                     -- código da entrega FEFO (transação)
SHOW CREATE TRIGGER trg_linha_entrega_bi;                      -- validação BR01, BR02, BR03, BR07, BR08

-- ---------------------------------------------------------------------
-- 5. "Mostrem as views a funcionar"
-- ---------------------------------------------------------------------
SELECT * FROM vw_stock_disponivel ORDER BY armazem, produto;  -- stock calculado a partir dos lotes
SELECT * FROM vw_lotes_a_expirar ORDER BY data_validade;      -- alertas dos próximos 7 dias
SELECT * FROM vw_pedido_progresso WHERE id_pedido = 3;        -- pedido parcial: pedido vs entregue

-- ---------------------------------------------------------------------
-- 6. "Mostrem uma regra a funcionar" — deve dar ERRO (é o objetivo)
-- ---------------------------------------------------------------------
-- BR09: lote com validade anterior à data da doação → ERROR 1644
INSERT INTO lote (id_doacao, id_produto, quantidade_inicial, quantidade_disponivel, data_validade)
VALUES (15, 1, 10, 10, CURRENT_DATE - INTERVAL 10 DAY);

-- BR12: pedido de uma instituição suspensa → ERROR 1644
INSERT INTO pedido (id_instituicao, data_pedido) VALUES (6, CURRENT_DATE);

-- ---------------------------------------------------------------------
-- 7. "Mostrem uma consulta" — rastreabilidade: da instituição ao doador (8 tabelas)
-- ---------------------------------------------------------------------
SELECT i.nome AS instituicao, e.data_entrega, p.nome AS produto, le.quantidade,
       l.id_lote, l.data_validade, dr.nome AS doador_original, dc.data_doacao
  FROM entrega e
  JOIN pedido pe        ON pe.id_pedido      = e.id_pedido
  JOIN instituicao i    ON i.id_instituicao  = pe.id_instituicao
  JOIN linha_entrega le ON le.id_entrega     = e.id_entrega
  JOIN lote l           ON l.id_lote         = le.id_lote
  JOIN produto p        ON p.id_produto      = l.id_produto
  JOIN doacao dc        ON dc.id_doacao      = l.id_doacao
  JOIN doador dr        ON dr.id_doador      = dc.id_doador
 WHERE pe.id_pedido = 3
 ORDER BY p.nome, l.data_validade;
