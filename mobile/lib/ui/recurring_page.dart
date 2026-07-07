/// Gerir despesas recorrentes (renda, assinaturas, passe…).
///
/// Cada regra gera automaticamente uma despesa por mês, no dia escolhido. A
/// materialização acontece no arranque da app (ver Repository.generateDueRecurring).
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../models/models.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

class RecurringPage extends StatefulWidget {
  final Repository repo;
  const RecurringPage({super.key, required this.repo});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  List<RecurringView> _rules = [];
  List<Category> _cats = [];
  List<Card> _cards = [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await widget.repo.listRecurring();
    final cats = await widget.repo.listCategories();
    final cards = await widget.repo.listCards();
    if (mounted) {
      setState(() {
        _rules = rules;
        _cats = cats;
        _cards = cards;
      });
    }
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
        title: Text('Recorrentes', style: display(19)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Criadas automaticamente todos os meses, no dia escolhido.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          if (_rules.isEmpty)
            AppCard(
              child: Row(
                children: [
                  const Text('🔁 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      'Sem despesas recorrentes. Toca em ➕ para criar a renda, '
                      'uma assinatura ou o passe.',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          for (final r in _rules) _ruleTile(r),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cats.isEmpty ? null : () => _showEditor(null),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Text('➕', style: TextStyle(fontSize: 16)),
            label: const Text('Nova recorrente',
                style:
                    TextStyle(fontFamily: kBody, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _ruleTile(RecurringView r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Opacity(
          opacity: r.active ? 1 : 0.5,
          child: Row(
            children: [
              CategoryChip(icon: r.icon, color: r.color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.description.isNotEmpty ? r.description : r.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: kBody,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Todo o dia ${r.dayOfMonth} · ${r.category}'
                      '${r.active ? '' : ' · em pausa'}',
                      style: TextStyle(
                          fontFamily: kBody,
                          fontSize: 12.5,
                          color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(fmtMoney(r.amount), style: display(15)),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: AppColors.muted),
                onPressed: () => _showEditor(r),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: AppColors.muted),
                onPressed: () => _confirmDelete(r),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(RecurringView r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Eliminar recorrente?', style: display(18)),
        content: Text(
          'Deixa de criar «${r.description.isNotEmpty ? r.description : r.category}» '
          'todos os meses. As despesas já criadas mantêm-se.',
          style: const TextStyle(fontFamily: kBody, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: TextStyle(fontFamily: kBody, color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(
                      fontFamily: kBody,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB4231F)))),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.deleteRecurring(r.id);
      _changed = true;
      _load();
    }
  }

  Future<void> _showEditor(RecurringView? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _RecurringEditor(
          repo: widget.repo,
          categories: _cats,
          cards: _cards,
          existing: existing),
    );
    if (saved == true) {
      _changed = true;
      _load();
    }
  }
}

class _RecurringEditor extends StatefulWidget {
  final Repository repo;
  final List<Category> categories;
  final List<Card> cards;
  final RecurringView? existing;
  const _RecurringEditor({
    required this.repo,
    required this.categories,
    required this.cards,
    this.existing,
  });

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late Category _category;
  int? _cardId;
  late int _day;
  late bool _active;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _day = e?.dayOfMonth ?? 1;
    _active = e?.active ?? true;
    final wantedId = e?.categoryId;
    _category = wantedId == null
        ? widget.categories.first
        : widget.categories.firstWhere((c) => c.id == wantedId,
            orElse: () => widget.categories.first);
    final wantedCard = e?.cardId;
    _cardId = widget.cards.any((c) => c.id == wantedCard) ? wantedCard : null;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.replaceAll(',', '.').trim();
    final valor = double.tryParse(raw);
    if (valor == null || valor <= 0) {
      setState(() => _error = 'Valor inválido. Escreve um número, ex: 12,50.');
      return;
    }
    final rule = Recurring(
      id: widget.existing?.id,
      amount: double.parse(valor.toStringAsFixed(2)),
      description: _descCtrl.text.trim(),
      categoryId: _category.id!,
      dayOfMonth: _day,
      active: _active,
      cardId: _cardId,
    );
    if (_isEditing) {
      await widget.repo.updateRecurring(rule);
    } else {
      await widget.repo.addRecurring(rule);
    }
    if (mounted) Navigator.of(context).pop(true);
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
          Text(_isEditing ? 'Editar recorrente' : 'Nova recorrente',
              style: display(20)),
          const SizedBox(height: 18),
          TextField(
            controller: _amountCtrl,
            autofocus: !_isEditing,
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
                DropdownMenuItem(value: c, child: Text('${c.icon} ${c.name}')),
            ],
            onChanged: (c) => setState(() => _category = c!),
          ),
          if (widget.cards.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _cardId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cartão'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Sem cartão —')),
                for (final c in widget.cards)
                  DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')),
              ],
              onChanged: (v) => setState(() => _cardId = v),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _day,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Dia do mês'),
            items: [
              for (var d = 1; d <= 31; d++)
                DropdownMenuItem(value: d, child: Text('Dia $d')),
            ],
            onChanged: (d) => setState(() => _day = d!),
          ),
          if (_day > 28)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Nos meses mais curtos usa o último dia.',
                style: TextStyle(color: AppColors.faint, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'ex: renda, Netflix, passe',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.accent,
            title: const Text('Ativa',
                style: TextStyle(fontFamily: kBody, fontSize: 14.5)),
            subtitle: Text('Desliga para pausar sem apagar',
                style: TextStyle(
                    fontFamily: kBody, fontSize: 12.5, color: AppColors.muted)),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFB4231F), fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
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
