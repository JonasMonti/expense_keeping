"""Testes do repositório (receitas, recorrentes e saldo) — espelham income_test.dart.

Usa uma BD SQLite temporária e a stdlib `unittest` (sem dependências extra):

    source .venv/bin/activate
    python -m unittest discover tests
"""
from __future__ import annotations

import datetime as dt
import os
import tempfile
import unittest
from decimal import Decimal

# Aponta a BD para um ficheiro temporário ANTES de importar a app (o engine é
# criado no import a partir de DATABASE_URL).
_TMP = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_TMP.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_TMP.name}"

from src import repository as repo  # noqa: E402
from src.database import engine, init_db  # noqa: E402
from src.models import Base  # noqa: E402


class RepositoryTest(unittest.TestCase):
    def setUp(self) -> None:
        # BD limpa por teste.
        Base.metadata.drop_all(engine)
        init_db()

    @classmethod
    def tearDownClass(cls) -> None:
        os.unlink(_TMP.name)

    # ---- receitas recorrentes ----
    def test_gera_mes_corrente_depois_do_dia(self) -> None:
        repo.add_recurring_income(Decimal("1500"), "Ordenado", 1, "salário",
                                  now=dt.date(2026, 6, 28))
        n = repo.generate_due_recurring_incomes(now=dt.date(2026, 6, 28))
        self.assertEqual(n, 1)
        jun = repo.list_incomes(2026, 6)
        self.assertEqual(len(jun), 1)
        self.assertEqual(jun[0]["amount"], 1500.0)
        self.assertEqual(jun[0]["source"], "Ordenado")
        self.assertEqual(jun[0]["received_on"], dt.date(2026, 6, 1))

    def test_nao_gera_antes_do_dia(self) -> None:
        repo.add_recurring_income(Decimal("100"), "Extra", 28, now=dt.date(2026, 6, 10))
        n = repo.generate_due_recurring_incomes(now=dt.date(2026, 6, 10))
        self.assertEqual(n, 0)
        self.assertEqual(repo.list_incomes(2026, 6), [])

    def test_idempotente(self) -> None:
        repo.add_recurring_income(Decimal("1200"), "Ordenado", 1, now=dt.date(2026, 6, 1))
        repo.generate_due_recurring_incomes(now=dt.date(2026, 6, 15))
        repo.generate_due_recurring_incomes(now=dt.date(2026, 6, 20))
        self.assertEqual(len(repo.list_incomes(2026, 6)), 1)

    def test_catch_up(self) -> None:
        repo.add_recurring_income(Decimal("1000"), "Ordenado", 1, now=dt.date(2026, 4, 1))
        n = repo.generate_due_recurring_incomes(now=dt.date(2026, 6, 2))
        self.assertEqual(n, 3)  # abril, maio, junho
        for m in (4, 5, 6):
            self.assertEqual(len(repo.list_incomes(2026, m)), 1)

    def test_ajusta_dia_31_em_fevereiro(self) -> None:
        repo.add_recurring_income(Decimal("200"), "Extra", 31, now=dt.date(2026, 2, 1))
        repo.generate_due_recurring_incomes(now=dt.date(2026, 2, 28))
        feb = repo.list_incomes(2026, 2)
        self.assertEqual(len(feb), 1)
        self.assertEqual(feb[0]["received_on"], dt.date(2026, 2, 28))

    def test_pausa_nao_gera(self) -> None:
        repo.add_recurring_income(Decimal("50"), "Extra", 1, active=False,
                                  now=dt.date(2026, 6, 1))
        n = repo.generate_due_recurring_incomes(now=dt.date(2026, 6, 15))
        self.assertEqual(n, 0)

    # ---- saldo e líquido ----
    def _cat_id(self) -> int:
        return repo.list_categories()[0].id

    def test_saldo_inicial_mais_receitas_menos_despesas(self) -> None:
        repo.set_opening_balance(1000.0, dt.date(2026, 6, 1))
        repo.add_income(Decimal("1500"), "Ordenado", dt.date(2026, 6, 1))
        repo.add_income(Decimal("50"), "Reembolso", dt.date(2026, 6, 10))
        repo.add_expense(Decimal("200"), self._cat_id(), dt.date(2026, 6, 15))
        self.assertAlmostEqual(repo.current_balance(now=dt.date(2026, 6, 28)), 2350.0)

    def test_futuro_nao_conta(self) -> None:
        repo.set_opening_balance(0.0, dt.date(2026, 6, 1))
        repo.add_income(Decimal("1500"), "Ordenado", dt.date(2026, 7, 1))
        self.assertAlmostEqual(repo.current_balance(now=dt.date(2026, 6, 28)), 0.0)

    def test_so_conta_a_partir_da_data_inicial(self) -> None:
        repo.set_opening_balance(500.0, dt.date(2026, 6, 1))
        repo.add_income(Decimal("999"), "Antigo", dt.date(2026, 5, 20))
        repo.add_income(Decimal("100"), "Extra", dt.date(2026, 6, 5))
        self.assertAlmostEqual(repo.current_balance(now=dt.date(2026, 6, 28)), 600.0)

    def test_liquido_do_mes(self) -> None:
        repo.add_income(Decimal("1500"), "Ordenado", dt.date(2026, 6, 1))
        repo.add_expense(Decimal("200"), self._cat_id(), dt.date(2026, 6, 5))
        self.assertAlmostEqual(repo.net_for_month(2026, 6), 1300.0)

    def test_receitas_por_origem(self) -> None:
        repo.add_income(Decimal("1500"), "Ordenado", dt.date(2026, 6, 1))
        repo.add_income(Decimal("100"), "Extra", dt.date(2026, 6, 3))
        repo.add_income(Decimal("50"), "Extra", dt.date(2026, 6, 7))
        rows = repo.incomes_by_source(2026, 6)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["source"], "Ordenado")  # maior primeiro
        extra = next(r for r in rows if r["source"] == "Extra")
        self.assertAlmostEqual(extra["total"], 150.0)


if __name__ == "__main__":
    unittest.main()
