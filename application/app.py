"""Despensa Solidária — protótipo Flask sobre a base de dados MySQL entregue.

Toda a lógica de regras de negócio está na base de dados (CHECK, triggers,
procedimentos). A aplicação limita-se a ler/escrever e a mostrar os erros.
"""
import os
from datetime import date
from functools import wraps

import pymysql
from flask import Flask, flash, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash

import db

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY") or os.urandom(24)


# ---------------------------------------------------------------------------
# Autenticação e papéis (FR01)
# ---------------------------------------------------------------------------

def requer_login(perfil=None):
    def decorador(f):
        @wraps(f)
        def envolvida(*args, **kwargs):
            if "id_voluntario" not in session:
                return redirect(url_for("login"))
            if perfil and session.get("perfil") != perfil:
                flash("Esta funcionalidade é reservada ao coordenador.", "erro")
                return redirect(url_for("painel"))
            return f(*args, **kwargs)
        return envolvida
    return decorador


@app.context_processor
def contexto_global():
    return {"utilizador": session.get("nome"), "perfil": session.get("perfil"), "hoje": date.today()}


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        v = db.consultar_um(
            "SELECT id_voluntario, nome, perfil, password_hash, ativo FROM voluntario WHERE email = %s",
            (request.form["email"].strip(),))
        if v and v["ativo"] and check_password_hash(v["password_hash"], request.form["password"]):
            session.update(id_voluntario=v["id_voluntario"], nome=v["nome"], perfil=v["perfil"])
            return redirect(url_for("painel"))
        flash("Email ou password inválidos, ou utilizador inativo.", "erro")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


# ---------------------------------------------------------------------------
# Painel (FR11) e abate de expirados (FR09)
# ---------------------------------------------------------------------------

@app.route("/")
@requer_login()
def painel():
    indicadores = db.consultar_um("""
        SELECT (SELECT COUNT(*) FROM vw_lotes_a_expirar)                                   AS a_expirar,
               (SELECT COUNT(*) FROM vw_lotes_expirados)                                   AS expirados,
               (SELECT COUNT(*) FROM pedido WHERE estado IN ('pendente','parcial'))        AS pedidos_abertos,
               (SELECT COUNT(*) FROM turno t
                 WHERE t.data_turno >= CURRENT_DATE
                   AND t.vagas <= (SELECT COUNT(*) FROM inscricao_turno i WHERE i.id_turno = t.id_turno)) AS turnos_cheios
    """)
    a_expirar = db.consultar("SELECT * FROM vw_lotes_a_expirar ORDER BY data_validade, produto")
    expirados = db.consultar("SELECT * FROM vw_lotes_expirados ORDER BY data_validade")
    pedidos = db.consultar("""
        SELECT pe.id_pedido, i.nome AS instituicao, pe.data_pedido, pe.estado
          FROM pedido pe JOIN instituicao i ON i.id_instituicao = pe.id_instituicao
         WHERE pe.estado IN ('pendente','parcial') ORDER BY pe.data_pedido""")
    return render_template("painel.html", ind=indicadores, a_expirar=a_expirar,
                           expirados=expirados, pedidos=pedidos)


@app.route("/desperdicio/expirados", methods=["POST"])
@requer_login("coordenador")
def processar_expirados():
    con = db.ligar()
    try:
        with con.cursor() as cur:
            cur.callproc("sp_processar_expirados", (date.today(), 0))
            cur.execute("SELECT @_sp_processar_expirados_1 AS n")
            n = cur.fetchone()["n"]
        con.commit()
        flash(f"{n} lote(s) expirado(s) abatido(s) como desperdício.", "ok")
    except pymysql.err.MySQLError as e:
        con.rollback()
        flash(db.mensagem_erro(e), "erro")
    finally:
        con.close()
    return redirect(url_for("painel"))


# ---------------------------------------------------------------------------
# Stock (FR05)
# ---------------------------------------------------------------------------

