/// CRUD e agregações — equivalente a src/repository.py.
///
/// As datas são guardadas como texto ISO 'yyyy-MM-dd', por isso o filtro por
/// ano/mês usa strftime() do SQLite (funciona sobre datas ISO).
library;

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database.dart';

class Repository {
  Future<Database> get _db => AppDatabase.instance.db;

  String _y(int year) => year.toString().padLeft(4, '0');
  String _m(int month) => month.toString().padLeft(2, '0');

  // ------------------------------------------------------------------ //
  // Categorias
  // ------------------------------------------------------------------ //
  Future<List<Category>> listCategories() async {
    final d = await _db;
    final rows = await d.query('categories', orderBy: 'name');
    return rows.map<Category>((m) => Category.fromMap(m)).toList();
  }

  Future<void> addCategory(String name,
      {String color = '#888888', String icon = '💸'}) async {
    final d = await _db;
    await d.insert('categories', {
      'name': name.trim(),
      'color': color,
      'icon': icon,
    });
  }

  Future<void> updateCategory(int id, String name, String color, String icon) async {
    final d = await _db;
    await d.update(
      'categories',
      {'name': name.trim(), 'color': color, 'icon': icon},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final d = await _db;
    await d.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> categoryHasExpenses(int id) async {
    final d = await _db;
    final c = Sqflite.firstIntValue(await d.rawQuery(
      'SELECT COUNT(*) FROM expenses WHERE category_id = ?',
      [id],
    ));
    return (c ?? 0) > 0;
  }

  // ------------------------------------------------------------------ //
  // Despesas
  // ------------------------------------------------------------------ //
  /// Insere a despesa e devolve o id gerado (útil para "Anular").
  Future<int> addExpense(Expense e) async {
    final d = await _db;
    return d.insert('expenses', e.toMap());
  }

  /// Atualiza uma despesa existente (requer e.id != null).
  Future<void> updateExpense(Expense e) async {
    final d = await _db;
    await d.update(
      'expenses',
      {
        'amount': e.amount,
        'description': e.description,
        'spent_on': e.toMap()['spent_on'],
        'category_id': e.categoryId,
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final d = await _db;
    await d.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// A despesa registada mais recentemente (alvo dos comandos de voz
  /// "apaga/edita a última despesa"). Null se ainda não há despesas.
  Future<ExpenseView?> lastExpense() async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT e.id, e.spent_on, e.amount, e.description, e.category_id,
             c.name AS category, c.color, c.icon
      FROM expenses e
      JOIN categories c ON c.id = e.category_id
      ORDER BY e.created_at DESC, e.id DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) return null;
    return ExpenseView.fromMap(rows.first);
  }

  Future<List<ExpenseView>> listExpenses(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT e.id, e.spent_on, e.amount, e.description, e.category_id,
             c.name AS category, c.color, c.icon
      FROM expenses e
      JOIN categories c ON c.id = e.category_id
      WHERE strftime('%Y', e.spent_on) = ? AND strftime('%m', e.spent_on) = ?
      ORDER BY e.spent_on DESC, e.id DESC
    ''', [_y(year), _m(month)]);
    return rows.map(ExpenseView.fromMap).toList();
  }

  // ------------------------------------------------------------------ //
  // Agregações
  // ------------------------------------------------------------------ //
  Future<double> totalForMonth(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM expenses
      WHERE strftime('%Y', spent_on) = ? AND strftime('%m', spent_on) = ?
    ''', [_y(year), _m(month)]);
    return (rows.first['total'] as num).toDouble();
  }

  Future<List<CategoryTotal>> totalsByCategory(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT c.name AS category, c.color, c.icon,
             COALESCE(SUM(e.amount), 0) AS total
      FROM categories c
      JOIN expenses e ON e.category_id = c.id
      WHERE strftime('%Y', e.spent_on) = ? AND strftime('%m', e.spent_on) = ?
      GROUP BY c.id
      ORDER BY total DESC
    ''', [_y(year), _m(month)]);
    return rows
        .map((m) => CategoryTotal(
              category: m['category'] as String,
              color: m['color'] as String,
              icon: m['icon'] as String,
              total: (m['total'] as num).toDouble(),
            ))
        .toList();
  }

  /// Total por mês de um ano (12 meses, com 0 onde não houve despesas).
  Future<List<MonthTotal>> monthlyTotalsForYear(int year) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT CAST(strftime('%m', spent_on) AS INTEGER) AS m,
             SUM(amount) AS total
      FROM expenses
      WHERE strftime('%Y', spent_on) = ?
      GROUP BY m
    ''', [_y(year)]);
    final found = <int, double>{
      for (final r in rows) (r['m'] as int): (r['total'] as num).toDouble(),
    };
    return [for (var mo = 1; mo <= 12; mo++) MonthTotal(mo, found[mo] ?? 0.0)];
  }

  /// Total por dia dentro de um mês (apenas dias com despesas).
  Future<List<int>> daysWithExpenses(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT DISTINCT CAST(strftime('%d', spent_on) AS INTEGER) AS d
      FROM expenses
      WHERE strftime('%Y', spent_on) = ? AND strftime('%m', spent_on) = ?
    ''', [_y(year), _m(month)]);
    return rows.map((r) => r['d'] as int).toList();
  }

  Future<List<int>> availableYears() async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT DISTINCT CAST(strftime('%Y', spent_on) AS INTEGER) AS y
      FROM expenses ORDER BY y DESC
    ''');
    return rows.map((r) => r['y'] as int).toList();
  }
}
