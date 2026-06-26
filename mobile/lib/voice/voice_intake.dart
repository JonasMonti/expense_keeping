/// Fluxo partilhado de comandos por voz.
///
/// Recebe uma frase já transcrita (vinda da Siri/Google via deep link, ou do
/// botão 🎤 dentro da app), interpreta-a com [VoiceCommand] e despacha:
///   • criar  → grava a despesa (com a data dita, ex. "ontem") e mostra "Anular";
///              sem valor utilizável, abre a folha já preenchida para completar.
///   • apagar → remove a última despesa e mostra "Anular".
///   • editar → aplica os campos reconhecidos à última despesa e mostra "Anular";
///              sem campo claro, abre a folha de edição preenchida.
///
/// As [navigatorKey] e [messengerKey] são partilhadas com o MaterialApp para
/// conseguir abrir UI e mostrar SnackBars a partir de um deep link (quando não
/// há um BuildContext do ecrã à mão). [expensesRevision] é incrementada sempre
/// que os dados mudam, para o dashboard se refrescar.
library;

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../ui/add_expense_sheet.dart';
import '../ui/format.dart';
import 'expense_parser.dart';
import 'voice_command.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();
final ValueNotifier<int> expensesRevision = ValueNotifier<int>(0);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Interpreta [text] e executa o comando (criar / apagar / editar).
Future<void> handleVoiceText(Repository repo, String text) async {
  final clean = text.trim();
  if (clean.isEmpty) return;

  final cats = await repo.listCategories();
  final messenger = messengerKey.currentState;
  if (cats.isEmpty) {
    messenger?.showSnackBar(const SnackBar(
        content: Text('Cria primeiro uma categoria em Gerir categorias.')));
    return;
  }

  final cmd = VoiceCommand.parse(clean, cats);
  switch (cmd.intent) {
    case VoiceIntent.delete:
      await _handleDelete(repo, messenger);
    case VoiceIntent.edit:
      await _handleEdit(repo, cmd, messenger);
    case VoiceIntent.create:
      await _handleCreate(repo, cmd.create!, messenger);
  }
}

// -------------------------------------------------------------------- //
// Criar
// -------------------------------------------------------------------- //
Future<void> _handleCreate(
  Repository repo,
  ParsedExpense parsed,
  ScaffoldMessengerState? messenger,
) async {
  final amount = parsed.amount;
  final category = parsed.category;
  final date = parsed.date ?? _today();

  // Sem valor utilizável → abrir a folha já preenchida para o utilizador acabar.
  if (amount == null || amount <= 0 || category == null) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final added = await showAddExpenseSheet(
      ctx,
      repo,
      initialAmount: amount,
      initialCategory: category,
      initialDescription: parsed.description,
      initialDate: parsed.date,
    );
    if (added) expensesRevision.value++;
    return;
  }

  // Caminho hands-free: gravar logo + faixa "Anular".
  final value = double.parse(amount.toStringAsFixed(2));
  final id = await repo.addExpense(Expense(
    amount: value,
    categoryId: category.id!,
    spentOn: date,
    description: parsed.description,
  ));
  expensesRevision.value++;

  final note = parsed.categoryMatched ? '' : ' · categoria por defeito';
  final when = _dateNote(parsed.date);
  messenger?.showSnackBar(_snack(
    '✅ ${fmtMoney(value)} · ${category.icon} ${category.name}$when$note',
    onUndo: () async {
      await repo.deleteExpense(id);
      expensesRevision.value++;
    },
  ));
}

// -------------------------------------------------------------------- //
// Apagar (última despesa)
// -------------------------------------------------------------------- //
Future<void> _handleDelete(
  Repository repo,
  ScaffoldMessengerState? messenger,
) async {
  final last = await repo.lastExpense();
  if (last == null) {
    messenger?.showSnackBar(
        const SnackBar(content: Text('Não há despesas para apagar.')));
    return;
  }
  final snapshot = last.toExpense();
  await repo.deleteExpense(last.id);
  expensesRevision.value++;

  messenger?.showSnackBar(_snack(
    '🗑️ Apagada ${fmtMoney(last.amount)} · ${last.icon} ${last.category}',
    onUndo: () async {
      await repo.addExpense(snapshot);
      expensesRevision.value++;
    },
  ));
}

// -------------------------------------------------------------------- //
// Editar (última despesa)
// -------------------------------------------------------------------- //
Future<void> _handleEdit(
  Repository repo,
  VoiceCommand cmd,
  ScaffoldMessengerState? messenger,
) async {
  final last = await repo.lastExpense();
  if (last == null) {
    messenger?.showSnackBar(
        const SnackBar(content: Text('Não há despesas para editar.')));
    return;
  }

  // Sem campo reconhecido → abrir o formulário de edição preenchido.
  if (!cmd.hasEditChange) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final changed = await showAddExpenseSheet(ctx, repo, editing: last);
    if (changed) expensesRevision.value++;
    return;
  }

  final before = last.toExpense();
  final updated = Expense(
    id: last.id,
    amount: cmd.newAmount != null
        ? double.parse(cmd.newAmount!.toStringAsFixed(2))
        : last.amount,
    categoryId: cmd.newCategory?.id ?? last.categoryId,
    spentOn: cmd.newDate ?? last.spentOn,
    description: cmd.newDescription ?? last.description,
  );
  await repo.updateExpense(updated);
  expensesRevision.value++;

  messenger?.showSnackBar(_snack(
    '✏️ Atualizada · ${fmtMoney(updated.amount)}${_dateNote(cmd.newDate)}',
    onUndo: () async {
      await repo.updateExpense(before);
      expensesRevision.value++;
    },
  ));
}

// -------------------------------------------------------------------- //
// Auxiliares
// -------------------------------------------------------------------- //
/// SnackBar consistente (6s) com ação "Anular".
SnackBar _snack(String text, {required Future<void> Function() onUndo}) {
  return SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(label: 'Anular', onPressed: () => onUndo()),
  );
}

/// " · ontem" quando uma data foi dita (não mostra nada para hoje/ausente).
String _dateNote(DateTime? date) {
  if (date == null) return '';
  final t = _today();
  if (date.year == t.year && date.month == t.month && date.day == t.day) {
    return '';
  }
  return ' · ${fmtDate(date)}';
}
