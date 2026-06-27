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
        version: 2,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
      ),
    );
    repo = Repository(() async => db);
  });

  tearDown(() => db.close());

  // Conta as despesas (geradas) num dado ano/mês.
  Future<List<ExpenseView>> month(int y, int m) => repo.listExpenses(y, m);

  test('gera a despesa do mês corrente depois de chegar o dia', () async {
    // Regra: dia 5. Hoje é 10/06 → já passou o dia 5.
    await repo.addRecurring(
      const Recurring(amount: 500, categoryId: 3, dayOfMonth: 5, description: 'renda'),
      now: DateTime(2026, 6, 10),
    );
    final n = await repo.generateDueRecurring(now: DateTime(2026, 6, 10));
    expect(n, 1);
    final jun = await month(2026, 6);
    expect(jun.length, 1);
    expect(jun.first.amount, 500);
    expect(jun.first.spentOn, DateTime(2026, 6, 5));
  });

  test('NÃO gera antes de chegar o dia', () async {
    await repo.addRecurring(
      const Recurring(amount: 20, categoryId: 1, dayOfMonth: 28),
      now: DateTime(2026, 6, 10),
    );
    final n = await repo.generateDueRecurring(now: DateTime(2026, 6, 10));
    expect(n, 0);
    expect((await month(2026, 6)), isEmpty);
  });

  test('é idempotente no mesmo mês', () async {
    await repo.addRecurring(
      const Recurring(amount: 9.99, categoryId: 5, dayOfMonth: 1),
      now: DateTime(2026, 6, 1),
    );
    await repo.generateDueRecurring(now: DateTime(2026, 6, 15));
    await repo.generateDueRecurring(now: DateTime(2026, 6, 20));
    expect((await month(2026, 6)).length, 1);
  });

  test('catch-up: cria os meses em falta quando a app esteve fechada', () async {
    // Criada em abril (dia 1); só voltamos a gerar em junho.
    await repo.addRecurring(
      const Recurring(amount: 30, categoryId: 2, dayOfMonth: 1, description: 'passe'),
      now: DateTime(2026, 4, 1),
    );
    final n = await repo.generateDueRecurring(now: DateTime(2026, 6, 2));
    expect(n, 3); // abril, maio, junho
    expect((await month(2026, 4)).length, 1);
    expect((await month(2026, 5)).length, 1);
    expect((await month(2026, 6)).length, 1);
  });

  test('ajusta o dia 31 ao tamanho do mês', () async {
    // Dia 31, mês de fevereiro de 2026 (28 dias) → dia 28.
    await repo.addRecurring(
      const Recurring(amount: 100, categoryId: 4, dayOfMonth: 31),
      now: DateTime(2026, 2, 1),
    );
    await repo.generateDueRecurring(now: DateTime(2026, 2, 28));
    final feb = await month(2026, 2);
    expect(feb.length, 1);
    expect(feb.first.spentOn, DateTime(2026, 2, 28));
  });

  test('regras em pausa não geram', () async {
    await repo.addRecurring(
      const Recurring(
          amount: 50, categoryId: 1, dayOfMonth: 1, active: false),
      now: DateTime(2026, 6, 1),
    );
    final n = await repo.generateDueRecurring(now: DateTime(2026, 6, 15));
    expect(n, 0);
  });

  test('migração v1→v2 cria a tabela recurring preservando dados', () async {
    // Simula uma BD da versão 1 (sem a tabela recurring) com dados existentes.
    // Ficheiro real em temp para os dados persistirem entre fechar/reabrir.
    final dir = Directory.systemTemp.createTempSync('despesas_mig');
    final path = '${dir.path}/m.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, v) async {
          await d.execute(
              'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, color TEXT, icon TEXT)');
          await d.execute(
              "CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, description TEXT NOT NULL DEFAULT '', spent_on TEXT NOT NULL, category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE, created_at TEXT NOT NULL DEFAULT (datetime('now')))");
          await d.insert('categories', {'name': 'Casa', 'color': '#6BCB77', 'icon': '🏠'});
          await d.insert('expenses', {
            'amount': 7.5,
            'description': 'antiga',
            'spent_on': '2026-06-03',
            'category_id': 1,
          });
        },
      ),
    );
    await v1.close();

    // Reabre na versão 2 → corre a migração.
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    final migRepo = Repository(() async => v2);

    // A despesa antiga foi preservada…
    expect((await migRepo.listExpenses(2026, 6)).length, 1);
    // …e a tabela recurring passou a existir e a funcionar.
    await migRepo.addRecurring(
      const Recurring(amount: 40, categoryId: 1, dayOfMonth: 2),
      now: DateTime(2026, 6, 1),
    );
    final n = await migRepo.generateDueRecurring(now: DateTime(2026, 6, 10));
    expect(n, 1);
    await v2.close();
    dir.deleteSync(recursive: true);
  });
}
