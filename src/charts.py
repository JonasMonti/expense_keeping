"""Gráficos Plotly, alinhados com a identidade visual da app (sem pandas)."""
from __future__ import annotations

import plotly.graph_objects as go

MONTH_NAMES_PT = [
    "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
    "Jul", "Ago", "Set", "Out", "Nov", "Dez",
]

INK = "#16201C"
MUTED = "#6E7872"
BORDER = "#E7EAE7"
ACCENT = "#0F7B66"
ACCENT_SOFT = "rgba(15,123,102,.12)"
FONT = "Inter, system-ui, sans-serif"
DISPLAY = "Space Grotesk, sans-serif"


def _base(fig: go.Figure, height: int = 300) -> go.Figure:
    fig.update_layout(
        height=height,
        margin=dict(t=10, b=10, l=8, r=8),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(family=FONT, size=13, color=INK),
        showlegend=False,
        hoverlabel=dict(bgcolor="#fff", bordercolor=BORDER,
                        font=dict(family=FONT, color=INK)),
    )
    return fig


def donut_by_category(rows: list[dict], total: float, currency: str = "€") -> go.Figure:
    """Donut com o total no centro."""
    labels = [f"{r['icon']} {r['category']}" for r in rows]
    values = [r["total"] for r in rows]
    colors = [r["color"] for r in rows]

    fig = go.Figure(
        go.Pie(
            labels=labels, values=values, hole=0.66,
            marker=dict(colors=colors, line=dict(color="#fff", width=2)),
            textinfo="none",
            hovertemplate="%{label}<br><b>%{value:.2f} " + currency
            + "</b> · %{percent}<extra></extra>",
            sort=False,
        )
    )
    total_txt = f"{total:,.0f}".replace(",", " ")
    fig.add_annotation(
        text="Total", showarrow=False, x=0.5, y=0.60,
        font=dict(size=13, color=MUTED, family=FONT),
    )
    fig.add_annotation(
        text=f"{total_txt} {currency}", showarrow=False, x=0.5, y=0.42,
        font=dict(size=29, color=INK, family=DISPLAY),
    )
    return _base(fig, height=320)


def year_line(
    rows: list[dict],
    highlight_month: int,
    currency: str = "€",
    income_rows: list[dict] | None = None,
) -> go.Figure:
    """Linha com o total gasto em cada mês do ano (Jan→Dez).

    Se `income_rows` for dado, sobrepõe uma segunda linha (receitas, em ink) e
    mostra legenda — fica uma comparação receitas vs despesas."""
    labels = [MONTH_NAMES_PT[r["month"] - 1] for r in rows]
    values = [r["total"] for r in rows]
    # Destaca o mês selecionado com um marcador maior.
    sizes = [12 if r["month"] == highlight_month else 6 for r in rows]

    fig = go.Figure(
        go.Scatter(
            x=labels, y=values, mode="lines+markers", name="Despesas",
            fill="tozeroy", fillcolor=ACCENT_SOFT,
            line=dict(color=ACCENT, width=2.5),
            marker=dict(size=sizes, color=ACCENT, line=dict(color="#fff", width=2)),
            hovertemplate="%{x}<br><b>%{y:.2f} " + currency + "</b><extra>Despesas</extra>",
        )
    )
    if income_rows is not None:
        fig.add_trace(
            go.Scatter(
                x=[MONTH_NAMES_PT[r["month"] - 1] for r in income_rows],
                y=[r["total"] for r in income_rows],
                mode="lines+markers", name="Receitas",
                line=dict(color=INK, width=2, dash="dot"),
                marker=dict(size=6, color=INK, line=dict(color="#fff", width=2)),
                hovertemplate="%{x}<br><b>%{y:.2f} " + currency
                + "</b><extra>Receitas</extra>",
            )
        )
    _base(fig, height=300)
    if income_rows is not None:
        fig.update_layout(
            showlegend=True,
            legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0,
                        font=dict(color=MUTED)),
        )
    fig.update_xaxes(showgrid=False, showline=False, color=MUTED)
    fig.update_yaxes(showgrid=True, gridcolor=BORDER, zeroline=False,
                     rangemode="tozero", color=MUTED, ticksuffix=f" {currency}")
    return fig
