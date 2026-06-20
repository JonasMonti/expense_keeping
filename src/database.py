"""Ligação à base de dados e inicialização do esquema."""
from __future__ import annotations

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from .config import DATABASE_URL
from .models import Base, Category

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


def init_db() -> None:
    """Cria as tabelas (se não existirem) e semeia categorias por defeito."""
    Base.metadata.create_all(engine)
    with SessionLocal() as session:
        existing = session.scalar(select(Category).limit(1))
        if existing is None:
            session.add_all(
                Category(name=name, color=color, icon=icon)
                for name, color, icon in DEFAULT_CATEGORIES
            )
            session.commit()
