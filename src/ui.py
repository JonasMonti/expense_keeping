"""Camada de apresentação: tema (CSS) e componentes HTML reutilizáveis."""
from __future__ import annotations

import html

import streamlit as st

from .config import CURRENCY

# --------------------------------------------------------------------------- #
# Formatação de valores (algarismos tabulares, formato PT: 1 234,56 €)
# --------------------------------------------------------------------------- #
def fmt_number(value: float) -> str:
    """1234.5 -> '1 234,50' (espaço de milhar fino, vírgula decimal)."""
    return f"{float(value):,.2f}".replace(",", " ").replace(".", ",")


def money_html(value: float, big: bool = False) -> str:
    cls = "amount amount-lg" if big else "amount"
    return (
        f'<span class="{cls} num">{fmt_number(value)}'
        f'<span class="cur">{CURRENCY}</span></span>'
    )


def signed_money_html(value: float) -> str:
    """Valor com sinal explícito (+/−) para o líquido do mês. Sem vermelho:
    negativo usa tinta neutra, positivo o acento esmeralda."""
    sign = "+" if value > 0 else ("−" if value < 0 else "")
    cls = "amount num pos" if value > 0 else "amount num"
    return (
        f'<span class="{cls}">{sign}{fmt_number(abs(value))}'
        f'<span class="cur">{CURRENCY}</span></span>'
    )


# Paleta esmeralda/terrosa para as origens de receita (não usamos vermelho).
SOURCE_PALETTE = ["#0F7B66", "#2E9E86", "#6BCB77", "#4D96FF", "#9B5DE5", "#FF9F45", "#888888"]


def source_donut_rows(rows: list[dict]) -> list[dict]:
    """Converte incomes_by_source (source/total) no formato do donut_by_category."""
    return [
        {
            "category": r["source"],
            "color": SOURCE_PALETTE[i % len(SOURCE_PALETTE)],
            "icon": "💶",
            "total": r["total"],
        }
        for i, r in enumerate(rows)
    ]


