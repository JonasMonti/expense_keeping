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
# Materializa as receitas recorrentes em falta (mês corrente + catch-up).
repo.generate_due_recurring_incomes()
ui.inject_css()

MESES_PT = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]

# Origens de receita sugeridas no formulário.
FONTES_RECEITA = ["Ordenado", "Subsídio de alimentação", "Extra", "Reembolso", "Outros"]


def category_lookup() -> dict[str, int]:
    return {f"{c.icon} {c.name}": c.id for c in repo.list_categories()}


# Rótulo usado quando um movimento não tem cartão associado.
SEM_CARTAO = "— Sem cartão —"


def card_lookup() -> dict[str, int | None]:
    """Mapa rótulo→id para os seletores de cartão. Inclui a opção «sem cartão»."""
    cards = {f"{c.icon} {c.name}": c.id for c in repo.list_cards()}
    return {SEM_CARTAO: None, **cards}


def card_select(
    label: str, current_id: int | None = None, key: str | None = None
) -> int | None:
    """Selectbox de cartão que devolve o id (ou None). Pré-seleciona `current_id`."""
    opts = card_lookup()
    labels = list(opts.keys())
    index = 0
    if current_id is not None:
        for i, cid in enumerate(opts.values()):
            if cid == current_id:
                index = i
                break
    escolha = st.selectbox(label, labels, index=index, key=key)
    return opts[escolha]


def parse_valor(valor_str: str) -> Decimal | None:
    """'12,50' -> Decimal('12.50'); None se inválido."""
    try:
        return Decimal(valor_str.replace(",", ".").strip())
    except (InvalidOperation, AttributeError):
        return None


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
        cartao_id = card_select("Cartão")
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
        repo.add_expense(valor, cats[categoria], data, descricao, card_id=cartao_id)
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


@st.dialog("Gerir cartões", width="large")
def dialog_cards() -> None:
    st.caption("Cada cartão é uma carteira: saldo = saldo inicial + receitas "
               "atribuídas − despesas atribuídas.")
    with st.form("novo_cartao", clear_on_submit=True):
        c1, c2, c3, c4, c5 = st.columns([4, 1, 1, 2, 2], vertical_alignment="bottom")
        nome = c1.text_input("Novo cartão")
        icon = c2.text_input("Emoji", value="💳", max_chars=4)
        cor = c3.color_picker("Cor", value="#0F7B66")
        saldo_str = c4.text_input("Saldo inicial", value="0")
        if c5.form_submit_button("➕", use_container_width=True, type="primary") and nome.strip():
            saldo = parse_valor(saldo_str) or Decimal("0")
            repo.add_card(nome, cor, icon, float(saldo))
            st.rerun()

    st.divider()
    for card in repo.list_cards():
        c1, c2, c3, c4, c5 = st.columns([1, 4, 2, 2, 1], vertical_alignment="center")
        c1.markdown(
            f'<div class="exp-chip" style="background:{card.color}22">{card.icon}</div>',
            unsafe_allow_html=True,
        )
        novo_nome = c2.text_input("Nome", value=card.name, key=f"cn_{card.id}", label_visibility="collapsed")
        novo_saldo = c3.text_input("Saldo inicial", value=ui.fmt_number(float(card.opening_balance)),
                                   key=f"cb_{card.id}", label_visibility="collapsed")
        if c4.button("💾", key=f"cs_{card.id}", use_container_width=True, help="Guardar"):
            saldo = parse_valor(novo_saldo) or Decimal("0")
            repo.update_card(card.id, novo_nome, card.color, card.icon, float(saldo))
            st.rerun()
        if c5.button("🗑️", key=f"cd_{card.id}", help="Eliminar"):
            if repo.card_has_movements(card.id):
                st.warning(f"«{card.name}» tem movimentos associados e não pode ser eliminado.")
            else:
                repo.delete_card(card.id)
                st.rerun()


@st.dialog("Registar receita")
def dialog_add_income() -> None:
    with st.form("nova_receita", clear_on_submit=False):
        valor_str = st.text_input("Valor", placeholder="1500,00")
        fonte = st.selectbox("Origem", FONTES_RECEITA)
        cartao_id = card_select("Carregar cartão")
        data = st.date_input("Data", value=dt.date.today(), format="DD/MM/YYYY")
        descricao = st.text_input("Descrição", placeholder="opcional — ex: prémio")
        ok = st.form_submit_button("💾", use_container_width=True, type="primary")

    if ok:
        valor = parse_valor(valor_str)
        if valor is None:
            st.error("Valor inválido. Escreve um número, ex: 1500,00.")
            return
        if valor <= 0:
            st.error("O valor tem de ser maior que zero.")
            return
        repo.add_income(valor, fonte, data, descricao, card_id=cartao_id)
        st.rerun()