@app.route("/stock")
@requer_login()
def stock():
    id_armazem = request.args.get("armazem", type=int)
    pesquisa = request.args.get("q", "").strip()
    sql = "SELECT * FROM vw_stock_disponivel WHERE 1=1"
    params = []
    if id_armazem:
        sql += " AND id_armazem = %s"
        params.append(id_armazem)
    if pesquisa:
        sql += " AND (produto LIKE %s OR categoria LIKE %s)"
        params += [f"%{pesquisa}%", f"%{pesquisa}%"]
    sql += " ORDER BY armazem, categoria, produto"
    linhas = db.consultar(sql, params)
    armazens = db.consultar("SELECT id_armazem, nome FROM armazem ORDER BY nome")
    return render_template("stock.html", linhas=linhas, armazens=armazens,
                           id_armazem=id_armazem, q=pesquisa)


@app.route("/stock/produto/<int:id_produto>")
@requer_login()
def lotes_produto(id_produto):
    produto = db.consultar_um("SELECT * FROM produto WHERE id_produto = %s", (id_produto,))
    lotes = db.consultar("""
        SELECT l.id_lote, a.nome AS armazem, dr.nome AS doador, dc.data_doacao,
               l.quantidade_inicial, l.quantidade_disponivel, l.data_validade,
               l.data_validade < CURRENT_DATE AS expirado
          FROM lote l
          JOIN doacao dc ON dc.id_doacao = l.id_doacao
          JOIN doador dr ON dr.id_doador = dc.id_doador
          JOIN armazem a ON a.id_armazem = dc.id_armazem
         WHERE l.id_produto = %s
         ORDER BY a.nome, l.data_validade, l.id_lote""", (id_produto,))
    return render_template("lotes_produto.html", produto=produto, lotes=lotes)


# ---------------------------------------------------------------------------
# Doações (FR04) — doação + lotes numa única transação
# ---------------------------------------------------------------------------

@app.route("/doacoes")
@requer_login()
def doacoes():
    linhas = db.consultar("""
        SELECT dc.id_doacao, dc.data_doacao, dr.nome AS doador, a.nome AS armazem,
               v.nome AS rececionado_por, COUNT(l.id_lote) AS num_lotes,
               GROUP_CONCAT(p.nome ORDER BY p.nome SEPARATOR ', ') AS produtos
          FROM doacao dc
          JOIN doador dr  ON dr.id_doador  = dc.id_doador
          JOIN armazem a  ON a.id_armazem  = dc.id_armazem
          LEFT JOIN voluntario v ON v.id_voluntario = dc.id_voluntario
          JOIN lote l     ON l.id_doacao   = dc.id_doacao
          JOIN produto p  ON p.id_produto  = l.id_produto
         GROUP BY dc.id_doacao, dc.data_doacao, dr.nome, a.nome, v.nome
         ORDER BY dc.data_doacao DESC, dc.id_doacao DESC""")
    return render_template("doacoes.html", linhas=linhas)


@app.route("/doacoes/nova", methods=["GET", "POST"])
@requer_login()
def doacao_nova():
    if request.method == "POST":
        lotes = [(p, q, v) for p, q, v in zip(request.form.getlist("produto"),
                                              request.form.getlist("quantidade"),
                                              request.form.getlist("validade")) if p and q and v]
        if not lotes:
            flash("Indique pelo menos um lote (produto, quantidade e validade).", "erro")
        else:
            con = db.ligar()
            try:
                with con.cursor() as cur:
                    cur.execute("""INSERT INTO doacao (id_doador, id_armazem, id_voluntario, data_doacao, observacoes)
                                   VALUES (%s, %s, %s, %s, %s)""",
                                (request.form["doador"], request.form["armazem"], session["id_voluntario"],
                                 request.form["data"], request.form.get("observacoes") or None))
                    id_doacao = cur.lastrowid
                    for produto, quantidade, validade in lotes:
                        cur.execute("""INSERT INTO lote (id_doacao, id_produto, quantidade_inicial,
                                                         quantidade_disponivel, data_validade)
                                       VALUES (%s, %s, %s, %s, %s)""",
                                    (id_doacao, produto, quantidade, quantidade, validade))
                con.commit()   # doação e lotes ficam gravados juntos...
                flash(f"Doação #{id_doacao} registada com {len(lotes)} lote(s).", "ok")
                return redirect(url_for("doacoes"))
            except pymysql.err.MySQLError as e:
                con.rollback()  # ...ou nada fica gravado
                flash(db.mensagem_erro(e), "erro")
            finally:
                con.close()
    return render_template("doacao_nova.html",
                           doadores=db.consultar("SELECT id_doador, nome FROM doador ORDER BY nome"),
                           armazens=db.consultar("SELECT id_armazem, nome FROM armazem ORDER BY nome"),
                           produtos=db.consultar("SELECT id_produto, nome, unidade_medida FROM produto ORDER BY nome"))


