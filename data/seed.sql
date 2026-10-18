-- =====================================================================
-- Despensa Solidária — seed.sql
-- Dados representativos (fictícios). Executar DEPOIS de schema.sql,
-- programmable_objects.sql e views.sql: as entregas e o desperdício
-- passam pelos triggers/procedimentos, por isso o stock fica coerente.
--
-- As datas são relativas a CURRENT_DATE, para que os alertas de validade,
-- os lotes expirados e os turnos da semana façam sentido em qualquer dia
-- em que a base de dados seja criada.
-- =====================================================================

USE despensa_solidaria;

-- Hash (PBKDF2-SHA256) da password de demonstração indicada no README.
SET @pw = 'pbkdf2:sha256:1000000$BIOm2G1GONLFlJ87$238dd5493fec8f33e770cc2162f78dc48c6c816ec8c59a5b3d83aa3800300c65';
SET @hoje = CURRENT_DATE;
SET @segunda = CURRENT_DATE - INTERVAL WEEKDAY(CURRENT_DATE) DAY;   -- início da semana atual

-- ---------------------------------------------------------------------
-- Referência
-- ---------------------------------------------------------------------
INSERT INTO armazem (nome, morada, localidade) VALUES
  ('Armazém Central de Aveiro', 'Rua das Salinas, 120',      'Aveiro'),   -- 1
  ('Polo de Ílhavo',            'Avenida da Ria, 45',        'Ílhavo'),   -- 2
  ('Polo de Ovar',              'Rua do Mercado, 8',         'Ovar');     -- 3

INSERT INTO categoria (nome, descricao) VALUES
  ('Laticínios',            'Leite, iogurtes e queijo'),                -- 1
  ('Massas e Arroz',        'Massas secas e arroz'),                    -- 2
  ('Conservas',             'Peixe e carne em lata'),                   -- 3
  ('Leguminosas',           'Grão, feijão e lentilhas'),                -- 4
  ('Frutas e Legumes',      'Produtos frescos'),                        -- 5
  ('Óleos e Condimentos',   'Azeite, óleo e sal'),                      -- 6
  ('Bebidas',               'Água e sumos'),                            -- 7
  ('Alimentação Infantil',  'Papas e leite em pó para bebés');          -- 8

INSERT INTO produto (id_categoria, nome, unidade_medida) VALUES
  (1, 'Leite UHT meio-gordo', 'l'),    -- 1
  (1, 'Iogurte natural',      'un'),   -- 2
  (1, 'Queijo flamengo',      'kg'),   -- 3
  (2, 'Massa esparguete',     'kg'),   -- 4
  (2, 'Arroz agulha',         'kg'),   -- 5
  (2, 'Massa cotovelos',      'kg'),   -- 6
  (3, 'Atum em lata',         'un'),   -- 7
  (3, 'Sardinha em lata',     'un'),   -- 8
  (3, 'Salsichas em lata',    'un'),   -- 9
  (4, 'Grão-de-bico cozido',  'un'),   -- 10
  (4, 'Feijão encarnado',     'kg'),   -- 11
  (4, 'Lentilhas',            'kg'),   -- 12
  (5, 'Maçã',                 'kg'),   -- 13
  (5, 'Batata',               'kg'),   -- 14
  (5, 'Cenoura',              'kg'),   -- 15
  (6, 'Azeite',               'l'),    -- 16
  (6, 'Óleo alimentar',       'l'),    -- 17
  (6, 'Sal',                  'kg'),   -- 18
  (7, 'Água mineral',         'l'),    -- 19
  (7, 'Sumo de laranja',      'l'),    -- 20
  (8, 'Papa infantil',        'un'),   -- 21
  (8, 'Leite em pó infantil', 'un');   -- 22

