import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:despesas/data/database.dart';
import 'package:despesas/data/repository.dart';
import 'package:despesas/models/models.dart';

void main() {
  late Database db;
  late Repository repo;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: AppDatabase.createSchema,
      ),
    );
    repo = Repository(() async => db);
  });

  tearDown(() => db.close());

  test('semeia os 4 cartões por defeito', () async {
    final cards = await repo.listCards();
    expect(cards.length, 4);
    expect(
      cards.map((c) => c.name).toSet(),
      {'Subsídio de alimentação', 'Débito', 'Cartão jovem', 'Dinheiro'},
    );
  });

  test('cardBalances = saldo inicial + receitas − despesas (só até hoje)',
      () async {
    final id = await repo.addCard(const Card(name: 'Teste', openingBalance: 50));
    // Receita e despesa atribuídas ao cartão, ambas no passado.
    await repo.addIncome(Income(
        amount: 100, source: 'Extra', receivedOn: DateTime(2026, 6, 1), cardId: id));
    await repo.addExpense(Expense(
        amount: 30, categoryId: 1, spentOn: DateTime(2026, 6, 10), cardId: id));
    // Movimentos futuros (não devem contar).
    await repo.addIncome(Income(
        amount: 999, source: 'Extra', receivedOn: DateTime(2026, 8, 1), cardId: id));
    await repo.addExpense(Expense(
        amount: 999, categoryId: 1, spentOn: DateTime(2026, 8, 5), cardId: id));

    final balances = await repo.cardBalances(now: DateTime(2026, 6, 28));
    final b = balances.firstWhere((c) => c.id == id);
    expect(b.opening, closeTo(50, 0.001));
    expect(b.incomes, closeTo(100, 0.001));
    expect(b.expenses, closeTo(30, 0.001));
    expect(b.balance, closeTo(120, 0.001)); // 50 + 100 − 30
  });

  test('cardHasMovements reflete despesas/receitas atribuídas', () async {
    final id = await repo.addCard(const Card(name: 'Carteira'));
    expect(await repo.cardHasMovements(id), isFalse);

    await repo.addExpense(Expense(
        amount: 5, categoryId: 1, spentOn: DateTime(2026, 6, 3), cardId: id));
    expect(await repo.cardHasMovements(id), isTrue);

    // Um segundo cartão, só com receita atribuída.
    final id2 = await repo.addCard(const Card(name: 'Só receita'));
    await repo.addIncome(Income(
        amount: 10, source: 'Extra', receivedOn: DateTime(2026, 6, 4), cardId: id2));
    expect(await repo.cardHasMovements(id2), isTrue);
  });

  test('movimentos sem cartão (cardId null) não afetam os saldos', () async {
    final id = await repo.addCard(const Card(name: 'Carteira', openingBalance: 20));
    // Sem cartão — não deve entrar em nenhum saldo de cartão.
    await repo.addExpense(
        Expense(amount: 40, categoryId: 1, spentOn: DateTime(2026, 6, 2)));
    await repo.addIncome(
        Income(amount: 80, source: 'Extra', receivedOn: DateTime(2026, 6, 2)));

    final balances = await repo.cardBalances(now: DateTime(2026, 6, 28));
    final b = balances.firstWhere((c) => c.id == id);
    expect(b.incomes, closeTo(0, 0.001));
    expect(b.expenses, closeTo(0, 0.001));
    expect(b.balance, closeTo(20, 0.001)); // só o saldo inicial

    // Não rebenta e o cartão não tem movimentos.
    expect(await repo.cardHasMovements(id), isFalse);
  });
}
