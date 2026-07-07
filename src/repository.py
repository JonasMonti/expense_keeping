"""Operações de leitura/escrita sobre despesas, receitas e categorias."""
from __future__ import annotations

import calendar
import datetime as dt
from decimal import Decimal

from sqlalchemy import delete, extract, func, select

from .database import SessionLocal
from .models import AppSetting, Card, Category, Expense, Income, RecurringIncome


# --------------------------------------------------------------------------- #
# Categorias
# --------------------------------------------------------------------------- #
def list_categories() -> list[Category]:
    with SessionLocal() as s:
        return list(s.scalars(select(Category).order_by(Category.name)))


def add_category(name: str, color: str = "#888888", icon: str = "💸") -> None:
    with SessionLocal() as s:
        s.add(Category(name=name.strip(), color=color, icon=icon))
        s.commit()


def update_category(cat_id: int, name: str, color: str, icon: str) -> None:
    with SessionLocal() as s:
        cat = s.get(Category, cat_id)
        if cat:
            cat.name, cat.color, cat.icon = name.strip(), color, icon
            s.commit()


def delete_category(cat_id: int) -> None:
    with SessionLocal() as s:
        s.execute(delete(Category).where(Category.id == cat_id))
        s.commit()


def category_has_expenses(cat_id: int) -> bool:
    with SessionLocal() as s:
        count = s.scalar(
            select(func.count(Expense.id)).where(Expense.category_id == cat_id)
        )
        return bool(count)


# --------------------------------------------------------------------------- #
# Cartões
# --------------------------------------------------------------------------- #
def list_cards() -> list[Card]:
    with SessionLocal() as s:
        return list(s.scalars(select(Card).order_by(Card.name)))


def add_card(
    name: str, color: str = "#0F7B66", icon: str = "💳", opening_balance: float = 0.0
) -> None:
    with SessionLocal() as s:
        s.add(
            Card(
                name=name.strip(),
                color=color,
                icon=icon,
                opening_balance=Decimal(str(opening_balance)),
            )
        )
        s.commit()


def update_card(
    card_id: int, name: str, color: str, icon: str, opening_balance: float
) -> None:
    with SessionLocal() as s:
        card = s.get(Card, card_id)
        if card:
            card.name = name.strip()
            card.color = color
            card.icon = icon
            card.opening_balance = Decimal(str(opening_balance))
            s.commit()


def delete_card(card_id: int) -> None:
    with SessionLocal() as s:
        s.execute(delete(Card).where(Card.id == card_id))
        s.commit()


def card_has_movements(card_id: int) -> bool:
    """True se o cartão tem despesas ou receitas associadas."""
    with SessionLocal() as s:
        exp = s.scalar(
            select(func.count(Expense.id)).where(Expense.card_id == card_id)
        )
        inc = s.scalar(
            select(func.count(Income.id)).where(Income.card_id == card_id)
        )
        return bool(exp or inc)


def card_balances(now: dt.date | None = None) -> list[dict]:
    """Saldo atual de cada cartão (ordenado por nome).

    Saldo = saldo inicial + receitas atribuídas − despesas atribuídas, contando
    apenas movimentos até hoje (itens futuros não contam, igual ao saldo global)."""
    today = now or dt.date.today()
    with SessionLocal() as s:
        cards = list(s.scalars(select(Card).order_by(Card.name)))
        inc_rows = dict(
            s.execute(
                select(Income.card_id, func.coalesce(func.sum(Income.amount), 0))
                .where(Income.card_id.is_not(None), Income.received_on <= today)
                .group_by(Income.card_id)
            ).all()
        )
        exp_rows = dict(
            s.execute(
                select(Expense.card_id, func.coalesce(func.sum(Expense.amount), 0))
                .where(Expense.card_id.is_not(None), Expense.spent_on <= today)
                .group_by(Expense.card_id)
            ).all()
        )
    result = []
    for c in cards:
        incomes = float(inc_rows.get(c.id, 0) or 0)
        expenses = float(exp_rows.get(c.id, 0) or 0)
        opening = float(c.opening_balance)
        result.append(
            {
                "id": c.id,
                "name": c.name,
                "color": c.color,
                "icon": c.icon,
                "opening": opening,
                "incomes": incomes,
                "expenses": expenses,
                "balance": opening + incomes - expenses,
            }
        )
    return result


# --------------------------------------------------------------------------- #
# Despesas
# --------------------------------------------------------------------------- #
def add_expense(
    amount: Decimal,
    category_id: int,
    spent_on: dt.date,
    description: str = "",
    card_id: int | None = None,
) -> None:
    with SessionLocal() as s:
        s.add(
            Expense(
                amount=Decimal(str(amount)),
                category_id=category_id,
                spent_on=spent_on,
                description=description.strip(),
                card_id=card_id,
            )
        )
        s.commit()


