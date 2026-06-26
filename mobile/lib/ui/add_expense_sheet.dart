/// Bottom sheet para registar uma despesa — espelha dialog_add_expense() (app.py).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../ocr/receipt_scanner.dart';
import 'format.dart';
import 'theme.dart';

/// Mostra o sheet e devolve true se foi registada/alterada uma despesa.
///
/// Os parâmetros `initial*` permitem abrir o formulário já preenchido (ex.:
/// quando o registo por voz percebeu a categoria/descrição mas não o valor).
/// Passar [editing] abre o sheet em modo edição: prefill com os valores da
/// despesa e gravação por `updateExpense`.
Future<bool> showAddExpenseSheet(
  BuildContext context,
  Repository repo, {
  double? initialAmount,
  Category? initialCategory,
  String? initialDescription,
  ExpenseView? editing,
}) async {
  final cats = await repo.listCategories();
  if (!context.mounted) return false;
  if (cats.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cria primeiro uma categoria em Gerir categorias.')));
    return false;
  }
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _AddExpenseForm(
      repo: repo,
      categories: cats,
      initialAmount: initialAmount,
      initialCategory: initialCategory,
      initialDescription: initialDescription,
      editing: editing,
    ),
  );
  return result ?? false;
}

class _AddExpenseForm extends StatefulWidget {
  final Repository repo;
  final List<Category> categories;
  final double? initialAmount;
  final Category? initialCategory;
  final String? initialDescription;
  final ExpenseView? editing;
  const _AddExpenseForm({
    required this.repo,
    required this.categories,
    this.initialAmount,
    this.initialCategory,
    this.initialDescription,
    this.editing,
  });

  @override
  State<_AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<_AddExpenseForm> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late Category _category;
  DateTime _date = _today();
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    final amount = ed?.amount ?? widget.initialAmount;
    _amountCtrl = TextEditingController(
      text: amount != null
          ? amount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _descCtrl = TextEditingController(
        text: ed?.description ?? widget.initialDescription ?? '');
    if (ed != null) _date = DateTime(ed.spentOn.year, ed.spentOn.month, ed.spentOn.day);
    // A categoria inicial pode vir de outra lista (ou da despesa em edição);
    // faz match pela id para garantir que é a mesma instância dos itens do dropdown.
    final wantedId = ed?.categoryId ?? widget.initialCategory?.id;
    _category = wantedId == null
        ? widget.categories.first
        : widget.categories.firstWhere(
            (c) => c.id == wantedId,
            orElse: () => widget.categories.first,
          );
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
      setState(() => _error = 'Valor inválido. Escreve um número, ex: 12,50.');
      return;
    }
    if (valor <= 0) {
      setState(() => _error = 'O valor tem de ser maior que zero.');
      return;
    }
    final e = Expense(
      id: widget.editing?.id,
      amount: double.parse(valor.toStringAsFixed(2)),
      categoryId: _category.id!,
      spentOn: _date,
      description: _descCtrl.text.trim(),
    );
    if (_isEditing) {
      await widget.repo.updateExpense(e);
    } else {
      await widget.repo.addExpense(e);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Lê uma fatura com a câmara/galeria e preenche valor e descrição.
  Future<void> _scanReceipt() async {
    final parsed = await scanReceipt(context);
    if (parsed == null || !mounted) return;
    setState(() {
      if (parsed.amount != null) {
        _amountCtrl.text =
            parsed.amount!.toStringAsFixed(2).replaceAll('.', ',');
      }
      // Só sugere a descrição se o campo ainda estiver vazio.
      if (_descCtrl.text.trim().isEmpty && parsed.description.isNotEmpty) {
        _descCtrl.text = parsed.description;
      }
      _error = null;
    });
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
          Row(
            children: [
              Expanded(
                child: Text(_isEditing ? 'Editar despesa' : 'Registar despesa',
                    style: display(20)),
              ),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: _scanReceipt,
                  icon: const Text('📷', style: TextStyle(fontSize: 16)),
                  label: const Text('Ler fatura',
                      style: TextStyle(
                          fontFamily: kBody,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                ),
            ],
          ),
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
              hintText: '12,50',
              suffixText: kCurrency,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Category>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(
                  value: c,
                  child: Text('${c.icon} ${c.name}'),
                ),
            ],
            onChanged: (c) => setState(() => _category = c!),
          ),
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
                  const Icon(Icons.calendar_today_outlined,
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
              hintText: 'opcional — ex: almoço',
            ),
          ),
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