-- ---------------------------------------------------------------------
-- Pessoas
-- ---------------------------------------------------------------------
INSERT INTO voluntario (nome, email, telefone, perfil, password_hash, data_inscricao, ativo) VALUES
  ('Ana Ribeiro',     'ana.ribeiro@despensa.test',     '910000001', 'coordenador', @pw, @hoje - INTERVAL 400 DAY, TRUE),   -- 1
  ('Rui Matos',       'rui.matos@despensa.test',       '910000002', 'coordenador', @pw, @hoje - INTERVAL 300 DAY, TRUE),   -- 2
  ('Beatriz Santos',  'beatriz.santos@despensa.test',  '910000003', 'voluntario',  @pw, @hoje - INTERVAL 200 DAY, TRUE),   -- 3
  ('Tiago Oliveira',  'tiago.oliveira@despensa.test',  '910000004', 'voluntario',  @pw, @hoje - INTERVAL 180 DAY, TRUE),   -- 4
  ('Marta Costa',     'marta.costa@despensa.test',     '910000005', 'voluntario',  @pw, @hoje - INTERVAL 150 DAY, TRUE),   -- 5
  ('Diogo Ferreira',  'diogo.ferreira@despensa.test',  NULL,        'voluntario',  @pw, @hoje - INTERVAL 120 DAY, TRUE),   -- 6
  ('Sofia Martins',   'sofia.martins@despensa.test',   '910000007', 'voluntario',  @pw, @hoje - INTERVAL 90 DAY,  TRUE),   -- 7
  ('Gonçalo Pinto',   'goncalo.pinto@despensa.test',   '910000008', 'voluntario',  @pw, @hoje - INTERVAL 60 DAY,  TRUE),   -- 8
  ('Inês Rocha',      'ines.rocha@despensa.test',      '910000009', 'voluntario',  @pw, @hoje - INTERVAL 30 DAY,  TRUE),   -- 9
  ('Hugo Carvalho',   'hugo.carvalho@despensa.test',   NULL,        'voluntario',  @pw, @hoje - INTERVAL 250 DAY, FALSE);  -- 10 (inativo)

INSERT INTO doador (tipo, nome, nif, email, telefone, data_registo) VALUES
  ('empresa',    'Supermercado Ria Fresca',              '501234560', 'geral@riafresca.test',       '234000001', @hoje - INTERVAL 365 DAY),  -- 1
  ('empresa',    'Padaria Moliceiro',                    '502345671', NULL,                         '234000002', @hoje - INTERVAL 300 DAY),  -- 2
  ('empresa',    'Cooperativa Agrícola Terras do Vouga', '503456782', 'coop@terrasvouga.test',      '234000003', @hoje - INTERVAL 280 DAY),  -- 3
  ('empresa',    'Lacticínios Beira-Mar',                '504567893', 'doacoes@beiramar.test',      NULL,        @hoje - INTERVAL 250 DAY),  -- 4
  ('empresa',    'Associação de Estudantes (campanha)',  '505678904', 'ae@campanha.test',           NULL,        @hoje - INTERVAL 100 DAY),  -- 5
  ('empresa',    'Hipermercado Costa Nova',              '506789015', 'social@costanova.test',      '234000006', @hoje - INTERVAL 220 DAY),  -- 6
  ('particular', 'Maria Fernandes',                      '212345678', 'maria.f@mail.test',          '960000007', @hoje - INTERVAL 90 DAY),   -- 7
  ('particular', 'João Pereira',                         NULL,        NULL,                         '960000008', @hoje - INTERVAL 60 DAY),   -- 8
  ('particular', 'Carla Sousa',                          '223456789', 'carla.s@mail.test',          NULL,        @hoje - INTERVAL 40 DAY),   -- 9
  ('particular', 'Anónimo — recolha em supermercado',    NULL,        NULL,                         NULL,        @hoje - INTERVAL 30 DAY),   -- 10
  ('empresa',    'Distribuidora Alimentar do Centro',    '507890126', 'rse@dacentro.test',          '234000011', @hoje - INTERVAL 200 DAY),  -- 11
  ('particular', 'Pedro Almeida',                        NULL,        'pedro.a@mail.test',          NULL,        @hoje - INTERVAL 10 DAY);   -- 12 (ainda sem doações)

