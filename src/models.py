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


class Expense(Base):
    __tablename__ = "expenses"

    id: Mapped[int] = mapped_column(primary_key=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    description: Mapped[str] = mapped_column(String(255), default="")
    spent_on: Mapped[dt.date] = mapped_column(Date, nullable=False, index=True)
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id"), nullable=False, index=True
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime, server_default=func.now()
    )

    category: Mapped["Category"] = relationship(back_populates="expenses")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Expense {self.amount} {self.spent_on}>"
