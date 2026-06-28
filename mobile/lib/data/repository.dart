/// CRUD e agregações — equivalente a src/repository.py.
///
/// As datas são guardadas como texto ISO 'yyyy-MM-dd', por isso o filtro por
/// ano/mês usa strftime() do SQLite (funciona sobre datas ISO).
library;

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database.dart';

class Repository {
  /// Override da base de dados (apenas para testes); em produção usa o singleton.
  final Future<Database> Function()? _dbOverride;
  Repository([this._dbOverride]);

  Future<Database> get _db {
    final override = _dbOverride;
    return override != null ? override() : AppDatabase.instance.db;
  }

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
  // Despesas recorrentes
  // ------------------------------------------------------------------ //
  Future<List<RecurringView>> listRecurring() async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT r.id, r.amount, r.description, r.category_id, r.day_of_month,
             r.active, c.name AS category, c.color, c.icon
      FROM recurring r
      JOIN categories c ON c.id = r.category_id
      ORDER BY r.day_of_month, r.id
    ''');
    return rows.map(RecurringView.fromMap).toList();
  }

  /// Cria uma regra. [lastGenerated] arranca no mês anterior ao atual, para que
  /// a geração comece já no mês corrente (e faça catch-up se a app não abrir).
  Future<int> addRecurring(Recurring r, {DateTime? now}) async {
    final d = await _db;
    final n = now ?? DateTime.now();
    final prev = DateTime(n.year, n.month - 1, 1);
    return d.insert('recurring', {
      'amount': r.amount,
      'description': r.description.trim(),
      'category_id': r.categoryId,
      'day_of_month': r.dayOfMonth,
      'active': r.active ? 1 : 0,
      'last_generated': _ym(prev),
    });
  }

  Future<void> updateRecurring(Recurring r) async {
    final d = await _db;
    await d.update(
      'recurring',
      {
        'amount': r.amount,
        'description': r.description.trim(),
        'category_id': r.categoryId,
        'day_of_month': r.dayOfMonth,
        'active': r.active ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<void> deleteRecurring(int id) async {
    final d = await _db;
    await d.delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  /// Materializa as despesas recorrentes em falta até ao mês/dia atual.
  ///
  /// Para cada regra ativa, gera uma despesa por cada mês entre o último gerado
  /// e o mês corrente (catch-up se a app esteve fechada). No mês corrente só
  /// gera depois de chegar o dia da regra; o dia é ajustado ao tamanho do mês
  /// (ex.: dia 31 em fevereiro → último dia). Devolve quantas despesas criou.
  Future<int> generateDueRecurring({DateTime? now}) async {
    final d = await _db;
    final today = _dateOnly(now ?? DateTime.now());
    final todayIdx = _ymIndex(today.year, today.month);

    final rules = await d.query('recurring', where: 'active = 1');
    var created = 0;

    for (final r in rules) {
      final id = r['id'] as int;
      final amount = (r['amount'] as num).toDouble();
      final desc = (r['description'] as String?) ?? '';
      final catId = r['category_id'] as int;
      final day = r['day_of_month'] as int;
      final lastGen = r['last_generated'] as String?;

      // Cursor = primeiro mês a considerar (o seguinte ao último gerado).
      var (cy, cm) = lastGen != null ? _ymAfter(lastGen) : (today.year, today.month);
      String? newLast = lastGen;

      while (_ymIndex(cy, cm) <= todayIdx) {
        final isCurrent = cy == today.year && cm == today.month;
        final dim = _daysInMonth(cy, cm);
        final dd = day > dim ? dim : day; // dia ajustado ao tamanho do mês
        if (isCurrent && today.day < dd) break; // ainda não chegou o dia

        await d.insert('expenses', {
          'amount': amount,
          'description': desc,
          'spent_on': _isoDate(DateTime(cy, cm, dd)),
          'category_id': catId,
        });
        created++;
        newLast = _ymOf(cy, cm);

        // Próximo mês.
        cm += 1;
        if (cm > 12) {
          cm = 1;
          cy += 1;
        }
      }

      if (newLast != lastGen) {
        await d.update('recurring', {'last_generated': newLast},
            where: 'id = ?', whereArgs: [id]);
      }
    }
    return created;
  }

  // Auxiliares de ano-mês.
  String _ym(DateTime d) => '${_y(d.year)}-${_m(d.month)}';
  String _ymOf(int y, int m) => '${_y(y)}-${_m(m)}';
  int _ymIndex(int y, int m) => y * 12 + (m - 1);
  (int, int) _ymAfter(String ym) {
    final p = ym.split('-');
    var y = int.parse(p[0]);
    var m = int.parse(p[1]) + 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
    return (y, m);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;
  String _isoDate(DateTime d) =>
      '${_y(d.year)}-${_m(d.month)}-${d.day.toString().padLeft(2, '0')}';

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
      SELECT y FROM (
        SELECT DISTINCT CAST(strftime('%Y', spent_on) AS INTEGER) AS y FROM expenses
        UNION
        SELECT DISTINCT CAST(strftime('%Y', received_on) AS INTEGER) AS y FROM incomes
      ) ORDER BY y DESC
    ''');
    return rows.map((r) => r['y'] as int).toList();
  }

  // ------------------------------------------------------------------ //
  // Receitas
  // ------------------------------------------------------------------ //
  Future<int> addIncome(Income i) async {
    final d = await _db;
    return d.insert('incomes', i.toMap());
  }

  Future<void> updateIncome(Income i) async {
    final d = await _db;
    await d.update(
      'incomes',
      {
        'amount': i.amount,
        'source': i.source,
        'description': i.description,
        'received_on': i.toMap()['received_on'],
      },
      where: 'id = ?',
      whereArgs: [i.id],
    );
  }

  Future<void> deleteIncome(int id) async {
    final d = await _db;
    await d.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<IncomeView>> listIncomes(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT id, received_on, amount, source, description
      FROM incomes
      WHERE strftime('%Y', received_on) = ? AND strftime('%m', received_on) = ?
      ORDER BY received_on DESC, id DESC
    ''', [_y(year), _m(month)]);
    return rows.map(IncomeView.fromMap).toList();
  }

  Future<double> incomeTotalForMonth(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM incomes
      WHERE strftime('%Y', received_on) = ? AND strftime('%m', received_on) = ?
    ''', [_y(year), _m(month)]);
    return (rows.first['total'] as num).toDouble();
  }

  Future<List<SourceTotal>> incomesBySource(int year, int month) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT source, COALESCE(SUM(amount), 0) AS total
      FROM incomes
      WHERE strftime('%Y', received_on) = ? AND strftime('%m', received_on) = ?
      GROUP BY source
      ORDER BY total DESC
    ''', [_y(year), _m(month)]);
    return rows
        .map((m) => SourceTotal(
              source: m['source'] as String,
              total: (m['total'] as num).toDouble(),
            ))
        .toList();
  }

  /// Total de receitas por mês de um ano (12 meses, com 0 onde não houve).
  Future<List<MonthTotal>> monthlyIncomeForYear(int year) async {
    final d = await _db;
    final rows = await d.rawQuery('''
      SELECT CAST(strftime('%m', received_on) AS INTEGER) AS m,
             SUM(amount) AS total
      FROM incomes
      WHERE strftime('%Y', received_on) = ?
      GROUP BY m
    ''', [_y(year)]);
    final found = <int, double>{
      for (final r in rows) (r['m'] as int): (r['total'] as num).toDouble(),
    };
    return [for (var mo = 1; mo <= 12; mo++) MonthTotal(mo, found[mo] ?? 0.0)];
  }

  // ------------------------------------------------------------------ //
  // Receitas recorrentes (espelha as despesas recorrentes)
  // ------------------------------------------------------------------ //
  Future<List<RecurringIncome>> listRecurringIncomes() async {
    final d = await _db;
    final rows = await d.query('recurring_incomes',
        orderBy: 'day_of_month, id');
    return rows.map(RecurringIncome.fromMap).toList();
  }

  /// Cria uma regra. [lastGenerated] arranca no mês anterior ao atual (igual a
  /// [addRecurring]).
  Future<int> addRecurringIncome(RecurringIncome r, {DateTime? now}) async {
    final d = await _db;
    final n = now ?? DateTime.now();
    final prev = DateTime(n.year, n.month - 1, 1);
    return d.insert('recurring_incomes', {
      'amount': r.amount,
      'source': r.source.trim(),
      'description': r.description.trim(),
      'day_of_month': r.dayOfMonth,
      'active': r.active ? 1 : 0,
      'last_generated': _ym(prev),
    });
  }

  Future<void> updateRecurringIncome(RecurringIncome r) async {
    final d = await _db;
    await d.update(
      'recurring_incomes',
      {
        'amount': r.amount,
        'source': r.source.trim(),
        'description': r.description.trim(),
        'day_of_month': r.dayOfMonth,
        'active': r.active ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<void> deleteRecurringIncome(int id) async {
    final d = await _db;
    await d.delete('recurring_incomes', where: 'id = ?', whereArgs: [id]);
  }

  /// Materializa as receitas recorrentes em falta até ao mês/dia atual. Mesma
  /// lógica de [generateDueRecurring], mas inserindo em `incomes`. Devolve quantas
  /// receitas criou.
  Future<int> generateDueRecurringIncomes({DateTime? now}) async {
    final d = await _db;
    final today = _dateOnly(now ?? DateTime.now());
    final todayIdx = _ymIndex(today.year, today.month);

    final rules = await d.query('recurring_incomes', where: 'active = 1');
    var created = 0;

    for (final r in rules) {
      final id = r['id'] as int;
      final amount = (r['amount'] as num).toDouble();
      final source = (r['source'] as String?) ?? 'Outros';
      final desc = (r['description'] as String?) ?? '';
      final day = r['day_of_month'] as int;
      final lastGen = r['last_generated'] as String?;

      var (cy, cm) =
          lastGen != null ? _ymAfter(lastGen) : (today.year, today.month);
      String? newLast = lastGen;

      while (_ymIndex(cy, cm) <= todayIdx) {
        final isCurrent = cy == today.year && cm == today.month;
        final dim = _daysInMonth(cy, cm);
        final dd = day > dim ? dim : day;
        if (isCurrent && today.day < dd) break;

        await d.insert('incomes', {
          'amount': amount,
          'source': source,
          'description': desc,
          'received_on': _isoDate(DateTime(cy, cm, dd)),
        });
        created++;
        newLast = _ymOf(cy, cm);

        cm += 1;
        if (cm > 12) {
          cm = 1;
          cy += 1;
        }
      }

      if (newLast != lastGen) {
        await d.update('recurring_incomes', {'last_generated': newLast},
            where: 'id = ?', whereArgs: [id]);
      }
    }
    return created;
  }

  // ------------------------------------------------------------------ //
  // Definições e saldo
  // ------------------------------------------------------------------ //
  Future<String?> getSetting(String key) async {
    final d = await _db;
    final rows =
        await d.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final d = await _db;
    await d.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// (valor inicial, data inicial). Por defeito (0, null).
  Future<(double, DateTime?)> getOpeningBalance() async {
    final amountRaw = await getSetting('opening_balance');
    final dateRaw = await getSetting('opening_balance_date');
    final amount = amountRaw == null ? 0.0 : double.tryParse(amountRaw) ?? 0.0;
    final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);
    return (amount, date);
  }

  Future<void> setOpeningBalance(double amount, DateTime date) async {
    await setSetting('opening_balance', amount.toString());
    await setSetting('opening_balance_date', _isoDate(_dateOnly(date)));
  }

  /// Saldo atual = valor inicial + receitas − despesas, da data inicial até hoje.
  /// Itens com data futura não contam.
  Future<double> currentBalance({DateTime? now}) async {
    final d = await _db;
    final today = _isoDate(_dateOnly(now ?? DateTime.now()));
    final (opening, since) = await getOpeningBalance();
    final sinceIso = since == null ? null : _isoDate(_dateOnly(since));

    final incWhere = sinceIso == null
        ? 'received_on <= ?'
        : 'received_on >= ? AND received_on <= ?';
    final incArgs = sinceIso == null ? [today] : [sinceIso, today];
    final expWhere = sinceIso == null
        ? 'spent_on <= ?'
        : 'spent_on >= ? AND spent_on <= ?';
    final expArgs = sinceIso == null ? [today] : [sinceIso, today];

    final inc = Sqflite.firstIntValue(await d.rawQuery(
            'SELECT CAST(ROUND(COALESCE(SUM(amount),0)*100) AS INTEGER) FROM incomes WHERE $incWhere',
            incArgs)) ??
        0;
    final exp = Sqflite.firstIntValue(await d.rawQuery(
            'SELECT CAST(ROUND(COALESCE(SUM(amount),0)*100) AS INTEGER) FROM expenses WHERE $expWhere',
            expArgs)) ??
        0;
    return opening + (inc - exp) / 100.0;
  }

  Future<double> netForMonth(int year, int month) async {
    final inc = await incomeTotalForMonth(year, month);
    final exp = await totalForMonth(year, month);
    return inc - exp;
  }
}
