# Despensa Solidária

Base de dados relacional e protótipo web para a gestão de um banco alimentar (IPSS fictícia): doações com lotes e prazos de validade, stock por armazém, pedidos de instituições satisfeitos por ordem **FEFO** (primeiro a expirar, primeiro a sair), registo de desperdício e turnos de voluntários.

Projeto da unidade curricular de Modelação e Preparação de Dados.

## Estrutura

```
data/              schema.sql, programmable_objects.sql, views.sql, seed.sql, queries.sql, tests.sql
application/       protótipo Flask (app.py, db.py, templates/, static/, requirements.txt)
documentation/     project-brief, requirements, business-rules, technical-stack, data-dictionary.csv,
                   ai-use-summary, diagrams/ERD.md, mockups/, screenshots/, test-results.txt
```

Para além da estrutura base foram acrescentados: `data/tests.sql` (testes positivos e negativos), `documentation/test-results.txt` (resultado dos testes) e `documentation/screenshots/` (ecrãs do protótipo).

## Pré-requisitos

| Ferramenta | Versão |
|---|---|
| MySQL Community Server | 8.0.16 ou superior (testado em 8.0.46) |
| Python | 3.10 ou superior (testado em 3.14.7) |
| MySQL Workbench (opcional) | 8.0 |

## 1. Base de dados

### 1.1 Criar a base de dados e um utilizador (uma vez, como root)

No MySQL Workbench ou na consola `mysql -u root -p`, trocando `<password>` por uma password à escolha:

```sql
CREATE DATABASE IF NOT EXISTS despensa_solidaria CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'despensa_app'@'localhost' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON despensa_solidaria.* TO 'despensa_app'@'localhost';
-- O MySQL 8 tem o binary log ativo: sem isto, um utilizador sem SUPER não cria triggers nem funções (erro 1419).
SET PERSIST log_bin_trust_function_creators = 1;
```

### 1.2 Criar os objetos e os dados (sempre por esta ordem)

Na raiz do projeto, com o utilizador criado acima ([data/setup.sql](data/setup.sql) executa `schema.sql` → `programmable_objects.sql` → `views.sql` → `seed.sql`):

```bash
mysql -u despensa_app -p -e "source data/setup.sql"
```

Ou abrir e executar os 4 ficheiros, por essa ordem, no MySQL Workbench.

> Windows: se o comando `mysql` não for reconhecido, usar o caminho completo `"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"` (em PowerShell, precedido de `&`) ou acrescentar essa pasta ao PATH.

A ordem difere da do template (o seed vem no fim) porque **as entregas e o desperdício do seed passam pelos triggers e pelo procedimento FEFO**: assim o stock dos dados de exemplo é calculado pela própria base de dados. Correr de novo os 4 ficheiros repõe a base de dados no estado inicial (`schema.sql` começa com `DROP DATABASE`).

As datas do seed são relativas ao dia em que é executado, para que haja sempre lotes a expirar nos próximos 7 dias, lotes expirados e turnos na semana atual.

### 1.3 Consultas e testes

```bash
mysql -u despensa_app -p -t despensa_solidaria -e "source data/queries.sql"
```

```bash
cmd /c "mysql -u despensa_app -p --force -t -v despensa_solidaria < data\tests.sql"
```

(Em macOS/Linux: `mysql -u despensa_app -p --force -t -v despensa_solidaria < data/tests.sql`. No Workbench: ativar *Query → Continue on SQL Script Error*.)

Os testes negativos **devem** terminar em erro (a mensagem esperada está no comentário de cada teste); `--force` faz continuar após cada erro — por isso o ficheiro é passado por redirecionamento (`<`) e não com `source`, que pára no primeiro erro. O resultado de uma execução está em [documentation/test-results.txt](documentation/test-results.txt). Os testes alteram dados: voltar a correr o passo 1.2 depois.

## 2. Aplicação

### 2.1 Configuração

Copiar `.env.example` para `.env` (na raiz do projeto) e preencher `DB_USER`, `DB_PASSWORD` e `FLASK_SECRET_KEY` (qualquer texto longo e aleatório). O `.env` não vai para o Git.

### 2.2 Instalar e executar (Windows PowerShell)

```bash
cd application
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python app.py
```

(Em macOS/Linux: `.venv/bin/python` em vez de `.venv\Scripts\python`.)

Abrir **http://localhost:5000**.

## Credenciais de demonstração

Criadas pelo `seed.sql` (password igual para todos, apenas para teste local): **`Despensa2026`**

| Utilizador | Papel |
|---|---|
| `ana.ribeiro@despensa.test` | coordenador |
| `beatriz.santos@despensa.test` | voluntário (já tem 3 turnos esta semana — bom para mostrar BR04) |
| `hugo.carvalho@despensa.test` | voluntário inativo (login recusado) |

## Demonstração sugerida (≈ 10 min)

1. **Painel** (coordenador): lotes a expirar, lotes expirados, pedidos em aberto.
2. **Stock** → clicar num produto: lotes por ordem FEFO.
3. **Pedidos → #5** → *Registar entrega*: o procedimento escolhe os lotes que expiram primeiro (35, 24, 7) e o pedido fica `concluido`.
4. **Doações → Registar doação** com um lote de validade passada → erro **BR09**, nada é gravado.
5. **Pedidos → Registar pedido** para "Associação Vizinhos Unidos" (suspensa) → erro **BR12**.
6. **Painel → Abater lotes expirados** → os lotes 4 e 6 passam para *Desperdício*.
7. Entrar como **Beatriz** → **Turnos** → inscrever num 4.º turno da semana → erro **BR04**.
8. **Relatórios**: desperdício por categoria, distribuição por instituição, doações por doador, evolução mensal.