# --------------------------------------------------------------------------- #
# Tema
# --------------------------------------------------------------------------- #
_CSS = """
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&display=swap');

:root{
  --bg:#F4F6F4; --surface:#FFFFFF; --border:#E7EAE7;
  --ink:#16201C; --muted:#6E7872; --faint:#9AA39D;
  --accent:#0F7B66; --accent-ink:#0A5848; --accent-soft:#E7F2EE;
  --radius:18px;
  --shadow:0 1px 2px rgba(20,32,28,.04), 0 10px 30px rgba(20,32,28,.05);
}

/* ---- base ---- */
html, body, [data-testid="stAppViewContainer"], .stMarkdown, input, textarea, button, select{
  font-family:'Inter', system-ui, -apple-system, sans-serif;
}
[data-testid="stApp"]{ background:var(--bg); }
[data-testid="stHeader"]{ background:transparent; }
[data-testid="stToolbar"], #MainMenu, footer{ visibility:hidden; }
.block-container{ padding-top:2rem; padding-bottom:5rem; max-width:1140px; }

h1, h2, h3{
  font-family:'Space Grotesk','Inter',sans-serif;
  color:var(--ink); letter-spacing:-.015em; font-weight:600;
}
h1{ font-size:1.9rem; margin-bottom:.2rem; }

.num{ font-variant-numeric:tabular-nums; font-feature-settings:"tnum" 1; }

/* ---- sidebar ---- */
[data-testid="stSidebar"]{ background:var(--surface); border-right:1px solid var(--border); }
[data-testid="stSidebar"] .block-container{ padding-top:1.4rem; }
.brand{ display:flex; align-items:center; gap:.55rem; font-family:'Space Grotesk',sans-serif;
  font-weight:600; font-size:1.25rem; color:var(--ink); margin:.2rem 0 1.4rem; }
.brand .dot{ width:30px; height:30px; border-radius:9px; background:var(--accent);
  display:grid; place-items:center; color:#fff; font-size:1rem; }

/* sidebar radio -> menu de navegação */
[data-testid="stSidebar"] [role="radiogroup"]{ gap:.25rem; }
[data-testid="stSidebar"] [role="radiogroup"] label{
  padding:.55rem .7rem; border-radius:11px; width:100%; cursor:pointer;
  transition:background .12s ease, color .12s ease; color:var(--muted); font-weight:500;
}
[data-testid="stSidebar"] [role="radiogroup"] label:hover{ background:var(--bg); color:var(--ink); }
[data-testid="stSidebar"] [role="radiogroup"] label:has(input:checked){
  background:var(--accent-soft); color:var(--accent-ink); font-weight:600;
}
[data-testid="stSidebar"] [role="radiogroup"] label > div:first-child{ display:none; }

/* ---- cartões ---- */
.card{
  background:var(--surface); border:1px solid var(--border);
  border-radius:var(--radius); box-shadow:var(--shadow); padding:1.4rem 1.5rem;
}
.eyebrow{ text-transform:uppercase; letter-spacing:.09em; font-size:.72rem;
  font-weight:600; color:var(--faint); margin-bottom:.5rem; }

/* ---- valores monetários ---- */
.amount{ font-family:'Space Grotesk',sans-serif; font-weight:600; color:var(--ink);
  font-variant-numeric:tabular-nums; }
.amount .cur{ font-size:.55em; color:var(--muted); font-weight:500; margin-left:.18em; }
.amount-lg{ font-size:3rem; line-height:1.05; display:inline-block; }

/* ---- saldo ---- */
.balance{ background:var(--accent); border:none; color:#fff; margin-bottom:1.1rem; }
.balance .eyebrow{ color:rgba(255,255,255,.75); }
.balance .amount{ color:#fff; }
.balance .amount .cur{ color:rgba(255,255,255,.7); }
.balance .balance-sub{ margin-top:.6rem; color:rgba(255,255,255,.85); font-size:.9rem; }

/* valor líquido positivo destacado a acento (negativo fica em tinta neutra) */
.amount.pos{ color:var(--accent); }
.amount.pos .cur{ color:var(--accent); }

/* ---- hero ---- */
.hero{ margin-bottom:1.1rem; }
.hero-sub{ margin-top:.7rem; color:var(--muted); font-size:.92rem; display:flex;
  flex-wrap:wrap; gap:.45rem .9rem; align-items:center; }
.hero-sub b{ color:var(--ink); font-weight:600; }
.hero-sub .sep{ color:var(--border); }

/* ---- mini KPIs ---- */
.kpi-grid{ display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:.9rem; margin:1.1rem 0; }
.kpi .k-label{ font-size:.74rem; text-transform:uppercase; letter-spacing:.07em; color:var(--faint);
  font-weight:600; margin-bottom:.35rem; }
.kpi .k-value{ font-family:'Space Grotesk',sans-serif; font-weight:600; font-size:1.45rem; color:var(--ink);
  font-variant-numeric:tabular-nums; }

/* ---- lista de categorias ---- */
.cat-list{ display:flex; flex-direction:column; gap:1rem; }
.cat-row .cat-head{ display:flex; justify-content:space-between; align-items:baseline; margin-bottom:.4rem; }
.cat-name{ font-weight:500; color:var(--ink); font-size:.95rem; }
.cat-pct{ color:var(--faint); font-size:.8rem; margin-left:.45rem; font-variant-numeric:tabular-nums; }
.cat-amt{ font-family:'Space Grotesk',sans-serif; font-weight:600; color:var(--ink); font-variant-numeric:tabular-nums; }
.track{ height:8px; border-radius:99px; background:var(--bg); overflow:hidden; }
.fill{ height:100%; border-radius:99px; }

/* ---- secção ---- */
.section-title{ font-family:'Space Grotesk',sans-serif; font-weight:600; font-size:1.05rem;
  color:var(--ink); margin:.4rem 0 .9rem; }

/* ---- botões ---- */
.stButton > button, .stFormSubmitButton > button{
  border-radius:11px; font-weight:600; border:1px solid var(--border); transition:.12s;
}
.stButton > button:hover{ border-color:var(--accent); color:var(--accent-ink); }
[data-testid="stFormSubmitButton"] > button{
  background:var(--accent); color:#fff; border:none;
}
[data-testid="stFormSubmitButton"] > button:hover{ background:var(--accent-ink); color:#fff; }

/* ---- inputs ---- */
[data-baseweb="input"], [data-baseweb="select"] > div{ border-radius:11px !important; }

/* ---- linha de despesa (histórico) ---- */
.exp-row{ display:flex; align-items:center; gap:.8rem; padding:.7rem .2rem;
  border-bottom:1px solid var(--border); }
.exp-date{ color:var(--faint); font-size:.82rem; width:84px; flex:none; font-variant-numeric:tabular-nums; }
.exp-chip{ width:34px; height:34px; border-radius:10px; display:grid; place-items:center;
  font-size:1rem; flex:none; }
.exp-main{ flex:1; min-width:0; }
.exp-cat{ font-weight:500; color:var(--ink); }
.exp-desc{ color:var(--muted); font-size:.85rem; }
.exp-amt{ font-family:'Space Grotesk',sans-serif; font-weight:600; color:var(--ink);
  font-variant-numeric:tabular-nums; white-space:nowrap; }

hr{ border-color:var(--border); }
"""


