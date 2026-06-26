/// Interpretação do texto reconhecido numa fatura/talão (OCR) para os campos
/// de uma despesa: o valor total e uma sugestão de descrição (comerciante).
///
/// Sem dependências de UI nem de base de dados — recebe o texto bruto devolvido
/// pelo reconhecimento de texto e devolve o que conseguiu extrair. As faturas
/// portuguesas costumam ter "TOTAL", "TOTAL A PAGAR", "VALOR A PAGAR", com o
/// valor em euros (ex.: "12,50" ou "12.50 EUR").
library;

/// Resultado da leitura de uma fatura. [amount] é null se nada foi reconhecido.
class ParsedReceipt {
  final double? amount;
  final String description;
  const ParsedReceipt({this.amount, this.description = ''});
}

class ReceiptParser {
  /// Palavras-chave que marcam o total a pagar (sem acentos, minúsculas),
  /// por ordem de prioridade (a primeira que bater ganha).
  static const List<String> _totalKeywords = [
    'total a pagar',
    'valor a pagar',
    'total c/iva',
    'total c iva',
    'total liquido',
    'montante total',
    'total eur',
    'total',
  ];

  /// Palavras que aparecem em linhas com valor mas que NÃO são o total a usar.
  static const List<String> _negativeKeywords = [
    'subtotal',
    'sub-total',
    'sub total',
    'troco',
    'iva',
    'sem iva',
    'desconto',
    'nif',
    'contribuinte',
    'numerario',
    'multibanco',
    'cartao',
    'entregue',
  ];

  static ParsedReceipt parse(String text) {
    final rawLines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (rawLines.isEmpty) return const ParsedReceipt();

    final amount = _findTotal(rawLines);
    final description = _findMerchant(rawLines);
    return ParsedReceipt(amount: amount, description: description);
  }

  // ------------------------------------------------------------------ //
  // Valor total
  // ------------------------------------------------------------------ //
  static double? _findTotal(List<String> lines) {
    // 1) Linha com a palavra-chave de total de maior prioridade + um valor.
    //    Procura também o valor na linha seguinte (layouts em duas linhas).
    for (final kw in _totalKeywords) {
      for (var i = 0; i < lines.length; i++) {
        final norm = _norm(lines[i]);
        if (!norm.contains(kw)) continue;
        if (_hasNegative(norm) && kw == 'total') continue;
        final here = _largestAmount(lines[i]);
        if (here != null) return here;
        if (i + 1 < lines.length) {
          final next = _largestAmount(lines[i + 1]);
          if (next != null) return next;
        }
      }
    }

    // 2) Recurso: o maior valor com 2 casas decimais em todo o talão.
    double? best;
    for (final l in lines) {
      if (_hasNegative(_norm(l))) continue;
      for (final v in _amountsIn(l, requireCents: true)) {
        if (best == null || v > best) best = v;
      }
    }
    if (best != null) return best;

    // 3) Último recurso: qualquer maior valor numérico.
    for (final l in lines) {
      for (final v in _amountsIn(l, requireCents: false)) {
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }

  static bool _hasNegative(String norm) =>
      _negativeKeywords.any((k) => norm.contains(k));

  /// Maior valor encontrado numa linha (preferindo os que têm cêntimos).
  static double? _largestAmount(String line) {
    final withCents = _amountsIn(line, requireCents: true);
    final pool = withCents.isNotEmpty
        ? withCents
        : _amountsIn(line, requireCents: false);
    if (pool.isEmpty) return null;
    return pool.reduce((a, b) => a > b ? a : b);
  }

  /// Todos os valores monetários numa linha.
  ///
  /// Aceita "12,50", "12.50", "1.234,56", "1,234.56" e (se [requireCents] for
  /// false) inteiros como "12". Ignora datas/horas (ex.: "2024-06-26", "12:30").
  static List<double> _amountsIn(String line, {required bool requireCents}) {
    // Remove horas (12:30) e datas (26/06/2024, 2024-06-26) para não as ler
    // como valores.
    var s = line
        .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'\b\d{1,4}[/-]\d{1,2}[/-]\d{1,4}\b'), ' ');

    final pattern = requireCents
        ? RegExp(r'\d{1,3}(?:[.\s]\d{3})*[.,]\d{2}\b|\d+[.,]\d{2}\b')
        : RegExp(r'\d{1,3}(?:[.\s]\d{3})*(?:[.,]\d{1,2})?\b|\d+(?:[.,]\d{1,2})?\b');

    final out = <double>[];
    for (final m in pattern.allMatches(s)) {
      final v = _toDouble(m.group(0)!);
      if (v != null) out.add(v);
    }
    return out;
  }

  /// Converte "1.234,56" / "1,234.56" / "12,50" / "12.50" em double.
  static double? _toDouble(String raw) {
    var t = raw.replaceAll(' ', '');
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      // O separador decimal é o que aparece mais à direita; o outro são milhares.
      if (lastComma > lastDot) {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      // Só vírgula → decimal pt-PT.
      t = t.replaceAll('.', '').replaceAll(',', '.');
    }
    final v = double.tryParse(t);
    if (v == null) return null;
    // Ignora valores absurdos (provável ruído de OCR).
    if (v <= 0 || v > 1000000) return null;
    return v;
  }

  // ------------------------------------------------------------------ //
  // Descrição (comerciante)
  // ------------------------------------------------------------------ //
  /// Tenta o nome do comerciante: primeira linha "textual" no topo do talão.
  static String _findMerchant(List<String> lines) {
    for (final l in lines.take(6)) {
      final letters = l.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      // Pelo menos 3 letras e maioritariamente texto (não um endereço/NIF).
      if (letters.length < 3) continue;
      final norm = _norm(l);
      if (_hasNegative(norm)) continue;
      if (norm.contains('fatura') ||
          norm.contains('factura') ||
          norm.contains('talao') ||
          norm.contains('recibo')) {
        continue;
      }
      // Evita linhas dominadas por dígitos.
      final digits = l.replaceAll(RegExp(r'[^0-9]'), '').length;
      if (digits > letters.length) continue;
      return _tidy(l);
    }
    return '';
  }

  /// Normaliza para comparação: minúsculas + sem acentos.
  static String _norm(String s) {
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(_accents[ch] ?? ch);
    }
    return b.toString();
  }

  /// Limpa o nome do comerciante (Title Case, sem ruído nas pontas).
  static String _tidy(String s) {
    final clean = s
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,.:;*#-]+|[\s,.:;*#-]+$'), '')
        .trim();
    // Se vier tudo em maiúsculas, converte para Title Case (mais legível).
    if (clean == clean.toUpperCase()) {
      return clean
          .split(' ')
          .map((w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }
    return clean;
  }

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
}
