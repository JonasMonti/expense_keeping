/// Gerir cartões / meios de pagamento — espelha [CategoriesPage].
///
/// Cada cartão funciona como carteira: saldo = saldo inicial + carregamentos −
/// despesas (ver Repository.cardBalances). Aqui só se editam os cartões em si.
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../models/models.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

/// Paleta de cores sugerida (igual à das categorias, com o esmeralda à cabeça).
const List<String> _palette = [
  '#0F7B66', '#FF6B6B', '#4D96FF', '#6BCB77',
  '#FF9F45', '#9B5DE5', '#F15BB5', '#00BBF9',
  '#F4A259', '#2A9D8F', '#E76F51', '#888888',
];

class CardsPage extends StatefulWidget {
  final Repository repo;
  const CardsPage({super.key, required this.repo});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  List<Card> _cards = [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await widget.repo.listCards();
    if (mounted) setState(() => _cards = cards);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: Text('Cartões', style: display(19)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Cada cartão é uma carteira: saldo inicial + carregamentos − despesas.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            for (final c in _cards) _cardTile(c),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Text('➕', style: TextStyle(fontSize: 16)),
              label: const Text('Novo cartão',
                  style: TextStyle(
                      fontFamily: kBody, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTile(Card c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CategoryChip(icon: c.icon, color: c.color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: kBody,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  Text('Saldo inicial ${fmtMoney(c.openingBalance)}',
                      style: TextStyle(
                          fontFamily: kBody,
                          fontSize: 12.5,
                          color: AppColors.muted)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.muted),
              onPressed: () => _showEdit(c),
              tooltip: 'Editar',
            ),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
              onPressed: () => _confirmDelete(c),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Card c) async {
    if (await widget.repo.cardHasMovements(c.id!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '«${c.name}» tem movimentos associados e não pode ser eliminado.')));
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Eliminar cartão', style: display(18)),
        content: Text('Eliminar «${c.name}»?',
            style: const TextStyle(fontFamily: kBody, fontSize: 14, height: 1.4)),
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
      await widget.repo.deleteCard(c.id!);
      _changed = true;
      _load();
    }
  }

  Future<void> _showAdd() => _showEditor(null);
  Future<void> _showEdit(Card c) => _showEditor(c);

  Future<void> _showEditor(Card? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CardEditor(repo: widget.repo, existing: existing),
    );
    if (saved == true) {
      _changed = true;
      _load();
    }
  }
}

class _CardEditor extends StatefulWidget {
  final Repository repo;
  final Card? existing;
  const _CardEditor({required this.repo, this.existing});

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _iconCtrl =
      TextEditingController(text: widget.existing?.icon ?? '💳');
  late final _openingCtrl = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.openingBalance
            .toStringAsFixed(2)
            .replaceAll('.', ',')
        : '',
  );
  late String _color = widget.existing?.color ?? '#0F7B66';
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escreve um nome para o cartão.');
      return;
    }
    final icon = _iconCtrl.text.trim().isEmpty ? '💳' : _iconCtrl.text.trim();
    final rawOpening = _openingCtrl.text.replaceAll(',', '.').trim();
    final opening = rawOpening.isEmpty ? 0.0 : double.tryParse(rawOpening);
    if (opening == null) {
      setState(() => _error = 'Saldo inicial inválido. Ex: 25,00.');
      return;
    }
    if (widget.existing == null) {
      await widget.repo.addCard(Card(
        name: name,
        color: _color,
        icon: icon,
        openingBalance: double.parse(opening.toStringAsFixed(2)),
      ));
    } else {
      await widget.repo.updateCard(widget.existing!.copyWith(
        name: name,
        color: _color,
        icon: icon,
        openingBalance: double.parse(opening.toStringAsFixed(2)),
      ));
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
          Text(widget.existing == null ? 'Novo cartão' : 'Editar cartão',
              style: display(20)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _iconCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Emoji',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: widget.existing == null,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _openingCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: display(18),
            decoration: const InputDecoration(
              labelText: 'Saldo inicial',
              hintText: '0,00',
              suffixText: kCurrency,
            ),
          ),
          const SizedBox(height: 16),
          Text('Cor',
              style: TextStyle(
                  fontFamily: kBody, fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final hex in {..._palette, _color})
                GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: hexColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == hex
                            ? AppColors.ink
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFB4231F), fontSize: 13)),
          ],
          const SizedBox(height: 22),
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
