# Technical Stack

## Database
- DBMS: MySQL Community Server
- Version: 8.0.x (testado em 8.0.46; mínimo 8.0.16, necessário para CHECK constraints)
- Database name: `despensa_solidaria`
- SQL dialect: MySQL 8.0
- Storage engine: InnoDB (obrigatório para chaves estrangeiras e transações)
- Charset / collation: `utf8mb4` / `utf8mb4_0900_ai_ci`
- Ferramenta de administração: MySQL Workbench 8.0

## Backend
- Language: Python
- Version: 3.14 (testado em 3.14.7; funciona com 3.10+)
- Framework: Flask
- Version: 3.1.3 (inclui Werkzeug 3.1.9 e Jinja2 3.1.6)

## Database access
- Library / ORM: sem ORM — SQL escrito à mão (consultas, views e chamadas a procedimentos)
- Driver: PyMySQL 1.2.3 (puro Python); configuração lida de `.env` com python-dotenv 1.2.4

## Frontend / UI
- Technology: páginas HTML geradas no servidor com templates Jinja2, CSS próprio, JavaScript mínimo (adicionar linhas de lotes/produtos)
- Version: HTML5 / CSS3, sem frameworks nem CDNs

## Runtime / package management
- Runtime: CPython 3.14 num ambiente virtual (`application/.venv`)
- Package manager: pip; dependências fixadas em `application/requirements.txt`

## Architecture
Aplicação web monolítica em duas camadas:

```
Browser ──HTTP──▶ Flask (app.py, templates Jinja2) ──PyMySQL──▶ MySQL 8.0 (despensa_solidaria)
```

- A **base de dados é a fonte das regras**: CHECK, chaves, triggers e procedimentos garantem BR01–BR12. A aplicação não repete as regras; envia as operações e mostra ao utilizador a mensagem do erro devolvido (`SIGNAL ... 'BRxx: ...'`).
- Leituras usam as views (`vw_stock_disponivel`, `vw_lotes_a_expirar`, `vw_lotes_expirados`, `vw_pedido_progresso`) e a função `fn_stock_disponivel`.
- Escritas com vários passos são transacionais: registo de doação + lotes e de pedido + linhas (transação aberta pela aplicação, `commit`/`rollback`), entrega FEFO e abate de expirados (transação dentro dos procedimentos `sp_registar_entrega` e `sp_processar_expirados`).
- Cada pedido HTTP abre e fecha a sua ligação (sem pool), suficiente para um protótipo.

## Authentication / roles
- **Sem passwords na interface** (requisito do docente): o ecrã de entrada pede apenas que se escolha o utilizador (lista de voluntários ativos). É uma simplificação assumida para um protótipo de demonstração; numa versão de produção seria necessária autenticação.
- Sessão Flask assinada com `FLASK_SECRET_KEY` (definida no `.env`). A única password do projeto é a da ligação ao MySQL, guardada no `.env` (fora do Git).
- Dois papéis (`voluntario.perfil`): **coordenador** (tudo, incluindo doadores, instituições, criação de pedidos e turnos, relatórios e abate de expirados) e **voluntário** (painel, stock, doações, entregas, desperdício e inscrição em turnos).

## Technical constraints
- The implementation must use the supplied database schema.
- Changes to the schema must be justified and propagated to the project artefacts.
- Credentials must not be hard-coded.
- New dependencies must be identified.
- Generated code must be compatible with the versions specified above.
- Violações de regras de negócio em triggers/procedimentos são sinalizadas com `SIGNAL SQLSTATE '45000'` e uma mensagem que indica a regra (ex.: "BR02: ...").
- Em MySQL um trigger não pode alterar a tabela que o disparou; regras que o exijam são implementadas em procedimentos.
- Com o binary log ativo (predefinição do MySQL 8.0), criar triggers/funções com um utilizador sem SUPER exige `log_bin_trust_function_creators = 1` (ver README).
