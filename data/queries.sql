-- =====================================================================
-- Despensa Solidária — queries.sql
-- Consultas relevantes do projeto. Cada consulta indica o objetivo e o
-- requisito (FR) que suporta.
-- =====================================================================

USE despensa_solidaria;

-- Q01 — Stock total por categoria, só de lotes válidos (FR05)
-- JOIN de 3 tabelas + GROUP BY + filtro de validade.
SELECT c.nome                          AS categoria,
       COUNT(DISTINCT l.id_produto)    AS produtos_com_stock,
       SUM(l.quantidade_disponivel)    AS quantidade_total
  FROM lote l
  JOIN produto p   ON p.id_produto   = l.id_produto
  JOIN categoria c ON c.id_categoria = p.id_categoria
 WHERE l.quantidade_disponivel > 0
   AND l.data_validade >= CURRENT_DATE
 GROUP BY c.nome
 ORDER BY quantidade_total DESC;

-- Q02 — Ordem FEFO dos lotes de um produto num armazém (FR08, BR03)
-- É a mesma ordem usada por sp_registar_entrega. Ex.: leite no armazém 1.
SELECT l.id_lote, l.data_validade, l.quantidade_disponivel, dc.data_doacao
  FROM lote l
  JOIN doacao dc ON dc.id_doacao = l.id_doacao
 WHERE l.id_produto = 1
   AND dc.id_armazem = 1
   AND l.quantidade_disponivel > 0
   AND l.data_validade >= CURRENT_DATE
 ORDER BY l.data_validade, l.id_lote;

-- Q03 — Desperdício por categoria e motivo, com percentagem do recebido (FR12)
-- Agregação com subconsulta escalar correlacionada (total recebido por categoria).
SELECT c.nome                             AS categoria,
       d.motivo,
       SUM(d.quantidade)                  AS desperdicado,
       ROUND(100 * SUM(d.quantidade) /
             (SELECT SUM(l2.quantidade_inicial)
                FROM lote l2 JOIN produto p2 ON p2.id_produto = l2.id_produto
               WHERE p2.id_categoria = c.id_categoria), 1) AS pct_do_recebido
  FROM desperdicio d
  JOIN lote l      ON l.id_lote      = d.id_lote
  JOIN produto p   ON p.id_produto   = l.id_produto
  JOIN categoria c ON c.id_categoria = p.id_categoria
 GROUP BY c.id_categoria, c.nome, d.motivo
 ORDER BY desperdicado DESC;

-- Q04 — Distribuição por instituição: entregas, quantidade e produtos (FR12)
-- LEFT JOIN para incluir instituições que ainda não receberam nada;
-- GROUP_CONCAT para listar os produtos recebidos.
SELECT i.nome                                AS instituicao,
       i.num_beneficiarios,
       COUNT(DISTINCT e.id_entrega)          AS num_entregas,
       COALESCE(SUM(le.quantidade), 0)       AS quantidade_recebida,
       GROUP_CONCAT(DISTINCT p.nome ORDER BY p.nome SEPARATOR ', ') AS produtos
  FROM instituicao i
  LEFT JOIN pedido pe        ON pe.id_instituicao = i.id_instituicao
  LEFT JOIN entrega e        ON e.id_pedido       = pe.id_pedido
  LEFT JOIN linha_entrega le ON le.id_entrega     = e.id_entrega
  LEFT JOIN lote l           ON l.id_lote         = le.id_lote
  LEFT JOIN produto p        ON p.id_produto      = l.id_produto
 GROUP BY i.id_instituicao, i.nome, i.num_beneficiarios
 ORDER BY quantidade_recebida DESC;

-- Q05 — Doações por doador: nº de doações, lotes e quantidade (FR12)
-- GROUP BY + HAVING: só doadores com mais de uma doação.
SELECT dr.nome, dr.tipo,
       COUNT(DISTINCT dc.id_doacao)   AS num_doacoes,
       COUNT(l.id_lote)               AS num_lotes,
       SUM(l.quantidade_inicial)      AS quantidade_doada,
       MAX(dc.data_doacao)            AS ultima_doacao
  FROM doador dr
  JOIN doacao dc ON dc.id_doador = dr.id_doador
  JOIN lote l    ON l.id_doacao  = dc.id_doacao
 GROUP BY dr.id_doador, dr.nome, dr.tipo
HAVING COUNT(DISTINCT dc.id_doacao) > 1
 ORDER BY quantidade_doada DESC;

-- Q06 — Doadores registados que nunca doaram (NOT EXISTS)
SELECT dr.id_doador, dr.nome, dr.data_registo
  FROM doador dr
 WHERE NOT EXISTS (SELECT 1 FROM doacao dc WHERE dc.id_doador = dr.id_doador);

-- Q07 — Pedidos com produtos em falta e se há stock para os satisfazer
-- Usa a view vw_pedido_progresso e a função fn_stock_disponivel (FR07, FR08).
SELECT v.id_pedido, v.instituicao, v.estado, v.produto,
       v.quantidade_em_falta,
       fn_stock_disponivel(v.id_produto, NULL) AS stock_disponivel_total
  FROM vw_pedido_progresso v
 WHERE v.estado IN ('pendente', 'parcial')
   AND v.quantidade_em_falta > 0
 ORDER BY v.id_pedido, v.produto;