@st.dialog("Definições", width="large")
def dialog_settings() -> None:
    # ---- saldo inicial ----
    st.markdown("##### Saldo inicial")
    st.caption("O dinheiro que tinhas numa certa data. A app soma receitas e subtrai "
               "despesas a partir daí para mostrar o saldo atual.")
    opening, since = repo.get_opening_balance()
    with st.form("saldo_inicial", clear_on_submit=False):
        c1, c2 = st.columns(2)
        valor_str = c1.text_input("Valor inicial", value=ui.fmt_number(opening))
        data = c2.date_input("A partir de", value=since or dt.date.today(),
                             format="DD/MM/YYYY")
        if st.form_submit_button("💾", use_container_width=True, type="primary"):
            valor = parse_valor(valor_str)
            if valor is None:
                st.error("Valor inválido.")
            else:
                repo.set_opening_balance(float(valor), data)
                st.rerun()

    st.divider()

    # ---- receitas recorrentes ----
    st.markdown("##### Receitas recorrentes")
    st.caption("Criadas automaticamente todos os meses, no dia escolhido "
               "(ordenado, subsídio…).")
    with st.form("nova_recorrente", clear_on_submit=True):
        c1, c2, c3, c4 = st.columns([3, 3, 2, 1], vertical_alignment="bottom")
        v_str = c1.text_input("Valor")
        fonte = c2.selectbox("Origem", FONTES_RECEITA)
        dia = c3.number_input("Dia", min_value=1, max_value=31, value=1, step=1)
        submit_rec = c4.form_submit_button("➕", use_container_width=True, type="primary")
        cartao_id = card_select("Carregar cartão", key="rec_card")
        if submit_rec:
            valor = parse_valor(v_str)
            if valor is None or valor <= 0:
                st.error("Valor inválido.")
            else:
                repo.add_recurring_income(valor, fonte, int(dia), card_id=cartao_id)
                st.rerun()

    for r in repo.list_recurring_incomes():
        c1, c2, c3, c4 = st.columns([5, 2, 2, 1], vertical_alignment="center")
        estado = "" if r["active"] else " · em pausa"
        c1.markdown(
            f'<div class="exp-row" style="border:none;padding:.3rem 0">'
            f'<span class="exp-chip" style="background:#0F7B6622">💶</span>'
            f'<span class="exp-main"><span class="exp-cat">{html.escape(r["source"])}</span>'
            f'<span class="exp-desc"> — dia {r["day_of_month"]}{estado}</span></span>'
            f"</div>",
            unsafe_allow_html=True,
        )
        c2.markdown(ui.money_html(r["amount"]), unsafe_allow_html=True)
        novo_estado = "Pausar" if r["active"] else "Retomar"
        if c3.button(novo_estado, key=f"ri_t_{r['id']}", use_container_width=True):
            repo.update_recurring_income(r["id"], Decimal(str(r["amount"])), r["source"],
                                         r["day_of_month"], r["description"],
                                         not r["active"], card_id=r["card_id"])
            st.rerun()
        if c4.button("🗑️", key=f"ri_d_{r['id']}", help="Eliminar"):
            repo.delete_recurring_income(r["id"])
            st.rerun()


