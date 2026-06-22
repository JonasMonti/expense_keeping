/// Ecrã único: cabeçalho + dashboard do mês/ano — espelha app.py.
library;

import 'package:flutter/material.dart';

import '../charts/donut.dart';
import '../charts/year_line.dart';
import '../data/repository.dart';
import '../models/models.dart';
import 'add_expense_sheet.dart';
import 'categories_page.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _DashboardData {
  final double total;
  final List<CategoryTotal> byCat;
  final List<ExpenseView> expenses;
  final List<MonthTotal> yearRows;
  final int activeDays;
  const _DashboardData({
    required this.total,
    required this.byCat,
    required this.expenses,
    required this.yearRows,
    required this.activeDays,
  });
}

class _HomePageState extends State<HomePage> {
  final _repo = Repository();
  late int _year;
  late int _month;
  Future<_DashboardData>? _future;
  List<int> _years = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _loadData());
  }

  Future<_DashboardData> _loadData() async {
    final years = await _repo.availableYears();
    final now = DateTime.now();
    if (!years.contains(now.year)) years.insert(0, now.year);
    _years = years.isEmpty ? [_year] : years;

    final total = await _repo.totalForMonth(_year, _month);
    final byCat = await _repo.totalsByCategory(_year, _month);
    final expenses = await _repo.listExpenses(_year, _month);
    final yearRows = await _repo.monthlyTotalsForYear(_year);
    final activeDays = (await _repo.daysWithExpenses(_year, _month)).length;

    return _DashboardData(
      total: total,
      byCat: byCat,
      expenses: expenses,
      yearRows: yearRows,
      activeDays: activeDays,
    );
  }

  Future<void> _addExpense() async {
    final added = await showAddExpenseSheet(context, _repo);
    if (added) _refresh();
  }

  Future<void> _openCategories() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CategoriesPage(repo: _repo)),
    );
    if (changed == true) _refresh();
  }

  Future<void> _deleteExpense(ExpenseView e) async {
    await _repo.deleteExpense(e.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        tooltip: 'Nova despesa',
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent));
            }
            return RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: _buildContent(snap.data!),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(_DashboardData d) {
    return [
      _header(),
      const SizedBox(height: 16),
      _heroCard(d),
      if (_yearSum(d) > 0) ...[
        const SizedBox(height: 22),
        SectionTitle('Gastos por mês em $_year'),
        AppCard(child: YearLineChart(rows: d.yearRows, highlightMonth: _month)),
      ],
      if (d.total == 0)
        const Padding(
          padding: EdgeInsets.only(top: 22),
          child: AppCard(
            child: Row(
              children: [
                Text('ℹ️ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    'Sem despesas neste mês. Toca no + para adicionar.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        )
      else ...[
        const SizedBox(height: 22),
        const SectionTitle('Repartição por categoria'),
        AppCard(child: CategoryDonut(rows: d.byCat, total: d.total)),
        const SizedBox(height: 22),
        const SectionTitle('Onde gastaste mais'),
        AppCard(child: CategoryBars(rows: d.byCat, total: d.total)),
        const SizedBox(height: 22),
        SectionTitle('Histórico · ${d.expenses.length} despesas'),
        ...d.expenses.map(_dismissibleRow),
      ],
    ];
  }

  double _yearSum(_DashboardData d) =>
      d.yearRows.fold(0.0, (s, r) => s + r.total);

  Widget _dismissibleRow(ExpenseView e) {
    return Dismissible(
      key: ValueKey('exp_${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0x14B4231F),
        child: const Icon(Icons.delete_outline, color: Color(0xFFB4231F)),
      ),
      onDismissed: (_) => _deleteExpense(e),
      child: ExpenseRow(e),
    );
  }

  // -------------------------------------------------------------------- //
  // Cabeçalho: marca + seletor de mês/ano + gerir categorias
  // -------------------------------------------------------------------- //
  Widget _header() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: const Text('€',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: kDisplay,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Despesas',
              style: display(20, weight: FontWeight.w600)),
        ),
        _periodButton(),
        IconButton(
          icon: const Text('🏷️', style: TextStyle(fontSize: 18)),
          onPressed: _openCategories,
          tooltip: 'Gerir categorias',
        ),
      ],
    );
  }

  Widget _periodButton() {
    return InkWell(
      onTap: _pickPeriod,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${mesesCurtoPt[_month - 1]} $_year',
                style: const TextStyle(
                    fontFamily: kBody,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.ink)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPeriod() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text('Período', style: display(18)),
                const SizedBox(height: 14),
                // Ano
                Wrap(
                  spacing: 8,
                  children: [
                    for (final y in _years)
                      ChoiceChip(
                        label: Text('$y'),
                        selected: y == _year,
                        selectedColor: AppColors.accentSoft,
                        onSelected: (_) {
                          setSheet(() {});
                          setState(() => _year = y);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Meses
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      ChoiceChip(
                        label: Text(mesesCurtoPt[m - 1]),
                        selected: m == _month,
                        selectedColor: AppColors.accentSoft,
                        onSelected: (_) {
                          setState(() => _month = m);
                          Navigator.pop(ctx);
                          _refresh();
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    _refresh();
  }

  Widget _heroCard(_DashboardData d) {
    final label = 'Gasto em ${mesesPt[_month - 1]} de $_year';
    if (d.total <= 0) {
      return HeroCard(
        label: label,
        total: 0,
        stats: [statText('ainda sem despesas este mês')],
      );
    }
    final mediaDia = d.activeDays > 0 ? d.total / d.activeDays : 0.0;
    final top = d.byCat.isNotEmpty ? d.byCat.first : null;
    return HeroCard(
      label: label,
      total: d.total,
      stats: [
        statText('', bold: '${d.expenses.length}', suffix: ' despesas'),
        statText('média ', bold: fmtMoney(mediaDia), suffix: '/dia ativo'),
        if (top != null)
          statText('maior: ', bold: '${top.icon} ${top.category}'),
      ],
    );
  }
}
