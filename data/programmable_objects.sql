-- =====================================================================
-- Despensa Solidária — programmable_objects.sql
-- Triggers, procedimentos e funções que garantem as regras de negócio
-- que envolvem mais do que uma linha/tabela (não exprimíveis com CHECK).
-- Executar depois de schema.sql e antes de seed.sql.
--
-- Erros de regra de negócio: SIGNAL SQLSTATE '45000' com mensagem "BRxx: ...".
-- Nota MySQL: um trigger não pode alterar a tabela que o disparou, por
-- isso o stock (lote) é atualizado por triggers de linha_entrega e de
-- desperdicio, e os ciclos sobre lotes são feitos em procedimentos.
-- =====================================================================

USE despensa_solidaria;

DROP TRIGGER   IF EXISTS trg_lote_bi;
DROP TRIGGER   IF EXISTS trg_lote_bu;
DROP TRIGGER   IF EXISTS trg_pedido_bi;
DROP TRIGGER   IF EXISTS trg_linha_entrega_bi;
DROP TRIGGER   IF EXISTS trg_linha_entrega_ai;
DROP TRIGGER   IF EXISTS trg_linha_entrega_bu;
DROP TRIGGER   IF EXISTS trg_linha_entrega_bd;
DROP TRIGGER   IF EXISTS trg_desperdicio_bi;
DROP TRIGGER   IF EXISTS trg_desperdicio_ai;
DROP TRIGGER   IF EXISTS trg_inscricao_turno_bi;
DROP PROCEDURE IF EXISTS sp_registar_entrega;
DROP PROCEDURE IF EXISTS sp_processar_expirados;
DROP FUNCTION  IF EXISTS fn_stock_disponivel;

DELIMITER $$

-- ---------------------------------------------------------------------
-- LOTE
-- ---------------------------------------------------------------------

-- BR09: não entram produtos já expirados. Todo o lote novo começa com a
-- quantidade disponível igual à inicial (o stock só desce por movimentos).
CREATE TRIGGER trg_lote_bi
BEFORE INSERT ON lote
FOR EACH ROW
BEGIN
  DECLARE v_data_doacao DATE;

  SELECT data_doacao INTO v_data_doacao
    FROM doacao WHERE id_doacao = NEW.id_doacao;

  IF NEW.data_validade <= v_data_doacao THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR09: a validade do lote tem de ser posterior à data da doação.';
  END IF;

  SET NEW.quantidade_disponivel = NEW.quantidade_inicial;
END$$

-- A origem e o produto de um lote não mudam depois de criado (rastreabilidade, BR05).
CREATE TRIGGER trg_lote_bu
BEFORE UPDATE ON lote
FOR EACH ROW
BEGIN
  IF NEW.id_doacao <> OLD.id_doacao OR NEW.id_produto <> OLD.id_produto THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR05: não é possível alterar a doação ou o produto de um lote.';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- PEDIDO
-- ---------------------------------------------------------------------

-- BR12: só instituições ativas fazem pedidos.
CREATE TRIGGER trg_pedido_bi
BEFORE INSERT ON pedido
FOR EACH ROW
BEGIN
  IF (SELECT estado FROM instituicao WHERE id_instituicao = NEW.id_instituicao) <> 'ativa' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR12: a instituição não está ativa e não pode fazer pedidos.';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- LINHA_ENTREGA — validação de cada saída de stock
-- ---------------------------------------------------------------------

