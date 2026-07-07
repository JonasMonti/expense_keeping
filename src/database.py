"""Ligação à base de dados e inicialização do esquema."""
from __future__ import annotations

from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import Session, sessionmaker

from .config import DATABASE_URL
from .models import Base, Card, Category

# SQLite precisa de check_same_thread=False para funcionar com o Streamlit.
_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=_connect_args, future=True)
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False, class_=Session)

# Categorias criadas automaticamente na primeira execução.
DEFAULT_CATEGORIES = [
    ("Alimentação", "#FF6B6B", "🍽️"),
    ("Transportes", "#4D96FF", "🚗"),
    ("Casa", "#6BCB77", "🏠"),
    ("Saúde", "#FF9F45", "💊"),
    ("Lazer", "#9B5DE5", "🎉"),
    ("Compras", "#F15BB5", "🛍️"),
    ("Educação", "#00BBF9", "📚"),
    ("Outros", "#888888", "💸"),
]

# Cartões criados automaticamente na primeira execução (nome, cor, emoji).
DEFAULT_CARDS = [
    ("Subsídio de alimentação", "#0F7B66", "🍽️"),
    ("Débito", "#4D96FF", "💳"),
    ("Cartão jovem", "#9B5DE5", "🎫"),
    ("Dinheiro", "#6BCB77", "💵"),
]

# Tabelas que ganharam a coluna `card_id` (para a migração leve abaixo).
_CARD_ID_TABLES = ("expenses", "incomes", "recurring_incomes")


def _migrate_card_id() -> None:
    """Adiciona a coluna `card_id` às tabelas já existentes.

    `create_all` cria tabelas em falta mas NÃO altera tabelas antigas, por isso
    uma BD criada antes dos cartões não teria a coluna. Detetamos a ausência via
    inspeção e fazemos `ALTER TABLE ADD COLUMN` (idempotente)."""
    insp = inspect(engine)
    existing_tables = set(insp.get_table_names())
    with engine.begin() as conn:
        for table in _CARD_ID_TABLES:
            if table not in existing_tables:
                continue  # tabela nova — create_all já a criou com a coluna
            cols = {c["name"] for c in insp.get_columns(table)}
            if "card_id" not in cols:
                conn.execute(
                    text(f"ALTER TABLE {table} ADD COLUMN card_id INTEGER")
                )


def init_db() -> None:
    """Cria as tabelas (se não existirem), migra o esquema e semeia dados base."""
    _migrate_card_id()  # antes do create_all: só toca em tabelas já existentes
    Base.metadata.create_all(engine)
    with SessionLocal() as session:
        if session.scalar(select(Category).limit(1)) is None:
            session.add_all(
                Category(name=name, color=color, icon=icon)
                for name, color, icon in DEFAULT_CATEGORIES
            )
        if session.scalar(select(Card).limit(1)) is None:
            session.add_all(
                Card(name=name, color=color, icon=icon)
                for name, color, icon in DEFAULT_CARDS
            )
        session.commit()
