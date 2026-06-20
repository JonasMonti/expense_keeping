"""Gestão de Despesas — aplicação Streamlit numa única página (web e telemóvel)."""
from __future__ import annotations

import datetime as dt
import html
from decimal import Decimal, InvalidOperation

import streamlit as st

from src import charts, repository as repo, ui
from src.config import CURRENCY
from src.database import init_db

st.set_page_config(
    page_title="As Minhas Despesas",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="collapsed",
)

init_db()
ui.inject_css()

MESES_PT = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]


def category_lookup() -> dict[str, int]:
    return {f"{c.icon} {c.name}": c.id for c in repo.list_categories()}


# --------------------------------------------------------------------------- #
# Modais
# --------------------------------------------------------------------------- #
@st.dialog("Registar despesa")
def dialog_add_expense() -> None:
    cats = category_lookup()
    if not cats:
        st.warning("Cria primeiro uma categoria em **Gerir categorias**.")
        return

    with st.form("nova_despesa", clear_on_submit=False):
        valor_str = st.text_input("Valor", placeholder="12,50")
        categoria = st.selectbox("Categoria", list(cats.keys()))
        data = st.date_input("Data", value=dt.date.today(), format="DD/MM/YYYY")
        descricao = st.text_input("Descrição", placeholder="opcional — ex: almoço")
        ok = st.form_submit_button("💾", use_container_width=True, type="primary")

    if ok:
        try:
            valor = Decimal(valor_str.replace(",", ".").strip())
        except (InvalidOperation, AttributeError):
            st.error("Valor inválido. Escreve um número, ex: 12,50.")
            return
        if valor <= 0:
            st.error("O valor tem de ser maior que zero.")
            return
        repo.add_expense(valor, cats[categoria], data, descricao)
        st.rerun()


@st.dialog("Gerir categorias", width="large")
def dialog_categorias() -> None:
    st.caption("As cores são usadas nos gráficos.")
    with st.form("nova_categoria", clear_on_submit=True):
        c1, c2, c3, c4 = st.columns([4, 1, 1, 2], vertical_alignment="bottom")
        nome = c1.text_input("Nova categoria")
        icon = c2.text_input("Emoji", value="💸", max_chars=4)
        cor = c3.color_picker("Cor", value="#0F7B66")
        if c4.form_submit_button("➕", use_container_width=True, type="primary") and nome.strip():
            repo.add_category(nome, cor, icon)
            st.rerun()

    st.divider()
    for cat in repo.list_categories():
        c1, c2, c3, c4, c5 = st.columns([1, 4, 2, 2, 1], vertical_alignment="center")
        c1.markdown(
            f'<div class="exp-chip" style="background:{cat.color}22">{cat.icon}</div>',
            unsafe_allow_html=True,
        )
        novo_nome = c2.text_input("Nome", value=cat.name, key=f"n_{cat.id}", label_visibility="collapsed")
        nova_cor = c3.color_picker("Cor", value=cat.color, key=f"c_{cat.id}", label_visibility="collapsed")
        if c4.button("💾", key=f"s_{cat.id}", use_container_width=True, help="Guardar"):
            repo.update_category(cat.id, novo_nome, nova_cor, cat.icon)
            st.rerun()
        if c5.button("🗑️", key=f"d_{cat.id}", help="Eliminar"):
            if repo.category_has_expenses(cat.id):
                st.warning(f"«{cat.name}» tem despesas associadas e não pode ser eliminada.")
            else:
                repo.delete_category(cat.id)
                st.rerun()


