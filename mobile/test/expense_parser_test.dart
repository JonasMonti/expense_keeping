import 'package:flutter_test/flutter_test.dart';
import 'package:despesas/models/models.dart';
import 'package:despesas/voice/expense_parser.dart';

void main() {
  // Categorias por defeito (iguais às de database.dart).
  const cats = [
    Category(id: 1, name: 'Alimentação', icon: '🍽️'),
    Category(id: 2, name: 'Transportes', icon: '🚌'),
    Category(id: 3, name: 'Casa', icon: '🏠'),
    Category(id: 4, name: 'Saúde', icon: '➕'),
    Category(id: 5, name: 'Lazer', icon: '🎬'),
    Category(id: 6, name: 'Compras', icon: '🛍️'),
    Category(id: 7, name: 'Educação', icon: '📚'),
    Category(id: 8, name: 'Outros', icon: '💸'),
  ];

  Category cat(String name) => cats.firstWhere((c) => c.name == name);

  group('valor', () {
    test('decimal com vírgula', () {
      expect(ExpenseParser.parse('gastei 12,50 em transportes', cats).amount,
          12.50);
    });
    test('decimal com ponto', () {
      expect(ExpenseParser.parse('12.5 euros casa', cats).amount, 12.5);
    });
    test('inteiro simples', () {
      expect(ExpenseParser.parse('despesa 30 lazer', cats).amount, 30);
    });
    test('euros e cêntimos em dígitos', () {
      expect(ExpenseParser.parse('100 euros e 5 em casa', cats).amount, 100.05);
    });
    test('número por extenso: "doze euros e cinquenta"', () {
      expect(ExpenseParser.parse('doze euros e cinquenta', cats).amount, 12.50);
    });
    test('número por extenso composto: "vinte e cinco euros"', () {
      expect(ExpenseParser.parse('vinte e cinco euros em saúde', cats).amount,
          25.0);
    });
    test('número por extenso simples: "cinco euros"', () {
      expect(ExpenseParser.parse('cinco euros', cats).amount, 5.0);
    });
    test('sem valor → null', () {
      expect(ExpenseParser.parse('despesa em alimentação', cats).amount, isNull);
    });
  });

  group('categoria', () {
    test('com palavra-chave "categoria"', () {
      final p = ExpenseParser.parse('10 euros categoria compras', cats);
      expect(p.category, cat('Compras'));
      expect(p.categoryMatched, isTrue);
    });
    test('reconhecida sem palavra-chave', () {
      final p = ExpenseParser.parse('25 euros em saúde', cats);
      expect(p.category, cat('Saúde'));
      expect(p.categoryMatched, isTrue);
    });
    test('acentos/maiúsculas indiferentes', () {
      final p = ExpenseParser.parse('5 euros EDUCACAO', cats);
      expect(p.category, cat('Educação'));
    });
    test('inexistente → cai em Outros (não reconhecida)', () {
      final p = ExpenseParser.parse('5 euros em viagens', cats);
      expect(p.category, cat('Outros'));
      expect(p.categoryMatched, isFalse);
    });
  });

  group('descrição', () {
    test('palavra-chave "descrição"', () {
      final p = ExpenseParser.parse(
          'doze euros e cinquenta em alimentação, descrição almoço com colegas',
          cats);
      expect(p.amount, 12.50);
      expect(p.category, cat('Alimentação'));
      expect(p.description, 'almoço com colegas');
    });
    test('palavra-chave "descrição é"', () {
      final p = ExpenseParser.parse(
          '10 euros categoria compras descrição é ténis novos', cats);
      expect(p.description, 'ténis novos');
    });
    test('descrição antes da categoria é cortada', () {
      final p = ExpenseParser.parse(
          '10 euros descrição jantar fora categoria alimentação', cats);
      expect(p.description, 'jantar fora');
      expect(p.category, cat('Alimentação'));
    });
    test('sem palavra-chave → vazia quando só há valor+categoria', () {
      final p = ExpenseParser.parse('25 euros em saúde', cats);
      expect(p.description, isEmpty);
    });
    test('frase completa típica', () {
      final p = ExpenseParser.parse(
          'cria despesa de 15,90 na categoria transportes descrição passe mensal',
          cats);
      expect(p.amount, 15.90);
      expect(p.category, cat('Transportes'));
      expect(p.description, 'passe mensal');
    });
  });
}