INSERT INTO instituicao (nome, nif, tipo, morada, localidade, email, telefone, num_beneficiarios, estado) VALUES
  ('Centro Social da Beira-Ria',    '508000001', 'Centro Social', 'Rua do Cais, 3',          'Aveiro', 'geral@beiraria.test',   '234100001', 120, 'ativa'),     -- 1
  ('Associação Mãos Solidárias',    '508000002', 'Associação',    'Travessa da Lota, 12',    'Ílhavo', 'maos@solidarias.test',  '234100002',  80, 'ativa'),     -- 2
  ('Grupo Paroquial Esperança',     '508000003', 'Paróquia',      'Largo da Igreja, 1',      'Aveiro', NULL,                    '234100003',  60, 'ativa'),     -- 3
  ('Lar Nossa Casa',                '508000004', 'IPSS',          'Rua das Flores, 22',      'Ovar',   'lar@nossacasa.test',    '256100004',  45, 'ativa'),     -- 4
  ('Cantina Social Porta Aberta',   '508000005', 'IPSS',          'Avenida Central, 150',    'Aveiro', 'cantina@porta.test',    '234100005', 200, 'ativa'),     -- 5
  ('Associação Vizinhos Unidos',    '508000006', 'Associação',    'Rua Nova, 5',             'Ovar',   NULL,                    NULL,         30, 'suspensa');  -- 6

-- ---------------------------------------------------------------------
-- Doações e lotes (a quantidade disponível é definida pelo trigger)
-- ---------------------------------------------------------------------
INSERT INTO doacao (id_doador, id_armazem, id_voluntario, data_doacao, observacoes) VALUES
  ( 1, 1,    3, @hoje - INTERVAL 60 DAY, NULL),                               -- 1
  ( 4, 1,    4, @hoje - INTERVAL 45 DAY, 'Excedentes de produção'),           -- 2
  ( 3, 1,    3, @hoje - INTERVAL 40 DAY, NULL),                               -- 3
  ( 6, 2,    5, @hoje - INTERVAL 35 DAY, NULL),                               -- 4
  ( 7, 1, NULL, @hoje - INTERVAL 30 DAY, 'Entregue na receção'),              -- 5
  (11, 1,    6, @hoje - INTERVAL 25 DAY, NULL),                               -- 6
  (10, 3,    7, @hoje - INTERVAL 20 DAY, 'Campanha de recolha de fim de semana'), -- 7
  ( 3, 1,    3, @hoje - INTERVAL 15 DAY, NULL),                               -- 8
  ( 5, 2,    5, @hoje - INTERVAL 12 DAY, 'Campanha universitária'),           -- 9
  ( 1, 1,    4, @hoje - INTERVAL 10 DAY, NULL),                               -- 10
  ( 9, 3,    8, @hoje - INTERVAL  8 DAY, NULL),                               -- 11
  ( 4, 1,    6, @hoje - INTERVAL  5 DAY, NULL),                               -- 12
  ( 8, 2, NULL, @hoje - INTERVAL  3 DAY, NULL),                               -- 13
  (11, 3,    7, @hoje - INTERVAL  2 DAY, NULL),                               -- 14
  ( 6, 1,    3, @hoje - INTERVAL  1 DAY, NULL);                               -- 15

