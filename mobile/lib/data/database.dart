/// Ligação SQLite (sqflite) e criação do esquema — equivalente a src/database.py.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Categorias criadas automaticamente na primeira execução (igual ao projeto original).
const List<(String, String, String)> defaultCategories = [
  ('Alimentação', '#FF6B6B', '🍽️'),
  ('Transportes', '#4D96FF', '🚗'),
  ('Casa', '#6BCB77', '🏠'),
  ('Saúde', '#FF9F45', '💊'),
  ('Lazer', '#9B5DE5', '🎉'),
  ('Compras', '#F15BB5', '🛍️'),
  ('Educação', '#00BBF9', '📚'),
  ('Outros', '#888888', '💸'),
];

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'expenses.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    );
  }

  /// Cria o esquema completo (versão atual). Público para os testes poderem
  /// abrir uma BD em memória com o mesmo esquema.
  static Future<void> createSchema(Database d, int version) async {
    await _create(d);
  }

  /// Migrações incrementais. Cada bloco corre quando se sobe a partir de uma
  /// versão anterior, preservando os dados existentes.
  static Future<void> upgradeSchema(
      Database d, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRecurring(d);
    }
  }

  /// Tabela de despesas recorrentes (usada por [_create] e por [upgradeSchema]).
  static Future<void> _createRecurring(Database d) async {
    await d.execute('''
      CREATE TABLE recurring (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        amount         REAL NOT NULL,
        description    TEXT NOT NULL DEFAULT '',
        category_id    INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        day_of_month   INTEGER NOT NULL,
        active         INTEGER NOT NULL DEFAULT 1,
        last_generated TEXT,
        created_at     TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  static Future<void> _create(Database d) async {
    await d.execute('''
      CREATE TABLE categories (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#888888',
        icon  TEXT NOT NULL DEFAULT '💸'
      )
    ''');
    await d.execute('''
      CREATE TABLE expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        amount      REAL NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        spent_on    TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await d.execute('CREATE INDEX idx_exp_date ON expenses(spent_on)');
    await d.execute('CREATE INDEX idx_exp_cat ON expenses(category_id)');
    await _createRecurring(d);

    final batch = d.batch();
    for (final (name, color, icon) in defaultCategories) {
      batch.insert('categories', {'name': name, 'color': color, 'icon': icon});
    }
    await batch.commit(noResult: true);
  }
}
