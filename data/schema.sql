-- =====================================================================
-- Despensa Solidária — schema.sql
-- SGBD: MySQL 8.0 (>= 8.0.16), motor InnoDB, utf8mb4
-- Cria a base de dados e as 15 tabelas, com PK, FK, NOT NULL, UNIQUE,
-- CHECK e regras referenciais. Regras que envolvem várias tabelas
-- (BR01, BR02, BR04, BR06–BR10, BR12) estão em programmable_objects.sql.
-- =====================================================================

SET NAMES utf8mb4;   -- garante os acentos com qualquer cliente (ex.: consola Windows em cp850)
DROP DATABASE IF EXISTS despensa_solidaria;
CREATE DATABASE despensa_solidaria
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE despensa_solidaria;

-- ---------------------------------------------------------------------
-- Tabelas de referência
-- ---------------------------------------------------------------------

CREATE TABLE categoria (
  id_categoria  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nome          VARCHAR(60)   NOT NULL,
  descricao     VARCHAR(255)  NULL,
  CONSTRAINT pk_categoria PRIMARY KEY (id_categoria),
  CONSTRAINT uq_categoria_nome UNIQUE (nome)                        -- BR11
) ENGINE = InnoDB;

CREATE TABLE produto (
  id_produto     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_categoria   INT UNSIGNED  NOT NULL,
  nome           VARCHAR(100)  NOT NULL,
  unidade_medida ENUM('un','kg','l') NOT NULL,
  CONSTRAINT pk_produto PRIMARY KEY (id_produto),
  CONSTRAINT uq_produto_nome UNIQUE (nome),                         -- BR11
  CONSTRAINT fk_produto_categoria FOREIGN KEY (id_categoria)
    REFERENCES categoria (id_categoria)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE armazem (
  id_armazem  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nome        VARCHAR(80)   NOT NULL,
  morada      VARCHAR(150)  NOT NULL,
  localidade  VARCHAR(60)   NOT NULL,
  CONSTRAINT pk_armazem PRIMARY KEY (id_armazem),
  CONSTRAINT uq_armazem_nome UNIQUE (nome)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Pessoas
-- ---------------------------------------------------------------------

-- Voluntários são também os utilizadores do sistema (perfil define o papel).
CREATE TABLE voluntario (
  id_voluntario   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nome            VARCHAR(100)  NOT NULL,
  email           VARCHAR(120)  NOT NULL,
  telefone        VARCHAR(20)   NULL,
  perfil          ENUM('coordenador','voluntario') NOT NULL DEFAULT 'voluntario',
  password_hash   VARCHAR(255)  NOT NULL,
  data_inscricao  DATE          NOT NULL DEFAULT (CURRENT_DATE),
  ativo           BOOLEAN       NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_voluntario PRIMARY KEY (id_voluntario),
  CONSTRAINT uq_voluntario_email UNIQUE (email),
  CONSTRAINT ck_voluntario_email CHECK (email LIKE '%_@_%._%')
) ENGINE = InnoDB;

-- NIF opcional: particulares em campanhas de recolha podem ser anónimos.
-- UNIQUE em MySQL admite vários NULL, logo só NIFs preenchidos são únicos.
CREATE TABLE doador (
  id_doador     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  tipo          ENUM('particular','empresa') NOT NULL,
  nome          VARCHAR(120)  NOT NULL,
  nif           CHAR(9)       NULL,
  email         VARCHAR(120)  NULL,
  telefone      VARCHAR(20)   NULL,
  data_registo  DATE          NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT pk_doador PRIMARY KEY (id_doador),
  CONSTRAINT uq_doador_nif UNIQUE (nif),                            -- BR11
  CONSTRAINT ck_doador_nif CHECK (nif IS NULL OR nif REGEXP '^[0-9]{9}$'),
  CONSTRAINT ck_doador_empresa_nif CHECK (tipo = 'particular' OR nif IS NOT NULL)
) ENGINE = InnoDB;

CREATE TABLE instituicao (
  id_instituicao     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  nome               VARCHAR(120)  NOT NULL,
  nif                CHAR(9)       NOT NULL,
  tipo               ENUM('IPSS','Paróquia','Associação','Centro Social','Outra') NOT NULL,
  morada             VARCHAR(150)  NOT NULL,
  localidade         VARCHAR(60)   NOT NULL,
  email              VARCHAR(120)  NULL,
  telefone           VARCHAR(20)   NULL,
  num_beneficiarios  INT UNSIGNED  NOT NULL DEFAULT 0,
  estado             ENUM('ativa','suspensa','inativa') NOT NULL DEFAULT 'ativa',
  CONSTRAINT pk_instituicao PRIMARY KEY (id_instituicao),
  CONSTRAINT uq_instituicao_nif UNIQUE (nif),                       -- BR11
  CONSTRAINT ck_instituicao_nif CHECK (nif REGEXP '^[0-9]{9}$')
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Entradas: doações e lotes
-- ---------------------------------------------------------------------

-- O armazém é registado na doação; os lotes herdam-no através dela
-- (guardá-lo também no lote criaria uma dependência transitiva — 3FN).
CREATE TABLE doacao (
  id_doacao      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_doador      INT UNSIGNED  NOT NULL,
  id_armazem     INT UNSIGNED  NOT NULL,
  id_voluntario  INT UNSIGNED  NULL,          -- quem rececionou (opcional)
  data_doacao    DATE          NOT NULL,
  observacoes    VARCHAR(255)  NULL,
  CONSTRAINT pk_doacao PRIMARY KEY (id_doacao),
  CONSTRAINT fk_doacao_doador FOREIGN KEY (id_doador)
    REFERENCES doador (id_doador) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_doacao_armazem FOREIGN KEY (id_armazem)
    REFERENCES armazem (id_armazem) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_doacao_voluntario FOREIGN KEY (id_voluntario)
    REFERENCES voluntario (id_voluntario) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB;

CREATE TABLE lote (
  id_lote                INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  id_doacao              INT UNSIGNED   NOT NULL,
  id_produto             INT UNSIGNED   NOT NULL,
  quantidade_inicial     DECIMAL(10,2)  NOT NULL,
  quantidade_disponivel  DECIMAL(10,2)  NOT NULL,
  data_validade          DATE           NOT NULL,
  CONSTRAINT pk_lote PRIMARY KEY (id_lote),
  CONSTRAINT fk_lote_doacao FOREIGN KEY (id_doacao)
    REFERENCES doacao (id_doacao) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_lote_produto FOREIGN KEY (id_produto)
    REFERENCES produto (id_produto) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_lote_qtd_inicial CHECK (quantidade_inicial > 0),                 -- BR05
  CONSTRAINT ck_lote_qtd_disponivel CHECK (quantidade_disponivel >= 0            -- BR02
                                           AND quantidade_disponivel <= quantidade_inicial)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Saídas: pedidos, entregas e desperdício
-- ---------------------------------------------------------------------

CREATE TABLE pedido (
  id_pedido       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_instituicao  INT UNSIGNED  NOT NULL,
  data_pedido     DATE          NOT NULL,
  estado          ENUM('pendente','parcial','concluido','cancelado') NOT NULL DEFAULT 'pendente',
  observacoes     VARCHAR(255)  NULL,
  CONSTRAINT pk_pedido PRIMARY KEY (id_pedido),
  CONSTRAINT fk_pedido_instituicao FOREIGN KEY (id_instituicao)
    REFERENCES instituicao (id_instituicao) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Entidade associativa pedido × produto (N:M).
CREATE TABLE linha_pedido (
  id_pedido          INT UNSIGNED   NOT NULL,
  id_produto         INT UNSIGNED   NOT NULL,
  quantidade_pedida  DECIMAL(10,2)  NOT NULL,
  CONSTRAINT pk_linha_pedido PRIMARY KEY (id_pedido, id_produto),
  CONSTRAINT fk_linha_pedido_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido (id_pedido) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_linha_pedido_produto FOREIGN KEY (id_produto)
    REFERENCES produto (id_produto) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_linha_pedido_qtd CHECK (quantidade_pedida > 0)
) ENGINE = InnoDB;

CREATE TABLE entrega (
  id_entrega     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  id_pedido      INT UNSIGNED  NOT NULL,
  id_armazem     INT UNSIGNED  NOT NULL,
  id_voluntario  INT UNSIGNED  NOT NULL,      -- responsável pela entrega
  data_entrega   DATE          NOT NULL,
  CONSTRAINT pk_entrega PRIMARY KEY (id_entrega),
  CONSTRAINT fk_entrega_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido (id_pedido) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_entrega_armazem FOREIGN KEY (id_armazem)
    REFERENCES armazem (id_armazem) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_entrega_voluntario FOREIGN KEY (id_voluntario)
    REFERENCES voluntario (id_voluntario) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Entidade associativa entrega × lote (N:M): de que lotes saiu cada entrega.
CREATE TABLE linha_entrega (
  id_entrega  INT UNSIGNED   NOT NULL,
  id_lote     INT UNSIGNED   NOT NULL,
  quantidade  DECIMAL(10,2)  NOT NULL,
  CONSTRAINT pk_linha_entrega PRIMARY KEY (id_entrega, id_lote),
  CONSTRAINT fk_linha_entrega_entrega FOREIGN KEY (id_entrega)
    REFERENCES entrega (id_entrega) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_linha_entrega_lote FOREIGN KEY (id_lote)
    REFERENCES lote (id_lote) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_linha_entrega_qtd CHECK (quantidade > 0)
) ENGINE = InnoDB;

CREATE TABLE desperdicio (
  id_desperdicio  INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  id_lote         INT UNSIGNED   NOT NULL,
  id_voluntario   INT UNSIGNED   NULL,        -- NULL quando registado automaticamente
  data_registo    DATE           NOT NULL,
  quantidade      DECIMAL(10,2)  NOT NULL,
  motivo          ENUM('expirado','danificado','outro') NOT NULL,
  observacoes     VARCHAR(255)   NULL,
  CONSTRAINT pk_desperdicio PRIMARY KEY (id_desperdicio),
  CONSTRAINT fk_desperdicio_lote FOREIGN KEY (id_lote)
    REFERENCES lote (id_lote) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_desperdicio_voluntario FOREIGN KEY (id_voluntario)
    REFERENCES voluntario (id_voluntario) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT ck_desperdicio_qtd CHECK (quantidade > 0)                           -- BR10
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Turnos de voluntariado
-- ---------------------------------------------------------------------

CREATE TABLE turno (
  id_turno     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  id_armazem   INT UNSIGNED      NOT NULL,
  data_turno   DATE              NOT NULL,
  hora_inicio  TIME              NOT NULL,
  hora_fim     TIME              NOT NULL,
  vagas        TINYINT UNSIGNED  NOT NULL,
  CONSTRAINT pk_turno PRIMARY KEY (id_turno),
  CONSTRAINT uq_turno UNIQUE (id_armazem, data_turno, hora_inicio),
  CONSTRAINT fk_turno_armazem FOREIGN KEY (id_armazem)
    REFERENCES armazem (id_armazem) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_turno_horas CHECK (hora_fim > hora_inicio),
  CONSTRAINT ck_turno_vagas CHECK (vagas > 0)
) ENGINE = InnoDB;

-- Entidade associativa voluntário × turno (N:M).
-- A PK composta impede inscrições duplicadas no mesmo turno (BR06).
CREATE TABLE inscricao_turno (
  id_voluntario   INT UNSIGNED  NOT NULL,
  id_turno        INT UNSIGNED  NOT NULL,
  data_inscricao  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_inscricao_turno PRIMARY KEY (id_voluntario, id_turno),
  CONSTRAINT fk_inscricao_voluntario FOREIGN KEY (id_voluntario)
    REFERENCES voluntario (id_voluntario) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_inscricao_turno FOREIGN KEY (id_turno)
    REFERENCES turno (id_turno) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Índices adicionais (as PK, UNIQUE e FK já têm índice no InnoDB)
-- ---------------------------------------------------------------------

-- Seleção FEFO: lotes de um produto por ordem de validade.
CREATE INDEX idx_lote_produto_validade ON lote (id_produto, data_validade);
-- Alertas de validade (FR11) e processamento de expirados.
CREATE INDEX idx_lote_validade ON lote (data_validade);
-- Relatórios por período.
CREATE INDEX idx_entrega_data ON entrega (data_entrega);
CREATE INDEX idx_doacao_data ON doacao (data_doacao);
CREATE INDEX idx_desperdicio_data ON desperdicio (data_registo);