def delete_expense(expense_id: int) -> None:
    with SessionLocal() as s:
        s.execute(delete(Expense).where(Expense.id == expense_id))
        s.commit()


def list_expenses(year: int, month: int) -> list[dict]:
    """Devolve as despesas de um mês como dicionários (já desligados da sessão)."""
    with SessionLocal() as s:
        rows = s.execute(
            select(Expense, Category, Card)
            .join(Category, Expense.category_id == Category.id)
            .outerjoin(Card, Expense.card_id == Card.id)
            .where(
                extract("year", Expense.spent_on) == year,
                extract("month", Expense.spent_on) == month,
            )
            .order_by(Expense.spent_on.desc(), Expense.id.desc())
        ).all()
    return [
        {
            "id": e.id,
            "spent_on": e.spent_on,
            "amount": float(e.amount),
            "description": e.description,
            "category": c.name,
            "color": c.color,
            "icon": c.icon,
            "card_id": e.card_id,
            "card": card.name if card else None,
            "card_icon": card.icon if card else None,
        }
        for e, c, card in rows
    ]


# --------------------------------------------------------------------------- #
# Agregações para gráficos
# --------------------------------------------------------------------------- #
def total_for_month(year: int, month: int) -> float:
    with SessionLocal() as s:
        total = s.scalar(
            select(func.coalesce(func.sum(Expense.amount), 0)).where(
                extract("year", Expense.spent_on) == year,
                extract("month", Expense.spent_on) == month,
            )
        )
    return float(total or 0)


def totals_by_category(year: int, month: int) -> list[dict]:
    """Soma por categoria num mês, ordenada do maior para o menor."""
    with SessionLocal() as s:
        rows = s.execute(
            select(
                Category.name,
                Category.color,
                Category.icon,
                func.coalesce(func.sum(Expense.amount), 0).label("total"),
            )
            .join(Expense, Expense.category_id == Category.id)
            .where(
                extract("year", Expense.spent_on) == year,
                extract("month", Expense.spent_on) == month,
            )
            .group_by(Category.id)
            .order_by(func.sum(Expense.amount).desc())
        ).all()
    return [
        {"category": name, "color": color, "icon": icon, "total": float(total)}
        for name, color, icon, total in rows
    ]


def monthly_totals(months: int = 12) -> list[dict]:
    """Total gasto por mês (todos os meses com despesas), do mais antigo ao mais recente."""
    with SessionLocal() as s:
        y = extract("year", Expense.spent_on)
        m = extract("month", Expense.spent_on)
        rows = s.execute(
            select(y.label("y"), m.label("m"), func.sum(Expense.amount).label("total"))
            .group_by(y, m)
            .order_by(y, m)
        ).all()
    data = [
        {"year": int(yr), "month": int(mo), "total": float(total)}
        for yr, mo, total in rows
    ]
    return data[-months:] if months else data


def monthly_totals_for_year(year: int) -> list[dict]:
    """Total por mês de um ano (12 meses, com 0 onde não houve despesas)."""
    with SessionLocal() as s:
        m = extract("month", Expense.spent_on)
        rows = s.execute(
            select(m.label("m"), func.sum(Expense.amount).label("total"))
            .where(extract("year", Expense.spent_on) == year)
            .group_by(m)
        ).all()
    found = {int(mo): float(total) for mo, total in rows}
    return [{"month": mo, "total": found.get(mo, 0.0)} for mo in range(1, 13)]


def daily_totals(year: int, month: int) -> list[dict]:
    """Total por dia dentro de um mês, ordenado por dia."""
    with SessionLocal() as s:
        day = extract("day", Expense.spent_on)
        rows = s.execute(
            select(day.label("d"), func.sum(Expense.amount).label("total"))
            .where(
                extract("year", Expense.spent_on) == year,
                extract("month", Expense.spent_on) == month,
            )
            .group_by(day)
            .order_by(day)
        ).all()
    return [{"day": int(d), "total": float(total)} for d, total in rows]


def available_years() -> list[int]:
    """Anos com despesas ou receitas, do mais recente para o mais antigo."""
    with SessionLocal() as s:
        exp = s.scalars(
            select(extract("year", Expense.spent_on)).distinct()
        ).all()
        inc = s.scalars(
            select(extract("year", Income.received_on)).distinct()
        ).all()
    return sorted({int(y) for y in (*exp, *inc)}, reverse=True)


