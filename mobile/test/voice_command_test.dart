import 'package:flutter_test/flutter_test.dart';
import 'package:despesas/models/models.dart';
import 'package:despesas/voice/expense_parser.dart';
import 'package:despesas/voice/voice_command.dart';

void main() {
  const cats = [
    Category(id: 1, name: 'Alimentação', icon: '🍽️'),
    Category(id: 2, name: 'Transportes', icon: '🚌'),
    Category(id: 3, name: 'Casa', icon: '🏠'),
    Category(id: 5, name: 'Lazer', icon: '🎬'),
    Category(id: 8, name: 'Outros', icon: '💸'),
  ];

  // 2026-06-26 é uma sexta-feira.
  final base = DateTime(2026, 6, 26);

  group('datas', () {
    DateTime? d(String s) => ExpenseParser.parse(s, cats, now: base).date;

    test('hoje', () => expect(d('gastei 5 euros hoje'), DateTime(2026, 6, 26)));
    test('ontem', () => expect(d('gastei 5 euros ontem'), DateTime(2026, 6, 25)));
    test('anteontem',
        () => expect(d('gastei 5 euros anteontem'), DateTime(2026, 6, 24)));
    test('há 3 dias',
        () => expect(d('despesa de 5 euros há 3 dias'), DateTime(2026, 6, 23)));
    test('há uma semana',
        () => expect(d('paguei há uma semana'), DateTime(2026, 6, 19)));
    test('dia 5', () => expect(d('foi no dia 5'), DateTime(2026, 6, 5)));
    test('dia 5 de janeiro',
        () => expect(d('foi dia 5 de janeiro'), DateTime(2026, 1, 5)));
    test('dia no futuro recua um mês',
        () => expect(d('foi dia 30'), DateTime(2026, 5, 30)));
    test('sem data → null', () => expect(d('gastei 5 euros em lazer'), isNull));

    test('dia da semana → ocorrência mais recente (<= hoje)', () {
      final r = d('paguei na quarta');
      expect(r!.weekday, DateTime.wednesday);
      expect(r.isAfter(base), isFalse);
      expect(base.difference(r).inDays, lessThanOrEqualTo(6));
    });

    test('o número da data não é lido como valor', () {
      final p = ExpenseParser.parse('gastei 12,50 em almoço há 3 dias', cats,
          now: base);
      expect(p.amount, 12.50);
      expect(p.date, DateTime(2026, 6, 23));
    });

    test('a descrição não inclui a expressão de data', () {
      final p = ExpenseParser.parse(
          'gastei 10 euros descrição almoço ontem', cats,
          now: base);
      expect(p.description, 'almoço');
    });
  });

  group('intenção', () {
    test('criar é o padrão', () {
      expect(VoiceCommand.parse('gastei 5 euros em lazer', cats).intent,
          VoiceIntent.create);
    });
    test('apagar: "apaga a última despesa"', () {
      expect(VoiceCommand.parse('apaga a última despesa', cats).intent,
          VoiceIntent.delete);
    });
    test('apagar: "cancela isso"', () {
      expect(VoiceCommand.parse('cancela isso', cats).intent,
          VoiceIntent.delete);
    });

    test('editar valor', () {
      final c = VoiceCommand.parse('muda o valor da última para 20 euros', cats);
      expect(c.intent, VoiceIntent.edit);
      expect(c.newAmount, 20);
      expect(c.newCategory, isNull);
      expect(c.hasEditChange, isTrue);
    });
    test('editar categoria', () {
      final c =
          VoiceCommand.parse('muda a categoria da última para transportes', cats);
      expect(c.intent, VoiceIntent.edit);
      expect(c.newCategory?.name, 'Transportes');
      expect(c.newAmount, isNull);
    });
    test('editar data', () {
      final c =
          VoiceCommand.parse('muda a data da última para ontem', cats, now: base);
      expect(c.intent, VoiceIntent.edit);
      expect(c.newDate, DateTime(2026, 6, 25));
    });
    test('editar sem campo claro → abrir formulário', () {
      final c = VoiceCommand.parse('edita a última despesa', cats);
      expect(c.intent, VoiceIntent.edit);
      expect(c.hasEditChange, isFalse);
    });
  });

  group('recorrentes por voz', () {
    test('"renda de 500 em casa todo o dia 1"', () {
      final c = VoiceCommand.parse(
          'renda de 500 euros em casa todo o dia 1', cats,
          now: base);
      expect(c.intent, VoiceIntent.createRecurring);
      expect(c.create?.amount, 500);
      expect(c.create?.category?.name, 'Casa');
      expect(c.recurringDay, 1);
    });

    test('"cria recorrente 30 euros transportes" (sem dia → null)', () {
      final c = VoiceCommand.parse(
          'cria recorrente 30 euros transportes', cats,
          now: base);
      expect(c.intent, VoiceIntent.createRecurring);
      expect(c.create?.amount, 30);
      expect(c.create?.category?.name, 'Transportes');
      expect(c.recurringDay, isNull);
    });

    test('"mensalmente" também marca recorrente', () {
      final c = VoiceCommand.parse('15 euros lazer mensalmente', cats);
      expect(c.intent, VoiceIntent.createRecurring);
    });

    test('despesa normal não é confundida com recorrente', () {
      expect(VoiceCommand.parse('gastei 5 euros em lazer', cats).intent,
          VoiceIntent.create);
    });
  });
}
