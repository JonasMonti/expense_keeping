import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:despesas/data/database.dart';
import 'package:despesas/data/repository.dart';
import 'package:despesas/models/models.dart';

void main() {
  late Database db;
  late Repository repo;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
      ),
    );
    repo = Repository(() async => db);
  });

  tearDown(() => db.close());

  group('receitas recorrentes', () {
    Future<List<IncomeView>> month(int y, int m) => repo.listIncomes(y, m);

    test('gera a receita do mês corrente depois de chegar o dia', () async {
      await repo.addRecurringIncome(
        const RecurringIncome(
            amount: 1500, source: 'Ordenado', dayOfMonth: 1, description: 'salário'),
        now: DateTime(2026, 6, 28),
      );
      final n = await repo.generateDueRecurringIncomes(now: DateTime(2026, 6, 28));
      expect(n, 1);
      final jun = await month(2026, 6);
      expect(jun.length, 1);
      expect(jun.first.amount, 1500);
      expect(jun.first.source, 'Ordenado');
      expect(jun.first.receivedOn, DateTime(2026, 6, 1));
    });

    test('NÃO gera antes de chegar o dia', () async {
      await repo.addRecurringIncome(
        const RecurringIncome(amount: 100, source: 'Extra', dayOfMonth: 28),
        now: DateTime(2026, 6, 10),
      );
      final n = await repo.generateDueRecurringIncomes(now: DateTime(2026, 6, 10));
      expect(n, 0);
      expect(await month(2026, 6), isEmpty);
    });

    test('é idempotente no mesmo mês', () async {
      await repo.addRecurringIncome(
        const RecurringIncome(amount: 1200, source: 'Ordenado', dayOfMonth: 1),
        now: DateTime(2026, 6, 1),
      );
      await repo.generateDueRecurringIncomes(now: DateTime(2026, 6, 15));
      await repo.generateDueRecurringIncomes(now: DateTime(2026, 6, 20));
      expect((await month(2026, 6)).length, 1);
    });

    test('catch-up: cria os meses em falta', () async {
      await repo.addRecurringIncome(
        const RecurringIncome(amount: 1000, source: 'Ordenado', dayOfMonth: 1),
        now: DateTime(2026, 4, 1),
      );
      final n = await repo.generateDueRecurringIncomes(now: DateTime(2026, 6, 2));
      expect(n, 3); // abril, maio, junho
      expect((await month(2026, 4)).length, 1);
      expect((await month(2026, 5)).length, 1);
      expect((await month(2026, 6)).length, 1);
    });

    test('ajusta o dia 31 ao tamanho do mês', () async {
      await repo.addRecurringIncome(
        const RecurringIncome(amount: 200, source: 'Extra', dayOfMonth: 31),
        now: DateTime(2026, 2, 1),
      );
      await repo.generateDueRecurringIncomes(now: DateTime(2026, 2, 28));
      final feb = await month(2026, 2);
      expect(feb.length, 1);
      expect(feb.first.receivedOn, DateTime(2026, 2, 28));
    });

    test('regras em pausa não geram', () async {
      await repo.addRecurringIncome(
        const RecurringIncome(
            amount: 50, source: 'Extra', dayOfMonth: 1, active: false),
        now: DateTime(2026, 6, 1),
      );
      final n = await repo.generateDueRecurringIncomes(now: DateTime(2026, 6, 15));
      expect(n, 0);
    });
  });

  group('saldo e líquido', () {
    test('saldo = inicial + receitas − despesas (até hoje)', () async {
      await repo.setOpeningBalance(1000, DateTime(2026, 6, 1));
      await repo.addIncome(Income(amount: 1500, source: 'Ordenado', receivedOn: DateTime(2026, 6, 1)));
      await repo.addIncome(Income(amount: 50, source: 'Reembolso', receivedOn: DateTime(2026, 6, 10)));
      await repo.addExpense(Expense(amount: 200, categoryId: 1, spentOn: DateTime(2026, 6, 15)));
      final saldo = await repo.currentBalance(now: DateTime(2026, 6, 28));
      expect(saldo, closeTo(2350, 0.001)); // 1000 + 1550 - 200
    });

    test('itens com data futura não contam para o saldo de hoje', () async {
      await repo.setOpeningBalance(0, DateTime(2026, 6, 1));
      await repo.addIncome(Income(amount: 1500, source: 'Ordenado', receivedOn: DateTime(2026, 7, 1)));
      final saldo = await repo.currentBalance(now: DateTime(2026, 6, 28));
      expect(saldo, closeTo(0, 0.001));
    });

    test('só conta a partir da data inicial', () async {
      await repo.setOpeningBalance(500, DateTime(2026, 6, 1));
      // Receita anterior à data inicial é ignorada.
      await repo.addIncome(Income(amount: 999, source: 'Antigo', receivedOn: DateTime(2026, 5, 20)));
      await repo.addIncome(Income(amount: 100, source: 'Extra', receivedOn: DateTime(2026, 6, 5)));
      final saldo = await repo.currentBalance(now: DateTime(2026, 6, 28));
      expect(saldo, closeTo(600, 0.001)); // 500 + 100
    });

    test('líquido do mês = receitas − despesas', () async {
      await repo.addIncome(Income(amount: 1500, source: 'Ordenado', receivedOn: DateTime(2026, 6, 1)));
      await repo.addExpense(Expense(amount: 200, categoryId: 1, spentOn: DateTime(2026, 6, 5)));
      expect(await repo.netForMonth(2026, 6), closeTo(1300, 0.001));
    });

    test('agrega receitas por origem', () async {
      await repo.addIncome(Income(amount: 1500, source: 'Ordenado', receivedOn: DateTime(2026, 6, 1)));
      await repo.addIncome(Income(amount: 100, source: 'Extra', receivedOn: DateTime(2026, 6, 3)));
      await repo.addIncome(Income(amount: 50, source: 'Extra', receivedOn: DateTime(2026, 6, 7)));
      final rows = await repo.incomesBySource(2026, 6);
      expect(rows.length, 2);
      expect(rows.first.source, 'Ordenado'); // maior primeiro
      expect(rows.firstWhere((r) => r.source == 'Extra').total, closeTo(150, 0.001));
    });
  });

  test('migração v2→v3 cria as tabelas de receita preservando dados', () async {
    final dir = Directory.systemTemp.createTempSync('despesas_mig_inc');
    final path = '${dir.path}/m.db';
    // Abre na versão 2 (sem tabelas de receita) com uma despesa.
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, v) async {
          await d.execute(
              'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, color TEXT, icon TEXT)');
          await d.execute(
              "CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, description TEXT NOT NULL DEFAULT '', spent_on TEXT NOT NULL, category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE, created_at TEXT NOT NULL DEFAULT (datetime('now')))");
          await d.insert('categories', {'name': 'Casa', 'color': '#6BCB77', 'icon': '🏠'});
          await d.insert('expenses', {
            'amount': 7.5,
            'spent_on': '2026-06-03',
            'category_id': 1,
          });
        },
      ),
    );
    await v2.close();

    // Reabre na versão 3 → corre a migração.
    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    final migRepo = Repository(() async => v3);

    // A despesa antiga foi preservada…
    expect((await migRepo.listExpenses(2026, 6)).length, 1);
    // …e as tabelas de receita passaram a existir e a funcionar.
    await migRepo.addIncome(
        Income(amount: 1500, source: 'Ordenado', receivedOn: DateTime(2026, 6, 1)));
    expect((await migRepo.listIncomes(2026, 6)).length, 1);
    await migRepo.setOpeningBalance(100, DateTime(2026, 6, 1));
    expect(await migRepo.currentBalance(now: DateTime(2026, 6, 28)),
        closeTo(1592.5, 0.001)); // 100 + 1500 − 7,5 (despesa antiga, 03/06)
    await v3.close();
    dir.deleteSync(recursive: true);
  });
}
