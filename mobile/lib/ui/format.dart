/// Formatação de valores e datas em pt-PT — espelha fmt_number() de src/ui.py.
library;

const String kCurrency = '€';

const List<String> mesesPt = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const List<String> mesesCurtoPt = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

/// 1234.5 -> "1 234,50" (espaço fino de milhar, vírgula decimal).
String fmtNumber(double value) {
  final fixed = value.toStringAsFixed(2); // "1234.50"
  final parts = fixed.split('.');
  final intPart = parts[0];
  final dec = parts[1];

  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;

  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' '); // espaço fixo
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf,$dec';
}

/// "1 234,50 €"
String fmtMoney(double value) => '${fmtNumber(value)} $kCurrency';

/// 0 -> "0", caso contrário valor inteiro com separador de milhar (para o centro do donut).
String fmtMoneyCompact(double value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buf $kCurrency';
}

/// "22/06/2026"
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';
