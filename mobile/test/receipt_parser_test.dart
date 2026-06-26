import 'package:flutter_test/flutter_test.dart';
import 'package:despesas/ocr/receipt_parser.dart';

void main() {
  group('valor total', () {
    test('linha "TOTAL A PAGAR" com vírgula', () {
      const txt = '''
SUPERMERCADO XPTO
Pão 1,20
Leite 0,89
TOTAL A PAGAR 2,09
''';
      expect(ReceiptParser.parse(txt).amount, 2.09);
    });

    test('prefere TOTAL a SUBTOTAL', () {
      const txt = '''
SUBTOTAL 10,00
IVA 2,30
TOTAL 12,30
''';
      expect(ReceiptParser.parse(txt).amount, 12.30);
    });

    test('ignora TROCO', () {
      const txt = '''
TOTAL 8,50
NUMERARIO 10,00
TROCO 1,50
''';
      expect(ReceiptParser.parse(txt).amount, 8.50);
    });

    test('valor com EUR na linha', () {
      const txt = 'TOTAL EUR 15,00';
      expect(ReceiptParser.parse(txt).amount, 15.00);
    });

    test('milhares com ponto e decimal com vírgula', () {
      const txt = 'TOTAL A PAGAR 1.234,56';
      expect(ReceiptParser.parse(txt).amount, 1234.56);
    });

    test('valor na linha seguinte ao "TOTAL"', () {
      const txt = '''
TOTAL
9,99
''';
      expect(ReceiptParser.parse(txt).amount, 9.99);
    });

    test('recurso: maior valor com cêntimos quando não há keyword', () {
      const txt = '''
Café 0,70
Bolo 1,50
Sumo 2,30
''';
      expect(ReceiptParser.parse(txt).amount, 2.30);
    });

    test('ignora datas e horas', () {
      const txt = '''
26/06/2024 12:30
TOTAL 4,00
''';
      expect(ReceiptParser.parse(txt).amount, 4.00);
    });

    test('texto vazio devolve null', () {
      expect(ReceiptParser.parse('   ').amount, isNull);
    });
  });

  group('descrição (comerciante)', () {
    test('usa a primeira linha textual', () {
      const txt = '''
Restaurante O Forno
Rua das Flores 12
TOTAL 18,40
''';
      expect(ReceiptParser.parse(txt).description, 'Restaurante O Forno');
    });

    test('converte MAIÚSCULAS para Title Case', () {
      const txt = '''
PINGO DOCE
TOTAL 5,00
''';
      expect(ReceiptParser.parse(txt).description, 'Pingo Doce');
    });

    test('salta linhas dominadas por dígitos', () {
      const txt = '''
123456789
Padaria Central
TOTAL 3,20
''';
      expect(ReceiptParser.parse(txt).description, 'Padaria Central');
    });
  });
}