CREATE TRIGGER trg_linha_entrega_bi
BEFORE INSERT ON linha_entrega
FOR EACH ROW
BEGIN
  DECLARE v_id_pedido     INT UNSIGNED;
  DECLARE v_arm_entrega   INT UNSIGNED;
  DECLARE v_data_entrega  DATE;
  DECLARE v_id_produto    INT UNSIGNED;
  DECLARE v_disponivel    DECIMAL(10,2);
  DECLARE v_validade      DATE;
  DECLARE v_arm_lote      INT UNSIGNED;
  DECLARE v_data_doacao   DATE;
  DECLARE v_pedida        DECIMAL(10,2);
  DECLARE v_ja_entregue   DECIMAL(10,2);

  SELECT id_pedido, id_armazem, data_entrega
    INTO v_id_pedido, v_arm_entrega, v_data_entrega
    FROM entrega WHERE id_entrega = NEW.id_entrega;

  SELECT l.id_produto, l.quantidade_disponivel, l.data_validade, d.id_armazem, d.data_doacao
    INTO v_id_produto, v_disponivel, v_validade, v_arm_lote, v_data_doacao
    FROM lote l JOIN doacao d ON d.id_doacao = l.id_doacao
   WHERE l.id_lote = NEW.id_lote;

  -- Um lote só pode sair depois de ter sido recebido.
  IF v_data_doacao > v_data_entrega THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'O lote só foi recebido depois da data da entrega.';
  END IF;

  -- BR01: nenhum lote expirado é entregue.
  IF v_validade < v_data_entrega THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR01: o lote está expirado na data da entrega.';
  END IF;

  -- BR08: o lote tem de estar no armazém de onde sai a entrega.
  IF v_arm_lote <> v_arm_entrega THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR08: o lote não pertence ao armazém da entrega.';
  END IF;

  -- BR02: não se retira mais do que o disponível.
  IF NEW.quantidade > v_disponivel THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR02: quantidade superior ao stock disponível do lote.';
  END IF;

  -- BR07: o produto tem de constar do pedido e o total entregue não excede o pedido.
  SELECT quantidade_pedida INTO v_pedida
    FROM linha_pedido
   WHERE id_pedido = v_id_pedido AND id_produto = v_id_produto;

  IF v_pedida IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR07: o produto do lote não consta do pedido.';
  END IF;

  SELECT COALESCE(SUM(le.quantidade), 0) INTO v_ja_entregue
    FROM linha_entrega le
    JOIN entrega e ON e.id_entrega = le.id_entrega
    JOIN lote l    ON l.id_lote    = le.id_lote
   WHERE e.id_pedido = v_id_pedido AND l.id_produto = v_id_produto;

  IF v_ja_entregue + NEW.quantidade > v_pedida THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR07: a quantidade entregue excede a quantidade pedida.';
  END IF;

  -- BR03 (FEFO): não pode existir, no mesmo armazém, um lote válido do mesmo
  -- produto com stock e validade anterior à do lote escolhido.
  IF EXISTS (
      SELECT 1
        FROM lote l JOIN doacao d ON d.id_doacao = l.id_doacao
       WHERE l.id_produto = v_id_produto
         AND d.id_armazem = v_arm_entrega
         AND l.id_lote <> NEW.id_lote
         AND l.quantidade_disponivel > 0
         AND l.data_validade >= v_data_entrega
         AND d.data_doacao <= v_data_entrega
         AND l.data_validade < v_validade) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR03: existe um lote deste produto que expira mais cedo (FEFO).';
  END IF;
END$$

-- Saída de stock: o lote é decrementado na mesma instrução (atómico).
CREATE TRIGGER trg_linha_entrega_ai
AFTER INSERT ON linha_entrega
FOR EACH ROW
BEGIN
  UPDATE lote
     SET quantidade_disponivel = quantidade_disponivel - NEW.quantidade
   WHERE id_lote = NEW.id_lote;
END$$

-- Movimentos de stock são históricos: não se alteram nem apagam.
CREATE TRIGGER trg_linha_entrega_bu
BEFORE UPDATE ON linha_entrega
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Linhas de entrega não podem ser alteradas (histórico de stock).';
END$$

CREATE TRIGGER trg_linha_entrega_bd
BEFORE DELETE ON linha_entrega
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Linhas de entrega não podem ser apagadas (histórico de stock).';
END$$

-- ---------------------------------------------------------------------
-- DESPERDICIO
-- ---------------------------------------------------------------------

-- BR02/BR10: só se desperdiça o que existe.
CREATE TRIGGER trg_desperdicio_bi
BEFORE INSERT ON desperdicio
FOR EACH ROW
BEGIN
  IF NEW.quantidade > (SELECT quantidade_disponivel FROM lote WHERE id_lote = NEW.id_lote) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR02: quantidade desperdiçada superior ao stock disponível do lote.';
  END IF;
