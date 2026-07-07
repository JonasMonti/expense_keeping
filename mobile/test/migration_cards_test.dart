import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:despesas/data/database.dart';

/// Cria manualmente o esquema v3 (sem cartões nem coluna card_id) — o estado
/// de uma app instalada antes da funcionalidade de cartões.
Future<void> createV3Schema(Database d, int version) async {
  await d.execute(
      'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, color TEXT, icon TEXT)');
  await d.execute(
      "CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, description TEXT NOT NULL DEFAULT '', spent_on TEXT NOT NULL, category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE, created_at TEXT NOT NULL DEFAULT (datetime('now')))");
  await d.execute(
      "CREATE TABLE recurring (id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, description TEXT NOT NULL DEFAULT '', category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE, day_of_month INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1, last_generated TEXT, created_at TEXT NOT NULL DEFAULT (datetime('now')))");
  await d.execute(
      "CREATE TABLE incomes (id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, source TEXT NOT NULL DEFAULT 'Outros', description TEXT NOT NULL DEFAULT '', received_on TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now')))");
  await d.execute(
      "CREATE TABLE recurring_incomes (id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, source TEXT NOT NULL DEFAULT 'Outros', description TEXT NOT NULL DEFAULT '', day_of_month INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1, last_generated TEXT, created_at TEXT NOT NULL DEFAULT (datetime('now')))");
  await d.execute(
      "CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '')");
  await d.insert('categories', {'name': 'Casa', 'color': '#6BCB77', 'icon': '🏠'});
  await d.insert('expenses', {
    'amount': 7.5,
    'description': 'antiga',
    'spent_on': '2026-06-03',
    'category_id': 1,
  });
}

Future<bool> _hasColumn(Database d, String table, String column) async {
  final rows = await d.rawQuery('PRAGMA table_info($table)');
  return rows.any((r) => r['name'] == column);
}

void main() {
  late Directory dir;
  late String path;

  setUpAll(() => sqfliteFfiInit());

  setUp(() {
    dir = Directory.systemTemp.createTempSync('despesas_mig_cards');
    path = '${dir.path}/m.db';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('migração v3→v4 cria cartões e coluna card_id preservando dados',
      () async {
    // Abre na v3 (sem cartões) — usa ficheiro real para reabrir depois.
    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: createV3Schema,
      ),
    );
    // Confirma o ponto de partida: sem tabela cards nem coluna card_id.
    expect(await _hasColumn(v3, 'expenses', 'card_id'), isFalse);
    await v3.close();

    // Reabre na v4 → corre a migração AppDatabase.upgradeSchema.
    final v4 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );

    // A tabela cards existe e tem os 4 cartões por defeito.
    final cards = await v4.query('cards', orderBy: 'name');
    expect(cards.length, 4);
    expect(
      cards.map((c) => c['name']).toSet(),
      {'Subsídio de alimentação', 'Débito', 'Cartão jovem', 'Dinheiro'},
    );

    // Todas as tabelas de movimentos ganharam a coluna card_id.
    for (final t in ['expenses', 'incomes', 'recurring', 'recurring_incomes']) {
      expect(await _hasColumn(v4, t, 'card_id'), isTrue,
          reason: '$t devia ter card_id após a migração');
    }

    // A despesa antiga continua lá, agora com card_id NULL.
    final exps = await v4.query('expenses');
    expect(exps.length, 1);
    expect(exps.first['description'], 'antiga');
    expect(exps.first['card_id'], isNull);

    await v4.close();
  });
}
