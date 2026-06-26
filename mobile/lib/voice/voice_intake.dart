/// Fluxo partilhado de registo por voz.
///
/// Recebe uma frase já transcrita (vinda da Siri/Google via deep link, ou do
/// botão 🎤 dentro da app), interpreta-a com [ExpenseParser] e:
///   • se tiver valor válido → grava logo a despesa e mostra uma faixa "Anular";
///   • caso contrário → abre a folha de despesa já preenchida para completar.
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();
final ValueNotifier<int> expensesRevision = ValueNotifier<int>(0);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Interpreta [text] e regista a despesa (ou abre o formulário preenchido).
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

  final parsed = ExpenseParser.parse(clean, cats);
  final amount = parsed.amount;
  final category = parsed.category;

  // Sem valor utilizável → abrir a folha já preenchida para o utilizador acabar.
  if (amount == null || amount <= 0 || category == null) {
    final ctx = navigatorKey.currentContext;
    // ctx vem do navigatorKey global; o guard .mounted confirma que continua válido.
    if (ctx == null || !ctx.mounted) return;
    final added = await showAddExpenseSheet(
      ctx,
      repo,
      initialAmount: amount,
      initialCategory: category,
      initialDescription: parsed.description,
    );
    if (added) expensesRevision.value++;
    return;
  }

  // Caminho hands-free: gravar logo + faixa "Anular".
  final value = double.parse(amount.toStringAsFixed(2));
  final id = await repo.addExpense(Expense(
    amount: value,
    categoryId: category.id!,
    spentOn: _today(),
    description: parsed.description,
  ));
  expensesRevision.value++;

  final note = parsed.categoryMatched ? '' : ' · categoria por defeito';
  messenger?.showSnackBar(SnackBar(
    content: Text('✅ ${fmtMoney(value)} · ${category.icon} ${category.name}$note'),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: 'Anular',
      onPressed: () async {
        await repo.deleteExpense(id);
        expensesRevision.value++;
      },
    ),
  ));
}