# --------------------------------------------------------------------------- #
# Receitas
# --------------------------------------------------------------------------- #
def add_income(
    amount: Decimal,
    source: str,
    received_on: dt.date,
    description: str = "",
    card_id: int | None = None,
) -> None:
    with SessionLocal() as s:
        s.add(
            Income(
                amount=Decimal(str(amount)),
                source=source.strip() or "Outros",
                received_on=received_on,
                description=description.strip(),
                card_id=card_id,
            )
        )
        s.commit()


def update_income(
    income_id: int,
    amount: Decimal,
    source: str,
    received_on: dt.date,
    description: str = "",
    card_id: int | None = None,
) -> None:
    with SessionLocal() as s:
        inc = s.get(Income, income_id)
        if inc:
            inc.amount = Decimal(str(amount))
            inc.source = source.strip() or "Outros"
            inc.received_on = received_on
            inc.description = description.strip()
            inc.card_id = card_id
            s.commit()


def delete_income(income_id: int) -> None:
    with SessionLocal() as s:
        s.execute(delete(Income).where(Income.id == income_id))
        s.commit()


def list_incomes(year: int, month: int) -> list[dict]:
    """Devolve as receitas de um mês como dicionários (desligados da sessão)."""
    with SessionLocal() as s:
        rows = s.execute(
            select(Income, Card)
            .outerjoin(Card, Income.card_id == Card.id)
            .where(
                extract("year", Income.received_on) == year,
                extract("month", Income.received_on) == month,
            )
            .order_by(Income.received_on.desc(), Income.id.desc())
        ).all()
    return [
        {
            "id": i.id,
            "received_on": i.received_on,
            "amount": float(i.amount),
            "source": i.source,
            "description": i.description,
            "card_id": i.card_id,
            "card": card.name if card else None,
            "card_icon": card.icon if card else None,
        }
        for i, card in rows
    ]


def income_total_for_month(year: int, month: int) -> float:
    with SessionLocal() as s:
        total = s.scalar(
            select(func.coalesce(func.sum(Income.amount), 0)).where(
                extract("year", Income.received_on) == year,
                extract("month", Income.received_on) == month,
            )
        )
    return float(total or 0)


def incomes_by_source(year: int, month: int) -> list[dict]:
    """Soma por origem num mês, ordenada do maior para o menor."""
    with SessionLocal() as s:
        rows = s.execute(
            select(
                Income.source,
                func.coalesce(func.sum(Income.amount), 0).label("total"),
            )
            .where(
                extract("year", Income.received_on) == year,
                extract("month", Income.received_on) == month,
            )
            .group_by(Income.source)
            .order_by(func.sum(Income.amount).desc())
        ).all()
    return [{"source": source, "total": float(total)} for source, total in rows]


def monthly_income_for_year(year: int) -> list[dict]:
    """Total de receitas por mês de um ano (12 meses, com 0 onde não houve)."""
    with SessionLocal() as s:
        m = extract("month", Income.received_on)
        rows = s.execute(
            select(m.label("m"), func.sum(Income.amount).label("total"))
            .where(extract("year", Income.received_on) == year)
            .group_by(m)
        ).all()
    found = {int(mo): float(total) for mo, total in rows}
    return [{"month": mo, "total": found.get(mo, 0.0)} for mo in range(1, 13)]


# --------------------------------------------------------------------------- #
# Receitas recorrentes (espelha o padrão `recurring` do mobile)
# --------------------------------------------------------------------------- #
def list_recurring_incomes() -> list[dict]:
    with SessionLocal() as s:
        rows = s.scalars(
            select(RecurringIncome).order_by(
                RecurringIncome.day_of_month, RecurringIncome.id
            )
        ).all()
    return [
        {
            "id": r.id,
            "amount": float(r.amount),
            "source": r.source,
            "description": r.description,
            "day_of_month": r.day_of_month,
            "active": r.active,
            "card_id": r.card_id,
        }
        for r in rows
    ]


def add_recurring_income(
    amount: Decimal,
    source: str,
    day_of_month: int,
    description: str = "",
    active: bool = True,
    card_id: int | None = None,
    now: dt.date | None = None,
) -> None:
    """Cria uma regra. `last_generated` arranca no mês anterior ao atual, para que a
    geração comece já no mês corrente (e faça catch-up se a app não abrir)."""
    n = now or dt.date.today()
    prev = (n.replace(day=1) - dt.timedelta(days=1)).strftime("%Y-%m")
    with SessionLocal() as s:
        s.add(
            RecurringIncome(
                amount=Decimal(str(amount)),
                source=source.strip() or "Outros",
                description=description.strip(),
                day_of_month=day_of_month,
                active=active,
                card_id=card_id,
                last_generated=prev,
            )
        )
        s.commit()


