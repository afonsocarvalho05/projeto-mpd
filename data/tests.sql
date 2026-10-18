-- =====================================================================
-- Despensa Solidária — tests.sql
-- Testes positivos (POS) e negativos (NEG) de integridade e regras.
-- Executar sobre uma base acabada de criar (schema → programmable_objects
-- → views → seed), com --force para continuar após os erros esperados:
--   mysql -u <user> -p --force -t -v despensa_solidaria < data/tests.sql
-- Cada teste NEG deve terminar com o erro indicado em "Esperado".
-- Os testes alteram os dados: voltar a correr o seed para repor.
-- =====================================================================

USE despensa_solidaria;

-- ---------------------------------------------------------------------
-- Integridade declarativa (PK, FK, UNIQUE, CHECK)
-- ---------------------------------------------------------------------

-- T01 [NEG] BR11 — NIF de doador duplicado. Esperado: ERROR 1062 (uq_doador_nif)
INSERT INTO doador (tipo, nome, nif) VALUES ('empresa', 'Empresa Repetida', '501234560');

-- T02 [NEG] CHECK — NIF de instituição com formato inválido. Esperado: ERROR 3819 (ck_instituicao_nif)
INSERT INTO instituicao (nome, nif, tipo, morada, localidade) VALUES ('Teste', '12345', 'IPSS', 'Rua X', 'Aveiro');

-- T03 [NEG] CHECK — empresa sem NIF. Esperado: ERROR 3819 (ck_doador_empresa_nif)
INSERT INTO doador (tipo, nome, nif) VALUES ('empresa', 'Empresa Sem NIF', NULL);

-- T04 [NEG] BR05 — lote com quantidade zero. Esperado: ERROR 3819 (ck_lote_qtd_inicial)
INSERT INTO lote (id_doacao, id_produto, quantidade_inicial, quantidade_disponivel, data_validade)
VALUES (15, 1, 0, 0, CURRENT_DATE + INTERVAL 30 DAY);

-- T05 [NEG] CHECK — turno que acaba antes de começar. Esperado: ERROR 3819 (ck_turno_horas)
INSERT INTO turno (id_armazem, data_turno, hora_inicio, hora_fim, vagas)
VALUES (1, CURRENT_DATE + INTERVAL 20 DAY, '18:00', '14:00', 2);

-- T06 [NEG] FK — produto com categoria inexistente. Esperado: ERROR 1452
INSERT INTO produto (id_categoria, nome, unidade_medida) VALUES (99, 'Produto órfão', 'un');

-- T07 [NEG] FK RESTRICT — apagar categoria com produtos. Esperado: ERROR 1451
DELETE FROM categoria WHERE id_categoria = 1;

-- T08 [NEG] PK composta — voluntário inscrito duas vezes no mesmo turno. Esperado: ERROR 1062
INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES (4, 3);

-- ---------------------------------------------------------------------
-- Regras de negócio em triggers
-- ---------------------------------------------------------------------

-- T09 [NEG] BR09 — lote com validade anterior à data da doação. Esperado: ERROR 1644 'BR09: ...'
INSERT INTO lote (id_doacao, id_produto, quantidade_inicial, quantidade_disponivel, data_validade)
VALUES (15, 1, 10, 10, CURRENT_DATE - INTERVAL 10 DAY);

-- T10 [NEG] BR12 — pedido de instituição suspensa. Esperado: ERROR 1644 'BR12: ...'
INSERT INTO pedido (id_instituicao, data_pedido) VALUES (6, CURRENT_DATE);

-- T11 [NEG] BR06 — inscrição num turno sem vagas (turno 1: 3/3). Esperado: ERROR 1644 'BR06: ...'
INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES (7, 1);

-- T12 [NEG] BR04 — 4.º turno na mesma semana (Beatriz já tem 3). Esperado: ERROR 1644 'BR04: ...'
INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES (3, 4);

-- T13 [NEG] voluntário inativo não se inscreve. Esperado: ERROR 1644 'O voluntário está inativo.'
INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES (10, 9);

-- Entregas "manuais" (sem o procedimento) para testar o trigger de linha_entrega.
INSERT INTO entrega (id_pedido, id_armazem, id_voluntario, data_entrega) VALUES (5, 1, 3, CURRENT_DATE);
SET @e5 = LAST_INSERT_ID();
INSERT INTO entrega (id_pedido, id_armazem, id_voluntario, data_entrega) VALUES (6, 1, 3, CURRENT_DATE);
SET @e6 = LAST_INSERT_ID();

-- T14 [NEG] BR01 — entregar um lote expirado (lote 6, iogurte). Esperado: ERROR 1644 'BR01: ...'
INSERT INTO linha_entrega (id_entrega, id_lote, quantidade) VALUES (@e5, 6, 10);

-- T15 [NEG] BR08 — lote de outro armazém (lote 26 está em Ílhavo). Esperado: ERROR 1644 'BR08: ...'
INSERT INTO linha_entrega (id_entrega, id_lote, quantidade) VALUES (@e6, 26, 10);

