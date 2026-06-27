/// Ecrã único: cabeçalho + dashboard do mês/ano — espelha app.py.
library;

import 'package:flutter/material.dart';

import '../charts/donut.dart';
import '../charts/year_line.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../voice/voice_intake.dart';
import '../voice/voice_listener.dart';
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _repo = Repository();
  late final VoiceListener _voice;
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
    // Refrescar quando uma despesa é criada/alterada/anulada por voz.
    expensesRevision.addListener(_onExpensesChanged);
    // Voz mãos-livres: ouve ao abrir + escuta contínua por palavra-chave.
    _voice = VoiceListener(_repo);
    WidgetsBinding.instance.addObserver(this);
    _voice.start();
  }

  @override
  void dispose() {
    expensesRevision.removeListener(_onExpensesChanged);
    WidgetsBinding.instance.removeObserver(this);
    _voice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _voice.onForeground();
    } else {
      _voice.onBackground();
    }
  }

  void _onExpensesChanged() {
    if (mounted) _refresh();
  }

  void _refresh() {
    setState(() => _future = _loadData());
  }

  Future<_DashboardData> _loadData() async {
    // Materializa as despesas recorrentes em falta (mês corrente + catch-up).
    await _repo.generateDueRecurring();

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

  Future<void> _editExpense(ExpenseView e) async {
    final changed = await showAddExpenseSheet(context, _repo, editing: e);
    if (changed) _refresh();
  }

  Future<void> _deleteExpense(ExpenseView e) async {
    await _repo.deleteExpense(e.id);
    _refresh();
  }

  /// Pergunta antes de apagar (evita apagar sem querer com um deslize acidental).
  Future<bool> _confirmDelete(ExpenseView e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Apagar despesa?', style: display(18)),
        content: Text(
          'Vais apagar ${fmtMoney(e.amount)} · ${e.icon} ${e.category}'
          '${e.description.isNotEmpty ? ' — ${e.description}' : ''}.\n'
          'Esta ação não pode ser anulada.',
          style: const TextStyle(fontFamily: kBody, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(fontFamily: kBody, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar',
                style: TextStyle(
                    fontFamily: kBody,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB4231F))),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _voiceIndicator(),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_add',
            onPressed: _addExpense,
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            tooltip: 'Nova despesa',
            child: const Icon(Icons.add, size: 28),
          ),
        ],
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
      // Pergunta antes de remover; só apaga se confirmar.
      confirmDismiss: (_) => _confirmDelete(e),
      onDismissed: (_) => _deleteExpense(e),
      child: InkWell(
        onTap: () => _editExpense(e),
        child: ExpenseRow(e),
      ),
    );
  }

  /// Indicador de microfone (substitui o antigo botão de voz).
  ///
  /// Não serve para "começar a ouvir" — a app já ouve sozinha; serve para
  /// SILENCIAR/reativar a escuta (bateria/privacidade) e mostrar o estado.
  Widget _voiceIndicator() {
    return ListenableBuilder(
      listenable: _voice,
      builder: (context, _) {
        if (_voice.status == VoiceStatus.unavailable) {
          return const SizedBox.shrink();
        }
        final on = _voice.enabled;
        final listening = on && _voice.status == VoiceStatus.listening;
        final heard = _voice.lastHeard.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Eco do que foi reconhecido — confirma que o micro ouve mesmo
            // (e ajuda a diagnosticar quando um comando não é entendido).
            if (on && heard.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🎤 $heard',
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.faint),
                  ),
                ),
              ),
            FloatingActionButton.small(
              heroTag: 'fab_voz',
              onPressed: _voice.toggle,
              backgroundColor: AppColors.surface,
              foregroundColor: on ? AppColors.accent : AppColors.faint,
              tooltip: on
                  ? 'A ouvir · tocar para silenciar'
                  : 'Voz silenciada · tocar para ativar',
              child: Icon(
                on ? (listening ? Icons.mic : Icons.mic_none) : Icons.mic_off,
                size: 20,
              ),
            ),
          ],
        );
      },
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
