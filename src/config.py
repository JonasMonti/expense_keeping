"""Configuração da aplicação, lida a partir de variáveis de ambiente / .env."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Carrega o .env (se existir) a partir da raiz do projeto.
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(_PROJECT_ROOT / ".env")

# Por defeito guarda num ficheiro SQLite na raiz do projeto.
_DEFAULT_DB = f"sqlite:///{_PROJECT_ROOT / 'expenses.db'}"

DATABASE_URL: str = os.getenv("DATABASE_URL", _DEFAULT_DB)
CURRENCY: str = os.getenv("APP_CURRENCY", "€")
