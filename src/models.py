"""Modelos de dados (SQLAlchemy 2.0)."""
from __future__ import annotations

import datetime as dt
from decimal import Decimal

from sqlalchemy import ForeignKey, Numeric, String, Date, DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    # Cor em hexadecimal usada nos gráficos, ex. "#4C9AFF".
    color: Mapped[str] = mapped_column(String(7), default="#888888")
    # Emoji opcional para apresentação.
    icon: Mapped[str] = mapped_column(String(8), default="💸")

    expenses: Mapped[list["Expense"]] = relationship(
        back_populates="category", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Category {self.name!r}>"


class Card(Base):
    """Cartão / meio de pagamento (subsídio de alimentação, débito, dinheiro…).

    Funciona como uma carteira: saldo = `opening_balance` + receitas atribuídas
    − despesas atribuídas (ver `repository.card_balance`). É uma lente paralela ao
    saldo global, não uma repartição dele."""

    __tablename__ = "cards"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    color: Mapped[str] = mapped_column(String(7), default="#0F7B66")
    icon: Mapped[str] = mapped_column(String(8), default="💳")
    # Saldo de arranque do cartão (o que lá estava antes de registares movimentos).
    opening_balance: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False, default=Decimal("0")
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Card {self.name!r}>"


class Expense(Base):
    __tablename__ = "expenses"

    id: Mapped[int] = mapped_column(primary_key=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    description: Mapped[str] = mapped_column(String(255), default="")
    spent_on: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id"), nullable=False, index=True
    )
    # Cartão usado (opcional). ON DELETE SET NULL: eliminar o cartão não apaga a despesa.
    card_id: Mapped[int | None] = mapped_column(
        ForeignKey("cards.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime, server_default=func.now()
    )

    category: Mapped["Category"] = relationship(back_populates="expenses")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Expense {self.amount} {self.spent_on}>"


class Income(Base):
    """Entrada de dinheiro (espelha Expense). A `source` faz o papel da categoria."""

    __tablename__ = "incomes"

    id: Mapped[int] = mapped_column(primary_key=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    # Origem da receita, ex. "Ordenado", "Subsídio de alimentação".
    source: Mapped[str] = mapped_column(String(80), default="Outros")
    description: Mapped[str] = mapped_column(String(255), default="")
    received_on: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
    # Cartão carregado por esta receita (opcional).
    card_id: Mapped[int | None] = mapped_column(
        ForeignKey("cards.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime, server_default=func.now()
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Income {self.amount} {self.received_on}>"


class RecurringIncome(Base):
    """Receita recorrente (ordenado, subsídio…). Gera uma receita por mês, no dia
    `day_of_month`, enquanto estiver `active`. Espelha a tabela `recurring` do mobile."""

    __tablename__ = "recurring_incomes"

    id: Mapped[int] = mapped_column(primary_key=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    source: Mapped[str] = mapped_column(String(80), default="Outros")
    description: Mapped[str] = mapped_column(String(255), default="")
    day_of_month: Mapped[int] = mapped_column(nullable=False)
    active: Mapped[bool] = mapped_column(default=True)
    # Cartão carregado pelas receitas geradas por esta regra (opcional).
    card_id: Mapped[int | None] = mapped_column(
        ForeignKey("cards.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # Último mês já materializado, no formato 'YYYY-MM' (None = ainda nenhum).
    last_generated: Mapped[str | None] = mapped_column(String(7), default=None)
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime, server_default=func.now()
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<RecurringIncome {self.amount} dia {self.day_of_month}>"


class AppSetting(Base):
    """Definições chave/valor (saldo inicial, data do saldo inicial…)."""

    __tablename__ = "settings"

    key: Mapped[str] = mapped_column(String(50), primary_key=True)
    value: Mapped[str] = mapped_column(String(255), default="")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<AppSetting {self.key}={self.value!r}>"
