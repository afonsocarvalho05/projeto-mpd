"""Acesso à base de dados MySQL (despensa_solidaria) com PyMySQL.

As credenciais vêm do ficheiro .env na raiz do projeto (nunca do código).
"""
import os
from pathlib import Path

import pymysql
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def ligar():
    """Abre uma ligação nova. autocommit=False: cada operação decide quando faz commit."""
    return pymysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.getenv("DB_NAME", "despensa_solidaria"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )


def consultar(sql, params=None):
    """Executa um SELECT e devolve a lista de linhas (dicionários)."""
    con = ligar()
    try:
        with con.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()
    finally:
        con.close()


def consultar_um(sql, params=None):
    linhas = consultar(sql, params)
    return linhas[0] if linhas else None


def executar(sql, params=None):
    """Executa uma única instrução de escrita numa transação; devolve o id inserido."""
    con = ligar()
    try:
        with con.cursor() as cur:
            cur.execute(sql, params)
            novo_id = cur.lastrowid
        con.commit()
        return novo_id
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()


def mensagem_erro(exc):
    """Converte um erro do MySQL numa mensagem legível para o utilizador.

    Os erros de regra de negócio (SIGNAL '45000', código 1644) já trazem o texto "BRxx: ...".
    """
    if isinstance(exc, pymysql.err.MySQLError) and len(exc.args) >= 2:
        codigo, texto = exc.args[0], exc.args[1]
        if codigo == 1644:
            return texto
        if codigo == 1062:
            return f"Registo duplicado: {texto}"
        if codigo == 3819:
            return f"Valor inválido (restrição CHECK): {texto}"
        if codigo in (1451, 1452):
            return "Operação recusada por integridade referencial (registo relacionado inexistente ou em uso)."
        return f"Erro da base de dados ({codigo}): {texto}"
    return str(exc)
