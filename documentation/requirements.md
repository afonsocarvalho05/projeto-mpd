# Functional Requirements

Identificadores FR01, FR02, ... descrevem comportamento observável do sistema.

## FR01 — Autenticação por papel
**Description:** O sistema deve permitir o login (email e password) e identificar o papel do utilizador (Coordenador ou Voluntário).
**Actor(s):** Todos
**Notes / acceptance condition:** Cada papel vê apenas as funcionalidades que lhe correspondem.

## FR02 — Gerir doadores
**Description:** O sistema deve permitir criar, editar e pesquisar doadores (particulares ou empresas).
**Actor(s):** Coordenador
**Notes / acceptance condition:** Não é possível criar dois doadores com o mesmo NIF.

## FR03 — Gerir produtos e categorias
**Description:** O sistema deve permitir gerir categorias e produtos (nome, categoria, unidade de medida).
**Actor(s):** Coordenador
**Notes / acceptance condition:** Cada produto pertence a exatamente uma categoria.

## FR04 — Registar doação
**Description:** O sistema deve permitir registar uma doação (doador, data, armazém) com um ou mais lotes (produto, quantidade, data de validade).
**Actor(s):** Voluntário, Coordenador
**Notes / acceptance condition:** A doação e os seus lotes são gravados em conjunto; lotes já expirados são recusados (BR09).

## FR05 — Consultar stock
**Description:** O sistema deve mostrar o stock disponível por produto e por armazém, com os lotes e as respetivas datas de validade.
**Actor(s):** Todos
**Notes / acceptance condition:** Lotes com quantidade zero não aparecem no stock disponível.

## FR06 — Gerir instituições beneficiárias
**Description:** O sistema deve permitir criar, editar e desativar instituições beneficiárias.
**Actor(s):** Coordenador
**Notes / acceptance condition:** Não é possível criar duas instituições com o mesmo NIF.

## FR07 — Registar pedido
**Description:** O sistema deve permitir registar um pedido de uma instituição com uma ou mais linhas (produto, quantidade pedida).
**Actor(s):** Coordenador
**Notes / acceptance condition:** Só instituições ativas podem fazer pedidos (BR12).

## FR08 — Registar entrega (FEFO)
**Description:** O sistema deve permitir registar a entrega de um pedido, sugerindo os lotes a usar por ordem de validade e retirando as quantidades de vários lotes.
**Actor(s):** Voluntário, Coordenador
**Notes / acceptance condition:** Operação atómica (procedimento `sp_registar_entrega`): ou todas as linhas de entrega são gravadas e o stock é atualizado, ou nada é alterado. Entrega o que houver em stock: o pedido fica `concluido` se tudo for entregue, ou `parcial` caso contrário. Respeita BR01–BR03, BR07 e BR08.

## FR09 — Registar desperdício
**Description:** O sistema deve permitir registar a perda de quantidades de um lote (expirado, danificado), com o motivo.
**Actor(s):** Voluntário, Coordenador
**Notes / acceptance condition:** A quantidade disponível do lote é reduzida na mesma operação. O coordenador pode também abater de uma só vez todos os lotes expirados (`sp_processar_expirados`).

## FR10 — Gerir voluntários e turnos
**Description:** O sistema deve permitir gerir voluntários, criar turnos por armazém e inscrever voluntários em turnos.
**Actor(s):** Coordenador (gestão), Voluntário (inscrição própria)
**Notes / acceptance condition:** A inscrição é recusada se violar BR04 ou BR06.

## FR11 — Alertas de validade
**Description:** O sistema deve listar os lotes com stock que expiram nos próximos 7 dias.
**Actor(s):** Todos
**Notes / acceptance condition:** Ordenados pela data de validade.

## FR12 — Relatórios de gestão
**Description:** O sistema deve produzir relatórios de desperdício por categoria, distribuição por instituição e doações por doador, filtráveis por período.
**Actor(s):** Coordenador
**Notes / acceptance condition:** Informação agregada a partir de várias tabelas.