END$$

-- BR10: o desperdício reduz o stock do lote.
CREATE TRIGGER trg_desperdicio_ai
AFTER INSERT ON desperdicio
FOR EACH ROW
BEGIN
  UPDATE lote
     SET quantidade_disponivel = quantidade_disponivel - NEW.quantidade
   WHERE id_lote = NEW.id_lote;
END$$

-- ---------------------------------------------------------------------
-- INSCRICAO_TURNO
-- ---------------------------------------------------------------------

CREATE TRIGGER trg_inscricao_turno_bi
BEFORE INSERT ON inscricao_turno
FOR EACH ROW
BEGIN
  DECLARE v_vagas      INT;
  DECLARE v_inscritos  INT;
  DECLARE v_data       DATE;
  DECLARE v_semana     INT;

  SELECT vagas, data_turno INTO v_vagas, v_data
    FROM turno WHERE id_turno = NEW.id_turno;

  IF (SELECT ativo FROM voluntario WHERE id_voluntario = NEW.id_voluntario) = FALSE THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'O voluntário está inativo.';
  END IF;

  -- BR06: capacidade do turno.
  SELECT COUNT(*) INTO v_inscritos
    FROM inscricao_turno WHERE id_turno = NEW.id_turno;

  IF v_inscritos >= v_vagas THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR06: o turno já não tem vagas.';
  END IF;

  -- BR04: máximo de 3 turnos por semana (semana ISO, segunda a domingo).
  SELECT COUNT(*) INTO v_semana
    FROM inscricao_turno i JOIN turno t ON t.id_turno = i.id_turno
   WHERE i.id_voluntario = NEW.id_voluntario
     AND YEARWEEK(t.data_turno, 3) = YEARWEEK(v_data, 3);

  IF v_semana >= 3 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR04: o voluntário já tem 3 turnos nesta semana.';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- FUNÇÃO: stock disponível (não expirado) de um produto
-- ---------------------------------------------------------------------