-- T16 [NEG] BR02 — retirar mais do que o disponível (lote 30 tem 150). Esperado: ERROR 1644 'BR02: ...'
INSERT INTO linha_entrega (id_entrega, id_lote, quantidade) VALUES (@e6, 30, 155);

-- T17 [NEG] BR07 — produto que não consta do pedido (água no pedido 5). Esperado: ERROR 1644 'BR07: ...'
INSERT INTO linha_entrega (id_entrega, id_lote, quantidade) VALUES (@e5, 20, 10);

-- T18 [NEG] BR07 — entregar mais do que o pedido (pedido 6 pede 60 l de leite). Esperado: ERROR 1644 'BR07: ...'
INSERT INTO linha_entrega (id_entrega, id_lote, quantidade) VALUES (@e6, 1, 70);

-- T19 [NEG] BR03 — saltar a ordem FEFO (lote 30 expira depois do lote 1). Esperado: ERROR 1644 'BR03: ...'
INSERT INTO linha_entrega (id_entrega, id_lote, quantidade) VALUES (@e6, 30, 10);

-- Limpeza: as entregas manuais ficaram sem linhas e podem ser removidas.
DELETE FROM entrega WHERE id_entrega IN (@e5, @e6);

-- T20 [NEG] histórico — apagar uma linha de entrega. Esperado: ERROR 1644 'Linhas de entrega não podem ser apagadas ...'
DELETE FROM linha_entrega WHERE id_entrega = 1 LIMIT 1;

-- T21 [NEG] BR02 — desperdiçar mais do que o lote tem (lote 34: 15 kg). Esperado: ERROR 1644 'BR02: ...'
INSERT INTO desperdicio (id_lote, id_voluntario, data_registo, quantidade, motivo) VALUES (34, 8, CURRENT_DATE, 20, 'danificado');

-- ---------------------------------------------------------------------
-- Procedimentos e transações
-- ---------------------------------------------------------------------

-- T22 [NEG] entrega de um pedido já concluído. Esperado: ERROR 1644 'Só pedidos pendentes ou parciais ...'
CALL sp_registar_entrega(1, 1, 3, CURRENT_DATE, @x);

-- T23 [NEG] ROLLBACK — pedido de sal (só há sal em Ovar) entregue a partir de Ílhavo.
-- Esperado: ERROR 1644 'BR02: não há stock ...' e NENHUMA entrega nova gravada.
INSERT INTO pedido (id_instituicao, data_pedido) VALUES (3, CURRENT_DATE);
SET @p_sal = LAST_INSERT_ID();
INSERT INTO linha_pedido (id_pedido, id_produto, quantidade_pedida) VALUES (@p_sal, 18, 5);
SELECT COUNT(*) AS entregas_antes FROM entrega;
CALL sp_registar_entrega(@p_sal, 2, 5, CURRENT_DATE, @x);
SELECT COUNT(*) AS entregas_depois_igual_a_antes FROM entrega;

-- T24 [POS] BR05/BR09 — doação válida: o lote nasce com disponível = inicial.
INSERT INTO lote (id_doacao, id_produto, quantidade_inicial, quantidade_disponivel, data_validade)
VALUES (15, 20, 25, 0, CURRENT_DATE + INTERVAL 90 DAY);
SELECT id_lote, quantidade_inicial, quantidade_disponivel AS disponivel_esperado_25
  FROM lote WHERE id_lote = LAST_INSERT_ID();

-- T25 [POS] FR08/BR03 — entrega FEFO do pedido 5 (iogurte, maçã, queijo) a partir do armazém 1.
-- Esperado: usa os lotes a expirar 35 (iogurte), 24 (maçã) e 7 (queijo); pedido fica 'concluido'.
CALL sp_registar_entrega(5, 1, 3, CURRENT_DATE, @e);
SELECT le.id_lote, p.nome AS produto, le.quantidade, l.data_validade, l.quantidade_disponivel AS resta_no_lote
  FROM linha_entrega le JOIN lote l ON l.id_lote = le.id_lote JOIN produto p ON p.id_produto = l.id_produto
 WHERE le.id_entrega = @e;
SELECT estado AS estado_esperado_concluido FROM pedido WHERE id_pedido = 5;

-- T26 [POS] BR10 — abate de expirados: lotes 4 e 6 (iogurte) passam a desperdício e ficam a 0.
CALL sp_processar_expirados(CURRENT_DATE, @n);
SELECT @n AS lotes_abatidos_esperado_2;
SELECT id_lote, quantidade_disponivel FROM lote WHERE id_lote IN (4, 6);

-- T27 [POS] BR04/BR06 — inscrição válida (Gonçalo no turno 2, com vagas).
INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES (8, 2);
SELECT COUNT(*) AS inscritos_turno_2 FROM inscricao_turno WHERE id_turno = 2;

-- T28 [POS] função — stock válido de leite por armazém e total.
SELECT fn_stock_disponivel(1, 1) AS leite_aveiro, fn_stock_disponivel(1, 2) AS leite_ilhavo,
       fn_stock_disponivel(1, NULL) AS leite_total;