# --------------------------------------------------------------------------- #
# Cabeçalho: marca, período e ações
# --------------------------------------------------------------------------- #
def header() -> tuple[int, int]:
    hoje = dt.date.today()
    anos = repo.available_years() or [hoje.year]
    if hoje.year not in anos:
        anos = sorted(set(anos + [hoje.year]), reverse=True)

    titulo, sel_mes, sel_ano, b_add, b_cat = st.columns(
        [5, 2, 1.3, 1, 1], vertical_alignment="bottom"
    )
    titulo.markdown(
        '<div class="brand"><span class="dot">€</span> As Minhas Despesas</div>',
        unsafe_allow_html=True,
    )
    mes = sel_mes.selectbox(
        "Mês", list(range(1, 13)), index=hoje.month - 1,
        format_func=lambda m: MESES_PT[m - 1], label_visibility="collapsed",
    )
    ano = sel_ano.selectbox(
        "Ano", anos, index=anos.index(hoje.year) if hoje.year in anos else 0,
        label_visibility="collapsed",
    )
    if b_add.button("➕", use_container_width=True, type="primary", help="Nova despesa"):
        dialog_add_expense()
    if b_cat.button("🏷️", use_container_width=True, help="Gerir categorias"):
        dialog_categorias()
    return ano, mes


# --------------------------------------------------------------------------- #
# Dashboard do mês + ano
# --------------------------------------------------------------------------- #
def dashboard(ano: int, mes: int) -> None:
    total = repo.total_for_month(ano, mes)
    by_cat = repo.totals_by_category(ano, mes)
    diario = repo.daily_totals(ano, mes)
    despesas = repo.list_expenses(ano, mes)
    year_rows = repo.monthly_totals_for_year(ano)
    year_sum = sum(r["total"] for r in year_rows)

    # ---- resumo do mês ----
    etiqueta = f"Gasto em {MESES_PT[mes - 1]} de {ano}"
    if total > 0:
        media_dia = total / len(diario) if diario else 0
        top = by_cat[0] if by_cat else None
        stats = [
            f"<b>{len(despesas)}</b> despesas",
            f"média {ui.money_html(media_dia)}/dia ativo",
        ]
        if top:
            stats.append(f"maior: <b>{top['icon']} {html.escape(top['category'])}</b>")
        ui.hero(etiqueta, total, stats)
    else:
        ui.hero(etiqueta, 0, ["ainda sem despesas este mês"])

    # ---- evolução do ano inteiro ----
    if year_sum > 0:
        ui.section(f"Gastos por mês em {ano}")
        st.plotly_chart(charts.year_line(year_rows, mes, CURRENCY),
                        use_container_width=True, config={"displayModeBar": False})

    if total == 0:
        st.info('Sem despesas neste mês. Carrega em **＋ Nova despesa** para adicionar.')
        return

    # ---- detalhe do mês ----
    left, right = st.columns([1, 1], gap="large")
    with left:
        ui.section("Repartição por categoria")
        st.plotly_chart(charts.donut_by_category(by_cat, total, CURRENCY),
                        use_container_width=True, config={"displayModeBar": False})
    with right:
        ui.section("Onde gastaste mais")
        ui.category_list(by_cat, total)

    historico(despesas)


def historico(despesas: list[dict]) -> None:
    st.write("")
    ui.section(f"Histórico · {len(despesas)} despesas")
    for d in despesas:
        row, btn = st.columns([10, 1], vertical_alignment="center")
        desc = f'<span class="exp-desc"> — {html.escape(d["description"])}</span>' if d["description"] else ""
        row.markdown(
            f'<div class="exp-row">'
            f'<span class="exp-date">{d["spent_on"].strftime("%d/%m/%Y")}</span>'
            f'<span class="exp-chip" style="background:{d["color"]}22">{d["icon"]}</span>'
            f'<span class="exp-main"><span class="exp-cat">{html.escape(d["category"])}</span>{desc}</span>'
            f'<span class="exp-amt">{ui.money_html(d["amount"])}</span>'
            f"</div>",
            unsafe_allow_html=True,
        )
        if btn.button("🗑️", key=f"del_{d['id']}", help="Eliminar"):
            repo.delete_expense(d["id"])
            st.rerun()


# --------------------------------------------------------------------------- #
# Página única
# --------------------------------------------------------------------------- #
ano, mes = header()
st.divider()
dashboard(ano, mes)
