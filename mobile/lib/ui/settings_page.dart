/// Definições: saldo inicial e acesso às receitas recorrentes.
///
/// O saldo inicial é o dinheiro que tinhas numa certa data; a partir daí a app
/// soma receitas e subtrai despesas para mostrar o saldo atual (ver
/// Repository.currentBalance).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import 'format.dart';
import 'recurring_income_page.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  final Repository repo;
  const SettingsPage({super.key, required this.repo});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _changed = false;
  bool _loaded = false;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (amount, since) = await widget.repo.getOpeningBalance();
    if (!mounted) return;
    setState(() {
      _amountCtrl.text = fmtNumber(amount);
      if (since != null) _date = since;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
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

  Future<void> _save() async {
    final raw = _amountCtrl.text.replaceAll(' ', '').replaceAll(',', '.').trim();
    final valor = double.tryParse(raw);
    if (valor == null) {
      setState(() => _saved = 'Valor inválido.');
      return;
    }
    await widget.repo
        .setOpeningBalance(double.parse(valor.toStringAsFixed(2)), _date);
    _changed = true;
    if (mounted) setState(() => _saved = 'Guardado ✓');
  }

  Future<void> _openRecurringIncomes() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecurringIncomePage(repo: widget.repo)),
    );
    if (changed == true) _changed = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
        title: Text('Definições', style: display(19)),
      ),
      body: !_loaded
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                const SectionTitle('Saldo inicial'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, left: 4),
                  child: Text(
                    'O dinheiro que tinhas numa certa data. A app soma receitas e '
                    'subtrai despesas a partir daí para mostrar o saldo atual.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                        ],
                        style: display(22),
                        decoration: const InputDecoration(
                          labelText: 'Valor inicial',
                          hintText: '0,00',
                          suffixText: kCurrency,
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'A partir de'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(fmtDate(_date),
                                  style: const TextStyle(
                                      fontFamily: kBody, fontSize: 15)),
                              Icon(Icons.calendar_today_outlined,
                                  size: 18, color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                      if (_saved != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_saved!,
                              style: TextStyle(
                                  fontFamily: kBody,
                                  fontSize: 13,
                                  color: AppColors.muted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Receitas recorrentes'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading:
                        const Text('🔁', style: TextStyle(fontSize: 20)),
                    title: const Text('Gerir receitas recorrentes',
                        style: TextStyle(
                            fontFamily: kBody,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('Ordenado, subsídio de alimentação…',
                        style: TextStyle(
                            fontFamily: kBody,
                            fontSize: 12.5,
                            color: AppColors.muted)),
                    trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap: _openRecurringIncomes,
                  ),
                ),
              ],
            ),
    );
  }
}
