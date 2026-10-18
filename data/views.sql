-- =====================================================================
-- Despensa Solidária — views.sql
-- Vistas reutilizadas pelo protótipo e pelos relatórios.
-- =====================================================================

USE despensa_solidaria;

-- ---------------------------------------------------------------------
-- V01 — Stock disponível por produto e armazém (FR05)
-- Só conta lotes não expirados com quantidade > 0. O stock não é guardado
-- numa tabela: é sempre calculado a partir dos lotes (fonte única).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_stock_disponivel AS
SELECT a.id_armazem,
       a.nome                       AS armazem,
       c.nome                       AS categoria,
       p.id_produto,
       p.nome                       AS produto,
       p.unidade_medida,
       SUM(l.quantidade_disponivel) AS quantidade,
       COUNT(*)                     AS num_lotes,
       MIN(l.data_validade)         AS proxima_validade
  FROM lote l
  JOIN doacao d    ON d.id_doacao    = l.id_doacao
  JOIN armazem a   ON a.id_armazem   = d.id_armazem
  JOIN produto p   ON p.id_produto   = l.id_produto
  JOIN categoria c ON c.id_categoria = p.id_categoria
 WHERE l.quantidade_disponivel > 0
   AND l.data_validade >= CURRENT_DATE
 GROUP BY a.id_armazem, a.nome, c.nome, p.id_produto, p.nome, p.unidade_medida;

-- ---------------------------------------------------------------------
-- V02 — Lotes com stock que expiram nos próximos 7 dias (FR11)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_lotes_a_expirar AS
SELECT l.id_lote,
       p.nome                                     AS produto,
       c.nome                                     AS categoria,
       a.nome                                     AS armazem,
       l.quantidade_disponivel,
       p.unidade_medida,
       l.data_validade,
       DATEDIFF(l.data_validade, CURRENT_DATE)    AS dias_restantes
  FROM lote l
  JOIN produto p   ON p.id_produto   = l.id_produto
  JOIN categoria c ON c.id_categoria = p.id_categoria
  JOIN doacao d    ON d.id_doacao    = l.id_doacao
  JOIN armazem a   ON a.id_armazem   = d.id_armazem
 WHERE l.quantidade_disponivel > 0
   AND l.data_validade BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL 7 DAY;

-- ---------------------------------------------------------------------
-- V03 — Lotes expirados que ainda têm stock (por abater como desperdício)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_lotes_expirados AS
SELECT l.id_lote,
       p.nome                                  AS produto,
       a.nome                                  AS armazem,
       l.quantidade_disponivel,
       p.unidade_medida,
       l.data_validade,
       DATEDIFF(CURRENT_DATE, l.data_validade) AS dias_expirado
  FROM lote l
  JOIN produto p ON p.id_produto = l.id_produto
  JOIN doacao d  ON d.id_doacao  = l.id_doacao
  JOIN armazem a ON a.id_armazem = d.id_armazem
 WHERE l.quantidade_disponivel > 0
   AND l.data_validade < CURRENT_DATE;

-- ---------------------------------------------------------------------
-- V04 — Estado de cada linha de pedido: pedido vs. entregue (FR07, FR08)
-- Subconsulta agregada em LEFT JOIN para incluir linhas sem entregas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_pedido_progresso AS
SELECT pe.id_pedido,
       i.nome                                       AS instituicao,
       pe.data_pedido,
       pe.estado,
       p.id_produto,
       p.nome                                       AS produto,
       p.unidade_medida,
       lp.quantidade_pedida,
       COALESCE(ent.entregue, 0)                    AS quantidade_entregue,
       lp.quantidade_pedida - COALESCE(ent.entregue, 0) AS quantidade_em_falta
  FROM pedido pe
  JOIN instituicao i   ON i.id_instituicao = pe.id_instituicao
  JOIN linha_pedido lp ON lp.id_pedido     = pe.id_pedido
  JOIN produto p       ON p.id_produto     = lp.id_produto
  LEFT JOIN (SELECT e.id_pedido, l.id_produto, SUM(le.quantidade) AS entregue
               FROM linha_entrega le
               JOIN entrega e ON e.id_entrega = le.id_entrega
               JOIN lote l    ON l.id_lote    = le.id_lote
              GROUP BY e.id_pedido, l.id_produto) ent
         ON ent.id_pedido = pe.id_pedido AND ent.id_produto = lp.id_produto;
