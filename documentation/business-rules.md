# Business Rules

Identificadores BR01, BR02, ... descrevem regras impostas pelo domínio.

## BR01 — Nenhum lote expirado é entregue
**Rule:** Um lote só pode ser incluído numa entrega se a sua data de validade for igual ou posterior à data da entrega.
**Rationale / domain meaning:** Segurança alimentar: não se distribuem produtos fora de prazo.

## BR02 — Stock nunca negativo
**Rule:** A quantidade disponível de um lote nunca pode ser negativa; não se pode retirar de um lote mais do que a quantidade disponível.
**Rationale / domain meaning:** Não se pode entregar ou desperdiçar o que não existe.

## BR03 — Saída por FEFO
**Rule:** Numa entrega, para cada produto, os lotes devem ser usados por ordem crescente de data de validade (primeiro a expirar, primeiro a sair).
**Rationale / domain meaning:** Minimiza o desperdício por expiração.

## BR04 — Máximo de turnos por voluntário
**Rule:** Um voluntário não pode estar inscrito em mais de 3 turnos na mesma semana (semana ISO, de segunda a domingo). Voluntários inativos não se inscrevem.
**Rationale / domain meaning:** Distribui o esforço e evita sobrecarga de voluntários.

## BR05 — Lote pertence a uma doação e a um produto
**Rule:** Cada lote pertence a exatamente uma doação, um produto e — através da doação — um armazém, e tem quantidade inicial maior que zero.
**Rationale / domain meaning:** Garante a rastreabilidade da origem de cada produto em stock.

## BR06 — Capacidade do turno
**Rule:** O número de voluntários inscritos num turno não pode exceder as vagas do turno, e um voluntário não pode inscrever-se duas vezes no mesmo turno.
**Rationale / domain meaning:** Cada turno tem um número de lugares definido pelo armazém.

## BR07 — Quantidade entregue não excede a pedida
**Rule:** A quantidade total entregue de um produto num pedido não pode exceder a quantidade pedida desse produto.
**Rationale / domain meaning:** Distribuição justa entre instituições.

## BR08 — Lotes do armazém de saída
**Rule:** Os lotes usados numa entrega têm de estar no armazém de onde a entrega sai e ter sido recebidos (data da doação) até à data da entrega.
**Rationale / domain meaning:** Uma entrega é preparada fisicamente num único armazém.

## BR09 — Não se aceitam produtos expirados
**Rule:** A data de validade de um lote tem de ser posterior à data da doação.
**Rationale / domain meaning:** Produtos já expirados não entram em stock.

## BR10 — Desperdício reduz o stock
**Rule:** Ao registar desperdício de um lote, a quantidade disponível do lote é reduzida na mesma quantidade; a quantidade desperdiçada é maior que zero.
**Rationale / domain meaning:** O stock reflete as perdas reais e permite medir o desperdício.

## BR11 — Identificação única
**Rule:** O NIF de doadores e de instituições é único; nomes de categorias e de produtos são únicos.
**Rationale / domain meaning:** Evita registos duplicados.

## BR12 — Só instituições ativas fazem pedidos
**Rule:** Apenas instituições no estado "ativa" podem ter novos pedidos.
**Rationale / domain meaning:** Instituições suspensas ou encerradas não recebem distribuição.
