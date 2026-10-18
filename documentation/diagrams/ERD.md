# ERD — Despensa Solidária

Notação: pé-de-galinha (engenharia da informação). `||` = exatamente um, `o|` = zero ou um, `|{` = um ou mais, `o{` = zero ou mais.
O diagrama corresponde exatamente a `data/schema.sql` (15 tabelas). Para uma imagem para o relatório, pode também ser gerado no MySQL Workbench em *Database → Reverse Engineer*.

```mermaid
erDiagram
    CATEGORIA ||--o{ PRODUTO : "classifica"
    DOADOR ||--o{ DOACAO : "faz"
    ARMAZEM ||--o{ DOACAO : "recebe"
    VOLUNTARIO |o--o{ DOACAO : "receciona"
    DOACAO ||--|{ LOTE : "é composta por"
    PRODUTO ||--o{ LOTE : "é armazenado em"
    INSTITUICAO ||--o{ PEDIDO : "faz"
    PEDIDO ||--|{ LINHA_PEDIDO : "contém"
    PRODUTO ||--o{ LINHA_PEDIDO : "é pedido em"
    PEDIDO ||--o{ ENTREGA : "é satisfeito por"
    ARMAZEM ||--o{ ENTREGA : "expede"
    VOLUNTARIO ||--o{ ENTREGA : "é responsável por"
    ENTREGA ||--|{ LINHA_ENTREGA : "contém"
    LOTE ||--o{ LINHA_ENTREGA : "sai em"
    LOTE ||--o{ DESPERDICIO : "perde"
    VOLUNTARIO |o--o{ DESPERDICIO : "regista"
    ARMAZEM ||--o{ TURNO : "tem"
    VOLUNTARIO ||--o{ INSCRICAO_TURNO : "inscreve-se"
    TURNO ||--o{ INSCRICAO_TURNO : "recebe"

    CATEGORIA {
        int id_categoria PK
        varchar nome UK
        varchar descricao
    }
    PRODUTO {
        int id_produto PK
        int id_categoria FK
        varchar nome UK
        enum unidade_medida
    }
    ARMAZEM {
        int id_armazem PK
        varchar nome UK
        varchar morada
        varchar localidade
    }
    VOLUNTARIO {
        int id_voluntario PK
        varchar nome
        varchar email UK
        varchar telefone
        enum perfil
        varchar password_hash
        date data_inscricao
        boolean ativo
    }
    DOADOR {
        int id_doador PK
        enum tipo
        varchar nome
        char nif UK "opcional"
        varchar email
        varchar telefone
        date data_registo
    }
    INSTITUICAO {
        int id_instituicao PK
        varchar nome
        char nif UK
        enum tipo
        varchar morada
        varchar localidade
        varchar email
        varchar telefone
        int num_beneficiarios
        enum estado
    }
    DOACAO {
        int id_doacao PK
        int id_doador FK
        int id_armazem FK
        int id_voluntario FK "opcional"
        date data_doacao
        varchar observacoes
    }
    LOTE {
        int id_lote PK
        int id_doacao FK
        int id_produto FK
        decimal quantidade_inicial
        decimal quantidade_disponivel
        date data_validade
    }
    PEDIDO {
        int id_pedido PK
        int id_instituicao FK
        date data_pedido
        enum estado
        varchar observacoes
    }
    LINHA_PEDIDO {
        int id_pedido PK,FK
        int id_produto PK,FK
        decimal quantidade_pedida
    }
    ENTREGA {
        int id_entrega PK
        int id_pedido FK
        int id_armazem FK
        int id_voluntario FK
        date data_entrega
    }
    LINHA_ENTREGA {
        int id_entrega PK,FK
        int id_lote PK,FK
        decimal quantidade
    }
    DESPERDICIO {
        int id_desperdicio PK
        int id_lote FK
        int id_voluntario FK "opcional"
        date data_registo
        decimal quantidade
        enum motivo
        varchar observacoes
    }
    TURNO {
        int id_turno PK
        int id_armazem FK
        date data_turno
        time hora_inicio
        time hora_fim
        tinyint vagas
    }
    INSCRICAO_TURNO {
        int id_voluntario PK,FK
        int id_turno PK,FK
        datetime data_inscricao
    }
```

## Relacionamentos e decisões de modelação

| Relacionamento | Cardinalidade | Notas |
|---|---|---|
| Categoria — Produto | 1:N, produto obrigatório numa categoria | |
| Doador — Doação | 1:N | Um doador pode estar registado sem doações (ex.: Pedro Almeida). |
| Doação — Lote | 1:N, **a doação tem pelo menos um lote** | O lote é a unidade de stock: um produto, uma quantidade e uma validade. |
| Armazém — Doação | 1:N | O armazém de um lote é o da sua doação (não é repetido no lote — 3FN). |
| Pedido — Produto | **N:M** via `LINHA_PEDIDO` | Os pedidos são feitos por produto, não por lote. |
| Entrega — Lote | **N:M** via `LINHA_ENTREGA` | Uma entrega retira de vários lotes; um lote pode sair em várias entregas. |
| Pedido — Entrega | 1:N | Um pedido pode ser satisfeito em várias entregas (estado `parcial`). |
| Voluntário — Turno | **N:M** via `INSCRICAO_TURNO` | Limitada por BR04 (3/semana) e BR06 (vagas). |
| Voluntário — Doação / Desperdício | 0..1:N (participação opcional) | Doações ao balcão e abates automáticos não têm voluntário. |

**Atributo derivado não guardado:** o stock de um produto não é uma coluna. É calculado como a soma de `LOTE.quantidade_disponivel` (view `vw_stock_disponivel`, função `fn_stock_disponivel`). Assim não podem existir dois valores de stock contraditórios.

**Atributo derivado guardado (exceção justificada):** `LOTE.quantidade_disponivel` podia ser calculado como `quantidade_inicial − Σ entregas − Σ desperdício`. É guardado porque a seleção FEFO e os alertas o consultam constantemente, e é mantido **apenas** por triggers (`trg_linha_entrega_ai`, `trg_desperdicio_ai`), com `CHECK` que impede valores negativos.
