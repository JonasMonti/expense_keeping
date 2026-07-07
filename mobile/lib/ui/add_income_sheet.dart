/// Bottom sheet para registar uma receita — espelha dialog_add_income() (app.py)
/// e [showAddExpenseSheet], mas com `source` (origem) em vez de categoria.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../models/models.dart';
import 'format.dart';
import 'recurring_income_page.dart';
import 'theme.dart';

/// Origens de receita sugeridas no formulário.
const List<String> kIncomeSources = [
  'Ordenado',
  'Subsídio de alimentação',
  'Extra',
  'Reembolso',
  'Outros',
];

/// Mostra o sheet e devolve true se foi registada/alterada uma receita.
Future<bool> showAddIncomeSheet(
  BuildContext context,
  Repository repo, {
  IncomeView? editing,
}) async {
  final cards = await repo.listCards();
  if (!context.mounted) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _AddIncomeForm(repo: repo, cards: cards, editing: editing),
  );
  return result ?? false;
}

class _AddIncomeForm extends StatefulWidget {
  final Repository repo;
  final List<Card> cards;
  final IncomeView? editing;
  const _AddIncomeForm({required this.repo, required this.cards, this.editing});

  @override
  State<_AddIncomeForm> createState() => _AddIncomeFormState();
}

class _AddIncomeFormState extends State<_AddIncomeForm> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _source;
  int? _cardId;
  DateTime _date = _today();
  bool _repeatMonthly = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _amountCtrl = TextEditingController(
      text: ed != null ? ed.amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _descCtrl = TextEditingController(text: ed?.description ?? '');
    // Mantém a origem em edição mesmo que não esteja na lista de sugestões.
    final wanted = ed?.source ?? kIncomeSources.first;
    _source = kIncomeSources.contains(wanted) ? wanted : kIncomeSources.first;
    final wantedCard = ed?.cardId;
    _cardId = widget.cards.any((c) => c.id == wantedCard) ? wantedCard : null;
    final initialDate = ed?.receivedOn;
    if (initialDate != null) {
      _date = DateTime(initialDate.year, initialDate.month, initialDate.day);
    }
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _amountCtrl.text.replaceAll(',', '.').trim();
    final valor = double.tryParse(raw);
    if (valor == null) {
      setState(() => _error = 'Valor inválido. Escreve um número, ex: 1500,00.');
      return;
    }
    if (valor <= 0) {
      setState(() => _error = 'O valor tem de ser maior que zero.');
      return;
    }
    final amount = double.parse(valor.toStringAsFixed(2));
    final i = Income(
      id: widget.editing?.id,
      amount: amount,
      source: _source,
      receivedOn: _date,
      description: _descCtrl.text.trim(),
      cardId: _cardId,
    );
    if (_isEditing) {
      await widget.repo.updateIncome(i);
    } else {
      await widget.repo.addIncome(i);
      // "Repetir todos os meses" → cria também uma regra recorrente, no dia
      // escolhido para esta receita.
      if (_repeatMonthly) {
        await widget.repo.addRecurringIncome(RecurringIncome(
          amount: amount,
          source: _source,
          description: i.description,
          dayOfMonth: _date.day,
          cardId: _cardId,
        ));
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openRecurringList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecurringIncomePage(repo: widget.repo)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
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
          Text(_isEditing ? 'Editar receita' : 'Registar receita',
              style: display(20)),
          const SizedBox(height: 18),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: display(22),
            decoration: const InputDecoration(
              labelText: 'Valor',
              hintText: '1500,00',
              suffixText: kCurrency,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Origem'),
            items: [
              for (final s in kIncomeSources)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (s) => setState(() => _source = s!),
          ),
          if (widget.cards.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _cardId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Carregar cartão'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Sem cartão —')),
                for (final c in widget.cards)
                  DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')),
              ],
              onChanged: (v) => setState(() => _cardId = v),
            ),
          ],
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Data'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmtDate(_date),
                      style: const TextStyle(fontFamily: kBody, fontSize: 15)),
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'opcional — ex: prémio',
            ),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accent,
              title: const Text('Repetir todos os meses',
                  style: TextStyle(fontFamily: kBody, fontSize: 14.5)),
              subtitle: Text(
                'Cria automaticamente no dia ${_date.day} de cada mês',
                style: TextStyle(
                    fontFamily: kBody, fontSize: 12.5, color: AppColors.muted),
              ),
              value: _repeatMonthly,
              onChanged: (v) => setState(() => _repeatMonthly = v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openRecurringList,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('🔁  Ver receitas recorrentes',
                    style: TextStyle(fontFamily: kBody, fontSize: 13)),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFB4231F), fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isEditing ? '💾  Guardar alterações' : '💾  Guardar',
                  style: const TextStyle(
                      fontFamily: kBody,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
