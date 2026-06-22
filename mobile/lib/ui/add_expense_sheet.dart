/// Bottom sheet para registar uma despesa — espelha dialog_add_expense() (app.py).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../models/models.dart';
import 'format.dart';
import 'theme.dart';

/// Mostra o sheet e devolve true se foi registada uma despesa.
Future<bool> showAddExpenseSheet(BuildContext context, Repository repo) async {
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
    builder: (_) => _AddExpenseForm(repo: repo, categories: cats),
  );
  return result ?? false;
}

class _AddExpenseForm extends StatefulWidget {
  final Repository repo;
  final List<Category> categories;
  const _AddExpenseForm({required this.repo, required this.categories});

  @override
  State<_AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<_AddExpenseForm> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late Category _category = widget.categories.first;
  DateTime _date = _today();
  String? _error;

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
    await widget.repo.addExpense(Expense(
      amount: double.parse(valor.toStringAsFixed(2)),
      categoryId: _category.id!,
      spentOn: _date,
      description: _descCtrl.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop(true);
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
          Text('Registar despesa', style: display(20)),
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
              child: const Text('💾  Guardar',
                  style: TextStyle(
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
