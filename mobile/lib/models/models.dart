/// Modelos de dados — equivalentes a src/models.py (Category e Expense).
library;

class Category {
  final int? id;
  final String name;
  final String color; // hex, ex. "#0F7B66"
  final String icon; // emoji

  const Category({
    this.id,
    required this.name,
    this.color = '#888888',
    this.icon = '💸',
  });

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        color: (m['color'] as String?) ?? '#888888',
        icon: (m['icon'] as String?) ?? '💸',
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': color,
        'icon': icon,
      };

  Category copyWith({int? id, String? name, String? color, String? icon}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
      );
}

class Expense {
  final int? id;
  final double amount;
  final String description;
  final DateTime spentOn; // só data (sem hora)
  final int categoryId;

  const Expense({
    this.id,
    required this.amount,
    this.description = '',
    required this.spentOn,
    required this.categoryId,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'description': description,
        // guardado como ISO yyyy-MM-dd, igual ao SQLite Date do projeto original
        'spent_on': _isoDate(spentOn),
        'category_id': categoryId,
      };
}

/// Linha de despesa já com a categoria resolvida (equivalente ao dict de list_expenses).
class ExpenseView {
  final int id;
  final DateTime spentOn;
  final double amount;
  final String description;
  final String category;
  final String color;
  final String icon;

  const ExpenseView({
    required this.id,
    required this.spentOn,
    required this.amount,
    required this.description,
    required this.category,
    required this.color,
    required this.icon,
  });

  factory ExpenseView.fromMap(Map<String, Object?> m) => ExpenseView(
        id: m['id'] as int,
        spentOn: DateTime.parse(m['spent_on'] as String),
        amount: (m['amount'] as num).toDouble(),
        description: (m['description'] as String?) ?? '',
        category: m['category'] as String,
        color: m['color'] as String,
        icon: m['icon'] as String,
      );
}

/// Total agregado por categoria (equivalente ao dict de totals_by_category).
class CategoryTotal {
  final String category;
  final String color;
  final String icon;
  final double total;

  const CategoryTotal({
    required this.category,
    required this.color,
    required this.icon,
    required this.total,
  });
}

/// Total de um mês (para a linha anual).
class MonthTotal {
  final int month; // 1..12
  final double total;
  const MonthTotal(this.month, this.total);
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
