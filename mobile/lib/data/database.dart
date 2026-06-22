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
      version: 1,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
    );
  }

  Future<void> _create(Database d, int version) async {
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

    final batch = d.batch();
    for (final (name, color, icon) in defaultCategories) {
      batch.insert('categories', {'name': name, 'color': color, 'icon': icon});
    }
    await batch.commit(noResult: true);
  }
}