# --------------------------------------------------------------------------- #
# Cabeçalho: marca, período e ações
# --------------------------------------------------------------------------- #
def header() -> tuple[int, int]:
    hoje = dt.date.today()
    anos = repo.available_years() or [hoje.year]
    if hoje.year not in anos:
        anos = sorted(set(anos + [hoje.year]), reverse=True)

    titulo, sel_mes, sel_ano, b_add, b_inc, b_card, b_cat, b_set = st.columns(
        [5, 2, 1.3, 1, 1, 1, 1, 1], vertical_alignment="bottom"
    )
    titulo.markdown(
        '<div class="brand"><span class="dot">€</span> As Minhas Finanças</div>',
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
    if b_add.button("➖", use_container_width=True, type="primary", help="Nova despesa"):
        dialog_add_expense()
    if b_inc.button("➕", use_container_width=True, help="Nova receita"):
        dialog_add_income()
    if b_card.button("💳", use_container_width=True, help="Gerir cartões"):
        dialog_cards()
    if b_cat.button("🏷️", use_container_width=True, help="Gerir categorias"):
        dialog_categorias()
    if b_set.button("⚙️", use_container_width=True, help="Definições · saldo e recorrentes"):
        dialog_settings()
    return ano, mes


# --------------------------------------------------------------------------- #
# Dashboard do mês + ano
# --------------------------------------------------------------------------- #
def dashboard(ano: int, mes: int) -> None:
    total = repo.total_for_month(ano, mes)
    receitas_total = repo.income_total_for_month(ano, mes)
    liquido = receitas_total - total
    by_cat = repo.totals_by_category(ano, mes)
    by_source = repo.incomes_by_source(ano, mes)
    diario = repo.daily_totals(ano, mes)
    despesas = repo.list_expenses(ano, mes)
    receitas = repo.list_incomes(ano, mes)
    year_rows = repo.monthly_totals_for_year(ano)
    year_inc_rows = repo.monthly_income_for_year(ano)
    year_sum = sum(r["total"] for r in year_rows)
    year_inc_sum = sum(r["total"] for r in year_inc_rows)
    saldo = repo.current_balance()
    _, since = repo.get_opening_balance()

    # ---- saldo atual (quanto tens agora) ----
    sinal = "+" if liquido > 0 else ("−" if liquido < 0 else "")
    net_txt = f"{sinal}{ui.fmt_number(abs(liquido))} {CURRENCY}"
    sub = f"Líquido de {MESES_PT[mes - 1]}: {net_txt}"
    if since:
        sub += f" · desde {since.strftime('%d/%m/%Y')}"
    ui.balance_card(saldo, sub)

    # ---- KPIs do mês ----
    ui.kpi_grid([
        ("Receitas do mês", ui.money_html(receitas_total)),
        ("Despesas do mês", ui.money_html(total)),
        ("Líquido do mês", ui.signed_money_html(liquido)),
    ])

    # ---- saldo por cartão (carteiras) ----
    cartoes = [
        c for c in repo.card_balances()
        if c["opening"] or c["incomes"] or c["expenses"]
    ]
    if cartoes:
        ui.section("Saldo por cartão")
        ui.card_balance_grid(cartoes)

    # ---- evolução do ano inteiro (receitas vs despesas) ----
    if year_sum > 0 or year_inc_sum > 0:
        ui.section(f"Receitas e despesas por mês em {ano}")
        st.plotly_chart(
            charts.year_line(year_rows, mes, CURRENCY, income_rows=year_inc_rows),
            use_container_width=True, config={"displayModeBar": False})

    if total == 0 and receitas_total == 0:
        st.info("Sem movimentos neste mês. Usa **➖** para uma despesa "
                "ou **➕** para uma receita.")
        return

    # ---- detalhe das despesas ----
    if total > 0:
        media_dia = total / len(diario) if diario else 0
        top = by_cat[0] if by_cat else None
        bits = f"{len(despesas)} despesas · média {ui.fmt_number(media_dia)} {CURRENCY}/dia ativo"
        if top:
            bits += f" · maior: {top['icon']} {top['category']}"
        left, right = st.columns([1, 1], gap="large")
        with left:
            ui.section("Repartição por categoria")
            st.plotly_chart(charts.donut_by_category(by_cat, total, CURRENCY),
                            use_container_width=True, config={"displayModeBar": False})
        with right:
            ui.section("Onde gastaste mais")
            st.caption(bits)
            ui.category_list(by_cat, total)

    # ---- detalhe das receitas ----
    if receitas_total > 0:
        rows = ui.source_donut_rows(by_source)
        left, right = st.columns([1, 1], gap="large")
        with left:
            ui.section("Receitas por origem")
            st.plotly_chart(charts.donut_by_category(rows, receitas_total, CURRENCY),
                            use_container_width=True, config={"displayModeBar": False})
        with right:
            ui.section("De onde veio")
            ui.category_list(rows, receitas_total)

    if despesas:
        historico(despesas)
    if receitas:
        historico_receitas(receitas)


def historico(despesas: list[dict]) -> None:
    st.write("")
    ui.section(f"Histórico · {len(despesas)} despesas")
    for d in despesas:
        row, btn = st.columns([10, 1], vertical_alignment="center")
        desc = f'<span class="exp-desc"> — {html.escape(d["description"])}</span>' if d["description"] else ""
        tag = (f'<span class="card-tag">{d["card_icon"]} {html.escape(d["card"])}</span>'
               if d.get("card") else "")
        row.markdown(
            f'<div class="exp-row">'
            f'<span class="exp-date">{d["spent_on"].strftime("%d/%m/%Y")}</span>'
            f'<span class="exp-chip" style="background:{d["color"]}22">{d["icon"]}</span>'
            f'<span class="exp-main"><span class="exp-cat">{html.escape(d["category"])}</span>{desc}{tag}</span>'
            f'<span class="exp-amt">{ui.money_html(d["amount"])}</span>'
            f"</div>",
            unsafe_allow_html=True,
        )
        if btn.button("🗑️", key=f"del_{d['id']}", help="Eliminar"):
            repo.delete_expense(d["id"])
            st.rerun()


def historico_receitas(receitas: list[dict]) -> None:
    st.write("")
    ui.section(f"Receitas · {len(receitas)} entradas")
    for r in receitas:
        row, btn = st.columns([10, 1], vertical_alignment="center")
        desc = (f'<span class="exp-desc"> — {html.escape(r["description"])}</span>'
                if r["description"] else "")
        tag = (f'<span class="card-tag">{r["card_icon"]} {html.escape(r["card"])}</span>'
               if r.get("card") else "")
        row.markdown(
            f'<div class="exp-row">'
            f'<span class="exp-date">{r["received_on"].strftime("%d/%m/%Y")}</span>'
            f'<span class="exp-chip" style="background:#0F7B6622">💶</span>'
            f'<span class="exp-main"><span class="exp-cat">{html.escape(r["source"])}</span>{desc}{tag}</span>'
            f'<span class="exp-amt">{ui.money_html(r["amount"])}</span>'
            f"</div>",
            unsafe_allow_html=True,
        )
        if btn.button("🗑️", key=f"delinc_{r['id']}", help="Eliminar"):
            repo.delete_income(r["id"])
            st.rerun()


# --------------------------------------------------------------------------- #
# Página única
# --------------------------------------------------------------------------- #
ano, mes = header()
st.divider()
dashboard(ano, mes)