# ---------------------------------------------------------------------------
# Doadores (FR02) e instituições (FR06)
# ---------------------------------------------------------------------------

@app.route("/doadores", methods=["GET", "POST"])
@requer_login("coordenador")
def doadores():
    if request.method == "POST":
        f = request.form
        valores = (f["tipo"], f["nome"].strip(), f.get("nif") or None, f.get("email") or None, f.get("telefone") or None)
        try:
            if f.get("id_doador"):
                db.executar("UPDATE doador SET tipo=%s, nome=%s, nif=%s, email=%s, telefone=%s WHERE id_doador=%s",
                            valores + (f["id_doador"],))
                flash("Doador atualizado.", "ok")
            else:
                db.executar("INSERT INTO doador (tipo, nome, nif, email, telefone) VALUES (%s,%s,%s,%s,%s)", valores)
                flash("Doador criado.", "ok")
            return redirect(url_for("doadores"))
        except pymysql.err.MySQLError as e:
            flash(db.mensagem_erro(e), "erro")
    pesquisa = request.args.get("q", "").strip()
    linhas = db.consultar("""
        SELECT dr.*, COUNT(dc.id_doacao) AS num_doacoes, MAX(dc.data_doacao) AS ultima_doacao
          FROM doador dr LEFT JOIN doacao dc ON dc.id_doador = dr.id_doador
         WHERE dr.nome LIKE %s OR dr.nif LIKE %s
         GROUP BY dr.id_doador ORDER BY dr.nome""", (f"%{pesquisa}%", f"%{pesquisa}%"))
    editar = None
    if request.args.get("editar"):
        editar = db.consultar_um("SELECT * FROM doador WHERE id_doador = %s", (request.args["editar"],))
    return render_template("doadores.html", linhas=linhas, editar=editar, q=pesquisa)


