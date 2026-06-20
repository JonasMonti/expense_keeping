"""Operações de leitura/escrita sobre despesas e categorias."""
from __future__ import annotations

import datetime as dt
from decimal import Decimal

from sqlalchemy import delete, extract, func, select

from .database import SessionLocal
from .models import Category, Expense


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
# Despesas
# --------------------------------------------------------------------------- #
def add_expense(
    amount: Decimal, category_id: int, spent_on: dt.date, description: str = ""
) -> None:
    with SessionLocal() as s:
        s.add(
            Expense(
                amount=Decimal(str(amount)),
                category_id=category_id,
                spent_on=spent_on,
                description=description.strip(),
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
            select(Expense, Category)
            .join(Category, Expense.category_id == Category.id)
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
        }
        for e, c in rows
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
    with SessionLocal() as s:
        rows = s.scalars(
            select(extract("year", Expense.spent_on))
            .distinct()
            .order_by(extract("year", Expense.spent_on).desc())
        ).all()
    return [int(y) for y in rows]