def inject_css() -> None:
    st.markdown(f"<style>{_CSS}</style>", unsafe_allow_html=True)


# --------------------------------------------------------------------------- #
# Componentes
# --------------------------------------------------------------------------- #
def hero(label: str, total: float, stats: list[str]) -> None:
    bits = '<span class="sep">·</span>'.join(f"<span>{s}</span>" for s in stats)
    st.markdown(
        f'<div class="hero card">'
        f'<div class="eyebrow">{html.escape(label)}</div>'
        f"{money_html(total, big=True)}"
        f'<div class="hero-sub">{bits}</div>'
        f"</div>",
        unsafe_allow_html=True,
    )


def balance_card(amount: float, sub: str) -> None:
    """Cartão de destaque com o saldo atual (quanto tens agora)."""
    st.markdown(
        f'<div class="balance card">'
        f'<div class="eyebrow">Saldo atual</div>'
        f"{money_html(amount, big=True)}"
        f'<div class="balance-sub">{html.escape(sub)}</div>'
        f"</div>",
        unsafe_allow_html=True,
    )


def kpi_grid(items: list[tuple[str, str]]) -> None:
    cards = "".join(
        f'<div class="kpi card"><div class="k-label">{html.escape(lbl)}</div>'
        f'<div class="k-value">{val}</div></div>'
        for lbl, val in items
    )
    st.markdown(f'<div class="kpi-grid">{cards}</div>', unsafe_allow_html=True)


def category_list(rows: list[dict], total: float) -> None:
    if not rows:
        return
    items = []
    for r in rows:
        pct = (r["total"] / total * 100) if total else 0
        items.append(
            f'<div class="cat-row">'
            f'<div class="cat-head">'
            f'<span class="cat-name">{r["icon"]} {html.escape(r["category"])}'
            f'<span class="cat-pct">{pct:.0f}%</span></span>'
            f'<span class="cat-amt">{fmt_number(r["total"])}</span>'
            f"</div>"
            f'<div class="track"><div class="fill" '
            f'style="width:{pct:.1f}%;background:{r["color"]}"></div></div>'
            f"</div>"
        )
    st.markdown(f'<div class="cat-list">{"".join(items)}</div>', unsafe_allow_html=True)


def section(title: str) -> None:
    st.markdown(f'<div class="section-title">{html.escape(title)}</div>', unsafe_allow_html=True)