-- Q08 — Taxa de ocupação dos turnos da semana atual (FR10)
-- LEFT JOIN + agregação + cálculo de percentagem.
SELECT t.id_turno, a.nome AS armazem, t.data_turno, t.hora_inicio, t.hora_fim,
       t.vagas,
       COUNT(it.id_voluntario)                         AS inscritos,
       ROUND(100 * COUNT(it.id_voluntario) / t.vagas)  AS ocupacao_pct
  FROM turno t
  JOIN armazem a              ON a.id_armazem = t.id_armazem
  LEFT JOIN inscricao_turno it ON it.id_turno  = t.id_turno
 WHERE YEARWEEK(t.data_turno, 3) = YEARWEEK(CURRENT_DATE, 3)
 GROUP BY t.id_turno, a.nome, t.data_turno, t.hora_inicio, t.hora_fim, t.vagas
 ORDER BY t.data_turno, t.hora_inicio;

-- Q09 — Voluntários mais ativos: turnos, doações rececionadas e entregas (CTE)
WITH turnos AS (
  SELECT id_voluntario, COUNT(*) AS n FROM inscricao_turno GROUP BY id_voluntario
), rececoes AS (
  SELECT id_voluntario, COUNT(*) AS n FROM doacao
   WHERE id_voluntario IS NOT NULL GROUP BY id_voluntario
), entregas AS (
  SELECT id_voluntario, COUNT(*) AS n FROM entrega GROUP BY id_voluntario
)
SELECT v.nome,
       COALESCE(t.n, 0) AS turnos,
       COALESCE(r.n, 0) AS doacoes_rececionadas,
       COALESCE(e.n, 0) AS entregas,
       COALESCE(t.n, 0) + COALESCE(r.n, 0) + COALESCE(e.n, 0) AS total_atividades
  FROM voluntario v
  LEFT JOIN turnos t   ON t.id_voluntario = v.id_voluntario
  LEFT JOIN rececoes r ON r.id_voluntario = v.id_voluntario
  LEFT JOIN entregas e ON e.id_voluntario = v.id_voluntario
 WHERE v.ativo
 ORDER BY total_atividades DESC, v.nome;

-- Q10 — Rastreabilidade: de que doadores veio o que uma instituição recebeu
-- JOIN de 7 tabelas, da instituição até ao doador original (pedido 3).
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

-- Q11 — Produtos cujo stock total é inferior ao pedido médio desse produto
-- Tabela derivada com a média por produto (necessidade de reposição).
SELECT p.nome AS produto,
       fn_stock_disponivel(p.id_produto, NULL) AS stock_atual,
       ROUND(m.media_pedida, 2)                AS media_pedida
  FROM produto p
  JOIN (SELECT id_produto, AVG(quantidade_pedida) AS media_pedida
          FROM linha_pedido GROUP BY id_produto) m ON m.id_produto = p.id_produto
 WHERE fn_stock_disponivel(p.id_produto, NULL) < m.media_pedida
 ORDER BY stock_atual;

-- Q12 — Maior lote válido de cada produto (subconsulta correlacionada com ALL)
SELECT p.nome AS produto, l.id_lote, l.quantidade_disponivel, l.data_validade
  FROM lote l
  JOIN produto p ON p.id_produto = l.id_produto
 WHERE l.quantidade_disponivel > 0
   AND l.data_validade >= CURRENT_DATE
   AND l.quantidade_disponivel >= ALL (SELECT l2.quantidade_disponivel
                                         FROM lote l2
                                        WHERE l2.id_produto = l.id_produto
                                          AND l2.data_validade >= CURRENT_DATE)
 ORDER BY p.nome;

-- Q13 — Evolução mensal: entradas (doado) vs. saídas (entregue) vs. desperdício
-- UNION ALL de três origens + agregação por mês.
SELECT mes,
       SUM(entradas)    AS entradas,
       SUM(saidas)      AS saidas,
       SUM(desperdicio) AS desperdicio
  FROM (SELECT DATE_FORMAT(dc.data_doacao, '%Y-%m') AS mes, l.quantidade_inicial AS entradas, 0 AS saidas, 0 AS desperdicio
          FROM lote l JOIN doacao dc ON dc.id_doacao = l.id_doacao
        UNION ALL
        SELECT DATE_FORMAT(e.data_entrega, '%Y-%m'), 0, le.quantidade, 0
          FROM linha_entrega le JOIN entrega e ON e.id_entrega = le.id_entrega
        UNION ALL
        SELECT DATE_FORMAT(data_registo, '%Y-%m'), 0, 0, quantidade
          FROM desperdicio) mov
 GROUP BY mes
 ORDER BY mes;

-- Q14 — Plano de execução da consulta FEFO (uso do índice idx_lote_produto_validade)
EXPLAIN
SELECT l.id_lote
  FROM lote l
 WHERE l.id_produto = 1 AND l.quantidade_disponivel > 0
 ORDER BY l.data_validade;
