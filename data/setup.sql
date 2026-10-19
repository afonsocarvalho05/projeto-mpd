-- Cria a base de dados completa. Executar a partir da raiz do projeto:
--   mysql -u <user> -p -e "source data/setup.sql"
SET NAMES utf8mb4;   -- garante os acentos com qualquer cliente (ex.: consola Windows em cp850)
source data/schema.sql
source data/programmable_objects.sql
source data/views.sql
source data/seed.sql
