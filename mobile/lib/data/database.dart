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

/// Cartões / meios de pagamento criados por defeito (nome, cor, emoji).
const List<(String, String, String)> defaultCards = [
  ('Subsídio de alimentação', '#0F7B66', '🍽️'),
  ('Débito', '#4D96FF', '💳'),
  ('Cartão jovem', '#9B5DE5', '🎫'),
  ('Dinheiro', '#6BCB77', '💵'),
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
      version: 4,
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
    if (oldVersion < 3) {
      await _createIncomeTables(d);
    }
    if (oldVersion < 4) {
      await _createCards(d);
      // Coluna nulável nas tabelas existentes. Sem REFERENCES no ALTER (o SQLite
      // não valida FKs adicionadas por ALTER); a integridade fica garantida pelo
      // esquema de [_create] e pelo ON DELETE tratado no repositório.
      await d.execute('ALTER TABLE expenses ADD COLUMN card_id INTEGER');
      await d.execute('ALTER TABLE incomes ADD COLUMN card_id INTEGER');
      await d.execute('ALTER TABLE recurring ADD COLUMN card_id INTEGER');
      await d.execute('ALTER TABLE recurring_incomes ADD COLUMN card_id INTEGER');
      await _seedCards(d);
    }
  }

  /// Tabela de cartões (meios de pagamento). Usada por [_create] e pela migração
  /// v3→v4. Cada cartão funciona como carteira: saldo inicial + carregamentos −
  /// despesas (ver Repository.cardBalances).
  static Future<void> _createCards(Database d) async {
    await d.execute('''
      CREATE TABLE cards (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT NOT NULL UNIQUE,
        color           TEXT NOT NULL DEFAULT '#0F7B66',
        icon            TEXT NOT NULL DEFAULT '💳',
        opening_balance REAL NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _seedCards(Database d) async {
    final batch = d.batch();
    for (final (name, color, icon) in defaultCards) {
      batch.insert('cards', {'name': name, 'color': color, 'icon': icon});
    }
    await batch.commit(noResult: true);
  }

  /// Tabela de despesas recorrentes (usada por [_create] e por [upgradeSchema]).
  /// Nota: na migração v1→v2/v2→v3 a coluna `card_id` é adicionada depois, no
  /// bloco v3→v4; por isso aqui só a incluímos quando criada de raiz (v4).
  static Future<void> _createRecurring(Database d, {bool withCard = false}) async {
    final cardCol = withCard
        ? "card_id INTEGER REFERENCES cards(id) ON DELETE SET NULL,"
        : '';
    await d.execute('''
      CREATE TABLE recurring (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        amount         REAL NOT NULL,
        description    TEXT NOT NULL DEFAULT '',
        category_id    INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        day_of_month   INTEGER NOT NULL,
        active         INTEGER NOT NULL DEFAULT 1,
        $cardCol
        last_generated TEXT,
        created_at     TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  /// Tabelas de receitas, receitas recorrentes e definições (chave/valor).
  /// Usadas por [_create] e pela migração v2→v3. A receita usa `source` (origem,
  /// ex. "Ordenado") em vez de uma FK de categoria.
  static Future<void> _createIncomeTables(Database d, {bool withCard = false}) async {
    final cardCol = withCard
        ? "card_id INTEGER REFERENCES cards(id) ON DELETE SET NULL,"
        : '';
    await d.execute('''
      CREATE TABLE incomes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        amount      REAL NOT NULL,
        source      TEXT NOT NULL DEFAULT 'Outros',
        description TEXT NOT NULL DEFAULT '',
        received_on TEXT NOT NULL,
        $cardCol
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await d.execute('CREATE INDEX idx_inc_date ON incomes(received_on)');
    await d.execute('''
      CREATE TABLE recurring_incomes (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        amount         REAL NOT NULL,
        source         TEXT NOT NULL DEFAULT 'Outros',
        description    TEXT NOT NULL DEFAULT '',
        day_of_month   INTEGER NOT NULL,
        active         INTEGER NOT NULL DEFAULT 1,
        $cardCol
        last_generated TEXT,
        created_at     TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await d.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT ''
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
    await _createCards(d); // antes das tabelas que lhe fazem referência
    await d.execute('''
      CREATE TABLE expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        amount      REAL NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        spent_on    TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        card_id     INTEGER REFERENCES cards(id) ON DELETE SET NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await d.execute('CREATE INDEX idx_exp_date ON expenses(spent_on)');
    await d.execute('CREATE INDEX idx_exp_cat ON expenses(category_id)');
    await _createRecurring(d, withCard: true);
    await _createIncomeTables(d, withCard: true);

    final batch = d.batch();
    for (final (name, color, icon) in defaultCategories) {
      batch.insert('categories', {'name': name, 'color': color, 'icon': icon});
    }
    for (final (name, color, icon) in defaultCards) {
      batch.insert('cards', {'name': name, 'color': color, 'icon': icon});
    }
    await batch.commit(noResult: true);
  }
}