INSERT INTO lote (id_doacao, id_produto, quantidade_inicial, quantidade_disponivel, data_validade) VALUES
  ( 1,  1, 120, 0, @hoje + INTERVAL  30 DAY),   -- 1  leite
  ( 1,  5,  80, 0, @hoje + INTERVAL 200 DAY),   -- 2  arroz
  ( 1,  7, 150, 0, @hoje + INTERVAL 400 DAY),   -- 3  atum
  ( 1,  2,  60, 0, @hoje - INTERVAL  30 DAY),   -- 4  iogurte (expirado)
  ( 2,  1, 200, 0, @hoje + INTERVAL   5 DAY),   -- 5  leite (a expirar)
  ( 2,  2,  80, 0, @hoje - INTERVAL   5 DAY),   -- 6  iogurte (expirado)
  ( 2,  3,  25, 0, @hoje + INTERVAL   3 DAY),   -- 7  queijo (a expirar)
  ( 3, 13, 150, 0, @hoje - INTERVAL  10 DAY),   -- 8  maçã (expirado)
  ( 3, 14, 300, 0, @hoje + INTERVAL  20 DAY),   -- 9  batata
  ( 3, 15, 100, 0, @hoje + INTERVAL   2 DAY),   -- 10 cenoura (a expirar)
  ( 4,  4, 100, 0, @hoje + INTERVAL 300 DAY),   -- 11 esparguete
  ( 4,  7, 100, 0, @hoje + INTERVAL 350 DAY),   -- 12 atum
  ( 4, 16,  50, 0, @hoje + INTERVAL 250 DAY),   -- 13 azeite
  ( 4,  1, 100, 0, @hoje + INTERVAL  15 DAY),   -- 14 leite
  ( 5, 10,  40, 0, @hoje + INTERVAL 180 DAY),   -- 15 grão
  ( 5, 11,  20, 0, @hoje + INTERVAL 250 DAY),   -- 16 feijão
  ( 6,  5, 150, 0, @hoje + INTERVAL 150 DAY),   -- 17 arroz (expira antes do lote 2)
  ( 6,  4, 120, 0, @hoje + INTERVAL 220 DAY),   -- 18 esparguete
  ( 6, 17,  60, 0, @hoje + INTERVAL 300 DAY),   -- 19 óleo
  ( 6, 19, 300, 0, @hoje + INTERVAL 365 DAY),   -- 20 água
  ( 7,  8, 120, 0, @hoje + INTERVAL 500 DAY),   -- 21 sardinha
  ( 7,  5,  60, 0, @hoje + INTERVAL 180 DAY),   -- 22 arroz
  ( 7, 21,  40, 0, @hoje + INTERVAL  90 DAY),   -- 23 papa infantil
  ( 8, 13, 100, 0, @hoje + INTERVAL   6 DAY),   -- 24 maçã (a expirar)
  ( 8, 14, 200, 0, @hoje + INTERVAL  25 DAY),   -- 25 batata
  ( 9,  7,  80, 0, @hoje + INTERVAL 380 DAY),   -- 26 atum
  ( 9,  6,  70, 0, @hoje + INTERVAL 260 DAY),   -- 27 cotovelos
  ( 9, 12,  30, 0, @hoje + INTERVAL 300 DAY),   -- 28 lentilhas
  ( 9, 22,  25, 0, @hoje + INTERVAL 200 DAY),   -- 29 leite em pó
  (10,  1, 150, 0, @hoje + INTERVAL  60 DAY),   -- 30 leite
  (10, 20,  80, 0, @hoje + INTERVAL  40 DAY),   -- 31 sumo
  (10,  9,  90, 0, @hoje + INTERVAL 270 DAY),   -- 32 salsichas
  (11, 10,  30, 0, @hoje + INTERVAL 200 DAY),   -- 33 grão
  (11, 18,  15, 0, @hoje + INTERVAL 700 DAY),   -- 34 sal
  (12,  2, 100, 0, @hoje + INTERVAL   4 DAY),   -- 35 iogurte (a expirar)
  (12,  3,  30, 0, @hoje + INTERVAL  25 DAY),   -- 36 queijo
  (13,  5,  25, 0, @hoje + INTERVAL 300 DAY),   -- 37 arroz
  (13, 11,  15, 0, @hoje + INTERVAL 300 DAY),   -- 38 feijão
  (14, 16,  40, 0, @hoje + INTERVAL 280 DAY),   -- 39 azeite
  (14, 19, 200, 0, @hoje + INTERVAL 360 DAY),   -- 40 água
  (14,  1,  80, 0, @hoje + INTERVAL  50 DAY),   -- 41 leite
  (15, 21,  50, 0, @hoje + INTERVAL 120 DAY),   -- 42 papa infantil
  (15, 22,  30, 0, @hoje + INTERVAL 210 DAY),   -- 43 leite em pó
  (15,  7, 100, 0, @hoje + INTERVAL 420 DAY);   -- 44 atum

-- ---------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------
INSERT INTO pedido (id_instituicao, data_pedido, estado, observacoes) VALUES
  (1, @hoje - INTERVAL 30 DAY, 'pendente',  NULL),                         -- 1
  (2, @hoje - INTERVAL 20 DAY, 'pendente',  NULL),                         -- 2
  (5, @hoje - INTERVAL 14 DAY, 'pendente',  'Reforço para a cantina'),     -- 3
  (4, @hoje - INTERVAL  9 DAY, 'pendente',  NULL),                         -- 4
  (3, @hoje - INTERVAL  6 DAY, 'pendente',  NULL),                         -- 5 (por entregar)
  (5, @hoje - INTERVAL  2 DAY, 'pendente',  NULL),                         -- 6 (por entregar)
  (2, @hoje - INTERVAL  4 DAY, 'cancelado', 'Cancelado pela instituição'); -- 7