def update_recurring_income(
    rule_id: int,
    amount: Decimal,
    source: str,
    day_of_month: int,
    description: str,
    active: bool,
    card_id: int | None = None,
) -> None:
    with SessionLocal() as s:
        r = s.get(RecurringIncome, rule_id)
        if r:
            r.amount = Decimal(str(amount))
            r.source = source.strip() or "Outros"
            r.day_of_month = day_of_month
            r.description = description.strip()
            r.active = active
            r.card_id = card_id
            s.commit()


def delete_recurring_income(rule_id: int) -> None:
    with SessionLocal() as s:
        s.execute(delete(RecurringIncome).where(RecurringIncome.id == rule_id))
        s.commit()


def generate_due_recurring_incomes(now: dt.date | None = None) -> int:
    """Materializa as receitas recorrentes em falta até ao mês/dia atual.

    Para cada regra ativa, gera uma receita por cada mês entre o último gerado e o
    mês corrente (catch-up se a app esteve fechada). No mês corrente só gera depois
    de chegar o dia da regra; o dia é ajustado ao tamanho do mês (ex.: 31 em
    fevereiro → último dia). Devolve quantas receitas criou."""
    today = now or dt.date.today()
    today_idx = today.year * 12 + (today.month - 1)
    created = 0
    with SessionLocal() as s:
        rules = list(s.scalars(select(RecurringIncome).where(RecurringIncome.active)))
        for r in rules:
            # Cursor = primeiro mês a considerar (o seguinte ao último gerado).
            if r.last_generated:
                ly, lm = (int(x) for x in r.last_generated.split("-"))
                cy, cm = (ly, lm + 1) if lm < 12 else (ly + 1, 1)
            else:
                cy, cm = today.year, today.month
            new_last = r.last_generated

            while cy * 12 + (cm - 1) <= today_idx:
                dim = calendar.monthrange(cy, cm)[1]
                dd = min(r.day_of_month, dim)  # dia ajustado ao tamanho do mês
                if cy == today.year and cm == today.month and today.day < dd:
                    break  # ainda não chegou o dia, no mês corrente
                s.add(
                    Income(
                        amount=r.amount,
                        source=r.source,
                        description=r.description,
                        received_on=dt.date(cy, cm, dd),
                        card_id=r.card_id,
                    )
                )
                created += 1
                new_last = f"{cy:04d}-{cm:02d}"
                cy, cm = (cy, cm + 1) if cm < 12 else (cy + 1, 1)

            if new_last != r.last_generated:
                r.last_generated = new_last
        s.commit()
    return created


# --------------------------------------------------------------------------- #
# Definições e saldo
# --------------------------------------------------------------------------- #
def get_setting(key: str, default: str | None = None) -> str | None:
    with SessionLocal() as s:
        row = s.get(AppSetting, key)
        return row.value if row else default


def set_setting(key: str, value: str) -> None:
    with SessionLocal() as s:
        row = s.get(AppSetting, key)
        if row:
            row.value = value
        else:
            s.add(AppSetting(key=key, value=value))
        s.commit()


def get_opening_balance() -> tuple[float, dt.date | None]:
    """Devolve (valor inicial, data inicial). Valores por defeito: (0, None)."""
    raw_amount = get_setting("opening_balance")
    raw_date = get_setting("opening_balance_date")
    amount = float(raw_amount) if raw_amount else 0.0
    date = dt.date.fromisoformat(raw_date) if raw_date else None
    return amount, date


def set_opening_balance(amount: float, date: dt.date) -> None:
    set_setting("opening_balance", str(amount))
    set_setting("opening_balance_date", date.isoformat())


def current_balance(now: dt.date | None = None) -> float:
    """Saldo atual = valor inicial + receitas − despesas, da data inicial até hoje.

    Itens com data futura não contam (é "quanto tens agora")."""
    today = now or dt.date.today()
    opening, since = get_opening_balance()
    with SessionLocal() as s:
        inc_q = select(func.coalesce(func.sum(Income.amount), 0)).where(
            Income.received_on <= today
        )
        exp_q = select(func.coalesce(func.sum(Expense.amount), 0)).where(
            Expense.spent_on <= today
        )
        if since is not None:
            inc_q = inc_q.where(Income.received_on >= since)
            exp_q = exp_q.where(Expense.spent_on >= since)
        incomes = float(s.scalar(inc_q) or 0)
        expenses = float(s.scalar(exp_q) or 0)
    return opening + incomes - expenses


def net_for_month(year: int, month: int) -> float:
    """Líquido do mês = receitas − despesas."""
    return income_total_for_month(year, month) - total_for_month(year, month)
