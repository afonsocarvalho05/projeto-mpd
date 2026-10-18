# Application

Protótipo Flask que usa a base de dados `despensa_solidaria` entregue em `../data`. Instruções de instalação e execução no [README da raiz](../README.md).

| Ficheiro | Conteúdo |
|---|---|
| `app.py` | Rotas e lógica de ecrã (login, painel, stock, doações, doadores, instituições, pedidos/entregas, desperdício, turnos, relatórios) |
| `db.py` | Ligação MySQL (PyMySQL) a partir do `.env` e tradução dos erros da BD em mensagens |
| `templates/` | Páginas Jinja2 |
| `static/style.css` | Estilos |
| `requirements.txt` | Dependências com versões fixas |

| Ecrã (rota) | Requisitos | Objetos da BD usados |
|---|---|---|
| `/login` | FR01 | `voluntario` |
| `/` Painel | FR09, FR11 | `vw_lotes_a_expirar`, `vw_lotes_expirados`, `sp_processar_expirados` |
| `/stock`, `/stock/produto/<id>` | FR05 | `vw_stock_disponivel`, `lote` |
| `/doacoes`, `/doacoes/nova` | FR04 | `doacao`, `lote` (transação na aplicação), `trg_lote_bi` |
| `/doadores` | FR02 | `doador` |
| `/instituicoes` | FR06 | `instituicao` |
| `/pedidos`, `/pedidos/novo`, `/pedidos/<id>` | FR07, FR08 | `vw_pedido_progresso`, `fn_stock_disponivel`, `sp_registar_entrega`, `trg_pedido_bi` |
| `/desperdicio` | FR09 | `desperdicio`, `trg_desperdicio_*` |
| `/turnos` | FR10 | `turno`, `inscricao_turno`, `trg_inscricao_turno_bi` |
| `/relatorios` | FR12 | agregações sobre entregas, desperdício e doações |