-- p_id_armazem NULL = todos os armazéns.
CREATE FUNCTION fn_stock_disponivel(p_id_produto INT UNSIGNED, p_id_armazem INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(12,2);

  SELECT COALESCE(SUM(l.quantidade_disponivel), 0) INTO v_total
    FROM lote l JOIN doacao d ON d.id_doacao = l.id_doacao
   WHERE l.id_produto = p_id_produto
     AND l.data_validade >= CURRENT_DATE
     AND (p_id_armazem IS NULL OR d.id_armazem = p_id_armazem);

  RETURN v_total;
END$$

-- ---------------------------------------------------------------------
-- PROCEDIMENTO: registar entrega de um pedido com seleção FEFO (FR08)
-- Transação: cria a entrega, retira de vários lotes e atualiza o estado
-- do pedido. Qualquer erro desfaz tudo (ROLLBACK).
-- Entrega o que houver em stock; se nada houver, a entrega é recusada.
-- ---------------------------------------------------------------------

CREATE PROCEDURE sp_registar_entrega(
  IN  p_id_pedido      INT UNSIGNED,
  IN  p_id_armazem     INT UNSIGNED,
  IN  p_id_voluntario  INT UNSIGNED,
  IN  p_data_entrega   DATE,
  OUT p_id_entrega     INT UNSIGNED
)
BEGIN
  DECLARE v_estado      VARCHAR(20);
  DECLARE v_produto     INT UNSIGNED DEFAULT 0;
  DECLARE v_pedida      DECIMAL(10,2);
  DECLARE v_falta       DECIMAL(10,2);
  DECLARE v_lote        INT UNSIGNED;
  DECLARE v_disp        DECIMAL(10,2);
  DECLARE v_qtd         DECIMAL(10,2);
  DECLARE v_linhas      INT DEFAULT 0;
  DECLARE v_incompleto  BOOLEAN DEFAULT FALSE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT estado INTO v_estado FROM pedido WHERE id_pedido = p_id_pedido FOR UPDATE;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O pedido não existe.';
  ELSEIF v_estado NOT IN ('pendente', 'parcial') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Só pedidos pendentes ou parciais podem ter entregas.';
  END IF;

  INSERT INTO entrega (id_pedido, id_armazem, id_voluntario, data_entrega)
  VALUES (p_id_pedido, p_id_armazem, p_id_voluntario, p_data_entrega);
  SET p_id_entrega = LAST_INSERT_ID();

  -- Percorre os produtos do pedido por ordem de id.
  produtos: LOOP
    SET v_pedida = NULL;
    SELECT id_produto, quantidade_pedida INTO v_produto, v_pedida
      FROM linha_pedido
     WHERE id_pedido = p_id_pedido AND id_produto > v_produto
     ORDER BY id_produto LIMIT 1;
    IF v_pedida IS NULL THEN
      LEAVE produtos;
    END IF;

    SELECT v_pedida - COALESCE(SUM(le.quantidade), 0) INTO v_falta
      FROM linha_entrega le
      JOIN entrega e ON e.id_entrega = le.id_entrega
      JOIN lote l    ON l.id_lote    = le.id_lote
     WHERE e.id_pedido = p_id_pedido AND l.id_produto = v_produto;

    -- BR03: consome os lotes por ordem crescente de validade (FEFO).
    lotes: WHILE v_falta > 0 DO
      SET v_lote = NULL;
      SELECT l.id_lote, l.quantidade_disponivel INTO v_lote, v_disp
        FROM lote l JOIN doacao d ON d.id_doacao = l.id_doacao
       WHERE l.id_produto = v_produto
         AND d.id_armazem = p_id_armazem
         AND l.quantidade_disponivel > 0
         AND l.data_validade >= p_data_entrega
         AND d.data_doacao <= p_data_entrega
       ORDER BY l.data_validade, l.id_lote
       LIMIT 1
       FOR UPDATE;

      IF v_lote IS NULL THEN
        SET v_incompleto = TRUE;   -- sem stock suficiente deste produto
        LEAVE lotes;
      END IF;

      SET v_qtd = LEAST(v_falta, v_disp);
      INSERT INTO linha_entrega (id_entrega, id_lote, quantidade)
      VALUES (p_id_entrega, v_lote, v_qtd);   -- trg_linha_entrega_* valida e desconta
      SET v_falta  = v_falta - v_qtd;
      SET v_linhas = v_linhas + 1;
    END WHILE lotes;
  END LOOP produtos;

  IF v_linhas = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'BR02: não há stock disponível neste armazém para nenhum produto do pedido.';
  END IF;

  UPDATE pedido
     SET estado = IF(v_incompleto, 'parcial', 'concluido')
   WHERE id_pedido = p_id_pedido;

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDIMENTO: abater lotes expirados como desperdício (BR10, FR09)
-- Usa um ciclo e não INSERT...SELECT FROM lote, porque o trigger de
-- desperdicio atualiza lote (MySQL erro 1442).
-- ---------------------------------------------------------------------

CREATE PROCEDURE sp_processar_expirados(
  IN  p_data         DATE,
  OUT p_num_lotes    INT
)
BEGIN
  DECLARE v_lote  INT UNSIGNED;
  DECLARE v_qtd   DECIMAL(10,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET p_num_lotes = 0;
  START TRANSACTION;

  ciclo: LOOP
    SET v_lote = NULL;
    SELECT id_lote, quantidade_disponivel INTO v_lote, v_qtd
      FROM lote
     WHERE data_validade < p_data AND quantidade_disponivel > 0
     ORDER BY id_lote LIMIT 1
     FOR UPDATE;
    IF v_lote IS NULL THEN
      LEAVE ciclo;
    END IF;

    INSERT INTO desperdicio (id_lote, id_voluntario, data_registo, quantidade, motivo, observacoes)
    VALUES (v_lote, NULL, p_data, v_qtd, 'expirado', 'Abate automático de lote expirado');
    SET p_num_lotes = p_num_lotes + 1;
  END LOOP ciclo;

  COMMIT;
END$$

DELIMITER ;