@app.route("/instituicoes", methods=["GET", "POST"])
@requer_login("coordenador")
def instituicoes():
    if request.method == "POST":
        f = request.form
        try:
            if f.get("acao") == "estado":
                db.executar("UPDATE instituicao SET estado = %s WHERE id_instituicao = %s",
                            (f["estado"], f["id_instituicao"]))
                flash("Estado da instituição atualizado.", "ok")
            else:
                db.executar("""INSERT INTO instituicao (nome, nif, tipo, morada, localidade, email, telefone, num_beneficiarios)
                               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
                            (f["nome"].strip(), f["nif"].strip(), f["tipo"], f["morada"], f["localidade"],
                             f.get("email") or None, f.get("telefone") or None, f.get("num_beneficiarios") or 0))
                flash("Instituição criada.", "ok")
            return redirect(url_for("instituicoes"))
        except pymysql.err.MySQLError as e:
            flash(db.mensagem_erro(e), "erro")
    linhas = db.consultar("SELECT * FROM instituicao ORDER BY nome")
    return render_template("instituicoes.html", linhas=linhas)


# ---------------------------------------------------------------------------
# Pedidos (FR07) e entregas FEFO (FR08)
# ---------------------------------------------------------------------------

@app.route("/pedidos")
@requer_login()
def pedidos():
    linhas = db.consultar("""
        SELECT pe.id_pedido, pe.data_pedido, pe.estado, i.nome AS instituicao,
               COUNT(*) AS num_produtos,
               SUM(v.quantidade_em_falta) AS em_falta
          FROM pedido pe
          JOIN instituicao i ON i.id_instituicao = pe.id_instituicao
          JOIN vw_pedido_progresso v ON v.id_pedido = pe.id_pedido
         GROUP BY pe.id_pedido, pe.data_pedido, pe.estado, i.nome
         ORDER BY FIELD(pe.estado,'pendente','parcial','concluido','cancelado'), pe.data_pedido DESC""")
    return render_template("pedidos.html", linhas=linhas)


@app.route("/pedidos/novo", methods=["GET", "POST"])
@requer_login("coordenador")
def pedido_novo():
    if request.method == "POST":
        linhas = [(p, q) for p, q in zip(request.form.getlist("produto"), request.form.getlist("quantidade")) if p and q]
        if not linhas:
            flash("Indique pelo menos um produto.", "erro")
        else:
            con = db.ligar()
            try:
                with con.cursor() as cur:
                    cur.execute("INSERT INTO pedido (id_instituicao, data_pedido, observacoes) VALUES (%s, %s, %s)",
                                (request.form["instituicao"], request.form["data"], request.form.get("observacoes") or None))
                    id_pedido = cur.lastrowid
                    cur.executemany("INSERT INTO linha_pedido (id_pedido, id_produto, quantidade_pedida) VALUES (%s, %s, %s)",
                                    [(id_pedido, p, q) for p, q in linhas])
                con.commit()
                flash(f"Pedido #{id_pedido} registado.", "ok")
                return redirect(url_for("pedido", id_pedido=id_pedido))
            except pymysql.err.MySQLError as e:
                con.rollback()
                flash(db.mensagem_erro(e), "erro")
            finally:
                con.close()
    return render_template("pedido_novo.html",
                           instituicoes=db.consultar("SELECT id_instituicao, nome, estado FROM instituicao ORDER BY nome"),
                           produtos=db.consultar("SELECT id_produto, nome, unidade_medida FROM produto ORDER BY nome"))


@app.route("/pedidos/<int:id_pedido>", methods=["GET", "POST"])
@requer_login()
def pedido(id_pedido):
    if request.method == "POST":
        if request.form.get("acao") == "cancelar":
            if session.get("perfil") != "coordenador":
                flash("Só o coordenador pode cancelar pedidos.", "erro")
            else:
                db.executar("UPDATE pedido SET estado = 'cancelado' WHERE id_pedido = %s AND estado = 'pendente'",
                            (id_pedido,))
                flash("Pedido cancelado.", "ok")
            return redirect(url_for("pedido", id_pedido=id_pedido))
        con = db.ligar()
        try:
            with con.cursor() as cur:
                cur.callproc("sp_registar_entrega", (id_pedido, request.form["armazem"],
                                                     request.form["voluntario"], request.form["data"], 0))
                cur.execute("SELECT @_sp_registar_entrega_4 AS id_entrega")
                id_entrega = cur.fetchone()["id_entrega"]
            con.commit()
            flash(f"Entrega #{id_entrega} registada (lotes escolhidos por FEFO).", "ok")
        except pymysql.err.MySQLError as e:
            con.rollback()
            flash(db.mensagem_erro(e), "erro")
        finally:
            con.close()
        return redirect(url_for("pedido", id_pedido=id_pedido))

    cab = db.consultar_um("""SELECT pe.*, i.nome AS instituicao FROM pedido pe
                             JOIN instituicao i ON i.id_instituicao = pe.id_instituicao
                             WHERE pe.id_pedido = %s""", (id_pedido,))
    if not cab:
        flash("Pedido inexistente.", "erro")
        return redirect(url_for("pedidos"))
    progresso = db.consultar("""SELECT v.*, fn_stock_disponivel(v.id_produto, NULL) AS stock_total
                                  FROM vw_pedido_progresso v WHERE v.id_pedido = %s ORDER BY v.produto""", (id_pedido,))
    entregas = db.consultar("""
        SELECT e.id_entrega, e.data_entrega, a.nome AS armazem, vo.nome AS responsavel,
               le.id_lote, p.nome AS produto, le.quantidade, p.unidade_medida, l.data_validade
          FROM entrega e
          JOIN armazem a        ON a.id_armazem     = e.id_armazem
          JOIN voluntario vo    ON vo.id_voluntario = e.id_voluntario
          JOIN linha_entrega le ON le.id_entrega    = e.id_entrega
          JOIN lote l           ON l.id_lote        = le.id_lote
          JOIN produto p        ON p.id_produto     = l.id_produto
         WHERE e.id_pedido = %s
         ORDER BY e.id_entrega DESC, p.nome, l.data_validade""", (id_pedido,))
    return render_template("pedido.html", p=cab, progresso=progresso, entregas=entregas,
                           armazens=db.consultar("SELECT id_armazem, nome FROM armazem ORDER BY nome"),
                           voluntarios=db.consultar("SELECT id_voluntario, nome FROM voluntario WHERE ativo ORDER BY nome"))


# ---------------------------------------------------------------------------
# Desperdício (FR09)
# ---------------------------------------------------------------------------

@app.route("/desperdicio", methods=["GET", "POST"])
@requer_login()
def desperdicio():
    if request.method == "POST":
        f = request.form
        try:
            db.executar("""INSERT INTO desperdicio (id_lote, id_voluntario, data_registo, quantidade, motivo, observacoes)
                           VALUES (%s, %s, CURRENT_DATE, %s, %s, %s)""",
                        (f["lote"], session["id_voluntario"], f["quantidade"], f["motivo"], f.get("observacoes") or None))
            flash("Desperdício registado; o stock do lote foi atualizado.", "ok")
            return redirect(url_for("desperdicio"))
        except pymysql.err.MySQLError as e:
            flash(db.mensagem_erro(e), "erro")
    lotes = db.consultar("""
        SELECT l.id_lote, p.nome AS produto, a.nome AS armazem, l.quantidade_disponivel,
               p.unidade_medida, l.data_validade
          FROM lote l JOIN produto p ON p.id_produto = l.id_produto
          JOIN doacao dc ON dc.id_doacao = l.id_doacao JOIN armazem a ON a.id_armazem = dc.id_armazem
         WHERE l.quantidade_disponivel > 0 ORDER BY p.nome, l.data_validade""")
    registos = db.consultar("""
        SELECT d.*, p.nome AS produto, p.unidade_medida, COALESCE(v.nome, 'automático') AS registado_por
          FROM desperdicio d JOIN lote l ON l.id_lote = d.id_lote
          JOIN produto p ON p.id_produto = l.id_produto
          LEFT JOIN voluntario v ON v.id_voluntario = d.id_voluntario
         ORDER BY d.data_registo DESC, d.id_desperdicio DESC""")
    return render_template("desperdicio.html", lotes=lotes, registos=registos)


# ---------------------------------------------------------------------------
# Turnos (FR10)
# ---------------------------------------------------------------------------

@app.route("/turnos", methods=["GET", "POST"])
@requer_login()
def turnos():
    if request.method == "POST":
        f = request.form
        try:
            if f.get("acao") == "criar":
                if session.get("perfil") != "coordenador":
                    raise PermissionError("Só o coordenador pode criar turnos.")
                db.executar("""INSERT INTO turno (id_armazem, data_turno, hora_inicio, hora_fim, vagas)
                               VALUES (%s, %s, %s, %s, %s)""",
                            (f["armazem"], f["data"], f["inicio"], f["fim"], f["vagas"]))
                flash("Turno criado.", "ok")
            elif f.get("acao") == "sair":
                db.executar("DELETE FROM inscricao_turno WHERE id_voluntario = %s AND id_turno = %s",
                            (session["id_voluntario"], f["turno"]))
                flash("Inscrição removida.", "ok")
            else:
                db.executar("INSERT INTO inscricao_turno (id_voluntario, id_turno) VALUES (%s, %s)",
                            (session["id_voluntario"], f["turno"]))
                flash("Inscrição feita.", "ok")
        except PermissionError as e:
            flash(str(e), "erro")
        except pymysql.err.MySQLError as e:
            flash(db.mensagem_erro(e), "erro")
        return redirect(url_for("turnos"))
    linhas = db.consultar("""
        SELECT t.id_turno, t.data_turno, t.hora_inicio, t.hora_fim, t.vagas, a.nome AS armazem,
               COUNT(it.id_voluntario) AS inscritos,
               MAX(it.id_voluntario = %s) AS eu_inscrito,
               GROUP_CONCAT(v.nome ORDER BY v.nome SEPARATOR ', ') AS voluntarios
          FROM turno t
          JOIN armazem a ON a.id_armazem = t.id_armazem
          LEFT JOIN inscricao_turno it ON it.id_turno = t.id_turno
          LEFT JOIN voluntario v ON v.id_voluntario = it.id_voluntario
         WHERE t.data_turno >= CURRENT_DATE - INTERVAL WEEKDAY(CURRENT_DATE) DAY
         GROUP BY t.id_turno, t.data_turno, t.hora_inicio, t.hora_fim, t.vagas, a.nome
         ORDER BY t.data_turno, t.hora_inicio""", (session["id_voluntario"],))
    meus = db.consultar_um("""
        SELECT COUNT(*) AS n FROM inscricao_turno i JOIN turno t ON t.id_turno = i.id_turno
         WHERE i.id_voluntario = %s AND YEARWEEK(t.data_turno, 3) = YEARWEEK(CURRENT_DATE, 3)""",
                           (session["id_voluntario"],))
    return render_template("turnos.html", linhas=linhas, meus_semana=meus["n"],
                           armazens=db.consultar("SELECT id_armazem, nome FROM armazem ORDER BY nome"))


# ---------------------------------------------------------------------------
# Relatórios (FR12)
# ---------------------------------------------------------------------------

@app.route("/relatorios")
@requer_login("coordenador")
def relatorios():
    inicio = request.args.get("inicio") or date(date.today().year, 1, 1).isoformat()
    fim = request.args.get("fim") or date.today().isoformat()
    periodo = (inicio, fim)
    desperdicio_cat = db.consultar("""
        SELECT c.nome AS categoria, d.motivo, SUM(d.quantidade) AS quantidade, COUNT(*) AS registos
          FROM desperdicio d JOIN lote l ON l.id_lote = d.id_lote
          JOIN produto p ON p.id_produto = l.id_produto JOIN categoria c ON c.id_categoria = p.id_categoria
         WHERE d.data_registo BETWEEN %s AND %s
         GROUP BY c.nome, d.motivo ORDER BY quantidade DESC""", periodo)
    distribuicao = db.consultar("""
        SELECT i.nome AS instituicao, i.num_beneficiarios,
               COUNT(DISTINCT e.id_entrega) AS entregas, COALESCE(SUM(le.quantidade), 0) AS quantidade
          FROM instituicao i
          LEFT JOIN pedido pe ON pe.id_instituicao = i.id_instituicao
          LEFT JOIN entrega e ON e.id_pedido = pe.id_pedido AND e.data_entrega BETWEEN %s AND %s
          LEFT JOIN linha_entrega le ON le.id_entrega = e.id_entrega
         GROUP BY i.id_instituicao, i.nome, i.num_beneficiarios ORDER BY quantidade DESC""", periodo)
    por_doador = db.consultar("""
        SELECT dr.nome, dr.tipo, COUNT(DISTINCT dc.id_doacao) AS doacoes, SUM(l.quantidade_inicial) AS quantidade
          FROM doador dr JOIN doacao dc ON dc.id_doador = dr.id_doador JOIN lote l ON l.id_doacao = dc.id_doacao
         WHERE dc.data_doacao BETWEEN %s AND %s
         GROUP BY dr.id_doador, dr.nome, dr.tipo ORDER BY quantidade DESC""", periodo)
    mensal = db.consultar("""
        SELECT mes, SUM(entradas) AS entradas, SUM(saidas) AS saidas, SUM(perdas) AS perdas FROM (
          SELECT DATE_FORMAT(dc.data_doacao, '%%Y-%%m') AS mes, l.quantidade_inicial AS entradas, 0 AS saidas, 0 AS perdas
            FROM lote l JOIN doacao dc ON dc.id_doacao = l.id_doacao WHERE dc.data_doacao BETWEEN %s AND %s
          UNION ALL
          SELECT DATE_FORMAT(e.data_entrega, '%%Y-%%m'), 0, le.quantidade, 0
            FROM linha_entrega le JOIN entrega e ON e.id_entrega = le.id_entrega WHERE e.data_entrega BETWEEN %s AND %s
          UNION ALL
          SELECT DATE_FORMAT(data_registo, '%%Y-%%m'), 0, 0, quantidade
            FROM desperdicio WHERE data_registo BETWEEN %s AND %s) mov
        GROUP BY mes ORDER BY mes""", periodo * 3)
    return render_template("relatorios.html", inicio=inicio, fim=fim, desperdicio_cat=desperdicio_cat,
                           distribuicao=distribuicao, por_doador=por_doador, mensal=mensal)


if __name__ == "__main__":
    app.run(debug=True, port=5000)
