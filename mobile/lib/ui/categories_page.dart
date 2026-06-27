/// Gerir categorias — espelha dialog_categorias() (app.py).
library;

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Paleta de cores sugerida (inclui as cores das categorias por defeito).
const List<String> _palette = [
  '#0F7B66', '#FF6B6B', '#4D96FF', '#6BCB77',
  '#FF9F45', '#9B5DE5', '#F15BB5', '#00BBF9',
  '#F4A259', '#2A9D8F', '#E76F51', '#888888',
];

class CategoriesPage extends StatefulWidget {
  final Repository repo;
  const CategoriesPage({super.key, required this.repo});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Category> _cats = [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await widget.repo.listCategories();
    if (mounted) setState(() => _cats = cats);
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
          title: Text('Categorias', style: display(19)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text('As cores são usadas nos gráficos.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
            for (final c in _cats) _categoryTile(c),
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
              label: const Text('Nova categoria',
                  style: TextStyle(
                      fontFamily: kBody, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(Category c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CategoryChip(icon: c.icon, color: c.color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.name,
                  style: const TextStyle(
                      fontFamily: kBody,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.muted),
              onPressed: () => _showEdit(c),
              tooltip: 'Editar',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: AppColors.muted),
              onPressed: () => _confirmDelete(c),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Category c) async {
    if (await widget.repo.categoryHasExpenses(c.id!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '«${c.name}» tem despesas associadas e não pode ser eliminada.')));
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar categoria'),
        content: Text('Eliminar «${c.name}»?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.deleteCategory(c.id!);
      _changed = true;
      _load();
    }
  }

  Future<void> _showAdd() => _showEditor(null);
  Future<void> _showEdit(Category c) => _showEditor(c);

  Future<void> _showEditor(Category? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CategoryEditor(repo: widget.repo, existing: existing),
    );
    if (saved == true) {
      _changed = true;
      _load();
    }
  }
}

class _CategoryEditor extends StatefulWidget {
  final Repository repo;
  final Category? existing;
  const _CategoryEditor({required this.repo, this.existing});

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _iconCtrl =
      TextEditingController(text: widget.existing?.icon ?? '💸');
  late String _color = widget.existing?.color ?? '#0F7B66';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final icon = _iconCtrl.text.trim().isEmpty ? '💸' : _iconCtrl.text.trim();
    if (widget.existing == null) {
      await widget.repo.addCategory(name, color: _color, icon: icon);
    } else {
      await widget.repo.updateCategory(widget.existing!.id!, name, _color, icon);
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
          Text(widget.existing == null ? 'Nova categoria' : 'Editar categoria',
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
