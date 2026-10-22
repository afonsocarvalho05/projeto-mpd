# Project Brief

## Project title
Despensa Solidária — Sistema de Gestão de Doações e Stock de um Banco Alimentar

## Area / Theme
Solidariedade social — gestão de doações alimentares, stock com prazo de validade e distribuição por instituições (IPSS fictícia).

## Problem
Uma IPSS recebe doações de produtos alimentares com prazo de validade e distribui-os por instituições beneficiárias. Atualmente o controlo é feito em folhas de cálculo, o que provoca:
- produtos que expiram em armazém porque ninguém sabe que estão prestes a caducar;
- desconhecimento do stock real por produto e por armazém;
- saída de lotes mais recentes antes de lotes mais antigos;
- entregas de produtos já expirados ou de quantidades que não existem em stock;
- escalas de voluntários desequilibradas;
- falta de indicadores (desperdício, distribuição por instituição, origem das doações).

## Objective
Desenvolver uma base de dados relacional e um protótipo funcional que permitam registar doações e respetivos lotes, controlar o stock por validade, satisfazer pedidos de instituições segundo a regra FEFO (primeiro a expirar, primeiro a sair), gerir os turnos de voluntários e produzir relatórios de desperdício e distribuição.

## Users / Actors
- **Coordenador:** gere doadores, produtos, armazéns, instituições, pedidos e turnos; consulta relatórios.
- **Voluntário:** regista doações recebidas, prepara entregas, regista desperdício e inscreve-se em turnos.

## Scope
### Included
- Doadores (particulares e empresas) e doações.
- Produtos, categorias e lotes com data de validade.
- Stock por produto e por armazém, calculado a partir dos lotes.
- Instituições beneficiárias, pedidos e entregas.
- Seleção de lotes por FEFO nas entregas.
- Registo de desperdício (lotes expirados ou danificados).
- Voluntários, turnos e inscrições em turnos.
- Relatórios: desperdício por categoria, produtos a expirar, distribuição por instituição, doações por doador.

### Excluded
- Doações monetárias e contabilidade.
- Logística de transporte (rotas, viaturas) e transferências de stock entre armazéns.
- Gestão de famílias/beneficiários finais das instituições.
- Emissão de recibos fiscais de doação.
- Autenticação segura de nível de produção (o protótipo não usa passwords: escolhe-se o utilizador, que define o papel).

## Main data to manage
- Doadores, doações
- Categorias, produtos, lotes
- Armazéns
- Instituições beneficiárias, pedidos e linhas de pedido
- Entregas e linhas de entrega (lote + quantidade)
- Registos de desperdício
- Voluntários, turnos e inscrições em turnos

## Main operations
- Registar uma doação com um ou mais lotes.
- Consultar o stock e os lotes a expirar.
- Registar um pedido de uma instituição.
- Registar uma entrega: retirar quantidades de vários lotes, por FEFO, numa única transação.
- Registar desperdício de lotes expirados ou danificados.
- Criar turnos e inscrever voluntários.
- Consultar relatórios.

## Initial assumptions / constraints
- A IPSS, os nomes e os dados são fictícios.
- Cada lote corresponde a um produto recebido numa doação, com uma única data de validade; o armazém do lote é o armazém onde a doação foi recebida (não há transferências entre armazéns).
- O stock de um produto é a soma das quantidades disponíveis dos seus lotes.
- Os pedidos são feitos por produto; as entregas retiram quantidades de lotes concretos.
- O modelo, os requisitos e as regras podem evoluir durante o projeto, mantendo os artefactos coerentes entre si.