INSERT INTO linha_pedido (id_pedido, id_produto, quantidade_pedida) VALUES
  (1,  1, 100), (1,  5,  50), (1,  7,  60),
  (2,  4,  60), (2,  7,  50), (2, 16,  20),
  (3, 14, 150), (3,  1, 120), (3,  5, 100), (3, 10,  50),
  (4,  8,  60), (4, 21,  20), (4,  5,  40),
  (5,  2,  50), (5, 13,  80), (5,  3,  10),
  (6,  7,  80), (6,  1,  60), (6, 19, 100),
  (7,  6,  30);

-- ---------------------------------------------------------------------
-- Entregas — feitas pelo procedimento transacional (FEFO)
-- ---------------------------------------------------------------------
CALL sp_registar_entrega(1, 1, 3, @hoje - INTERVAL 28 DAY, @e);   -- concluído
CALL sp_registar_entrega(2, 2, 5, @hoje - INTERVAL 18 DAY, @e);   -- concluído
CALL sp_registar_entrega(3, 1, 4, @hoje - INTERVAL 12 DAY, @e);   -- parcial (falta grão)
CALL sp_registar_entrega(4, 3, 7, @hoje - INTERVAL  7 DAY, @e);   -- concluído

-- ---------------------------------------------------------------------
-- Desperdício (o trigger desconta o stock do lote)
-- Os lotes 4 e 6 ficam expirados por abater, para demonstrar
-- sp_processar_expirados no protótipo.
-- ---------------------------------------------------------------------
INSERT INTO desperdicio (id_lote, id_voluntario, data_registo, quantidade, motivo, observacoes) VALUES
  ( 8, 3, @hoje - INTERVAL 9 DAY, 150, 'expirado',   'Maçã imprópria para consumo'),
  (14, 5, @hoje - INTERVAL 10 DAY,  5, 'danificado', 'Embalagens furadas'),
  ( 9, 4, @hoje - INTERVAL 5 DAY,  20, 'danificado', 'Batata com bolor'),
  (24, 6, @hoje - INTERVAL 2 DAY,  10, 'danificado', 'Fruta pisada no transporte');

-- ---------------------------------------------------------------------
-- Turnos (semana atual e seguinte) e inscrições
-- ---------------------------------------------------------------------
INSERT INTO turno (id_armazem, data_turno, hora_inicio, hora_fim, vagas) VALUES
  (1, @segunda,                    '09:00', '13:00', 3),   -- 1  seg
  (1, @segunda + INTERVAL 2 DAY,   '09:00', '13:00', 3),   -- 2  qua
  (1, @segunda + INTERVAL 4 DAY,   '14:00', '18:00', 4),   -- 3  sex
  (1, @segunda + INTERVAL 5 DAY,   '09:00', '13:00', 4),   -- 4  sáb
  (2, @segunda + INTERVAL 1 DAY,   '14:00', '18:00', 2),   -- 5  ter
  (2, @segunda + INTERVAL 3 DAY,   '14:00', '18:00', 2),   -- 6  qui
  (3, @segunda + INTERVAL 5 DAY,   '09:00', '13:00', 3),   -- 7  sáb
  (1, @segunda + INTERVAL 7 DAY,   '09:00', '13:00', 3),   -- 8  seg (próxima semana)
  (1, @segunda + INTERVAL 9 DAY,   '09:00', '13:00', 3),   -- 9  qua
  (1, @segunda + INTERVAL 11 DAY,  '14:00', '18:00', 4),   -- 10 sex
  (2, @segunda + INTERVAL 8 DAY,   '14:00', '18:00', 2),   -- 11 ter
  (3, @segunda + INTERVAL 12 DAY,  '09:00', '13:00', 3);   -- 12 sáb

INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES
  (3, 1), (3, 2), (3, 3),        -- Beatriz: 3 turnos nesta semana (limite BR04)
  (4, 1), (4, 3),
  (6, 1),                        -- turno 1 fica cheio (3/3, BR06)
  (6, 4),
  (5, 5), (5, 6),
  (9, 5),                        -- turno 5 fica cheio (2/2)
  (7, 7), (8, 7), (8, 3),
  (3, 8), (9, 8), (9, 9),
  (4, 10), (4, 11),
  (7, 12);
