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
- Language:
- Version:
- Framework:
- Version:

## Database access
- Library / ORM:
- Driver:

## Frontend / UI
- Technology:
- Version:

## Runtime / package management
- Runtime:
- Package manager:

## Architecture
Describe the main architecture and how the application communicates with the database.

## Authentication / roles
Describe only if applicable.

## Technical constraints
- The implementation must use the supplied database schema.
- Changes to the schema must be justified and propagated to the project artefacts.
- Credentials must not be hard-coded.
- New dependencies must be identified.
- Generated code must be compatible with the versions specified above.
- Violações de regras de negócio em triggers/procedimentos são sinalizadas com `SIGNAL SQLSTATE '45000'` e uma mensagem que indica a regra (ex.: "BR02: ...").
- Em MySQL um trigger não pode alterar a tabela que o disparou; regras que o exijam são implementadas em procedimentos.
