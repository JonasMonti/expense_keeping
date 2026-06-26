/// Interpretação de frases de voz em pt-PT para os campos de uma despesa.
///
/// Sem dependências de UI nem de base de dados — recebe o texto ditado e a
/// lista de categorias existentes e devolve os campos que conseguiu extrair.
/// Pensado para frases como:
///   "cria despesa de doze euros e cinquenta em alimentação, descrição almoço"
///   "gastei 12,50 na categoria transportes descrição passe do mês"
///
/// A Siri / o Google Assistant normalmente já transcrevem os números como
/// dígitos ("12,50"); o suporte a números por extenso ("doze euros e cinquenta")
/// é um extra para o caso de virem por palavras.
library;

import '../models/models.dart';

/// Resultado da interpretação. [category] vem sempre preenchida quando há
/// categorias (cai em "Outros" se nada bater certo); [categoryMatched] indica
/// se foi de facto reconhecida na frase ou se é apenas o valor por defeito.
class ParsedExpense {
  final double? amount;
  final Category? category;
  final bool categoryMatched;
  final String description;

  const ParsedExpense({
    this.amount,
    this.category,
    this.categoryMatched = false,
    this.description = '',
  });
}

class ExpenseParser {
  static ParsedExpense parse(String input, List<Category> categories) {
    final text = input.trim();
    final lower = text.toLowerCase();

    final amount = _parseAmount(lower);
    final cat = _matchCategory(lower, categories);
    final description = _extractDescription(text, cat.matchedName);

    return ParsedExpense(
      amount: amount,
      category: cat.category,
      categoryMatched: cat.matched,
      description: description,
    );
  }

  // ------------------------------------------------------------------ //
  // Valor
  // ------------------------------------------------------------------ //
  static double? _parseAmount(String lower) {
    final norm = _stripAccents(lower);

    // a) decimal explícito: "12,50" / "12.5"
    final dec = RegExp(r'(\d+)\s*[.,]\s*(\d{1,2})').firstMatch(norm);
    if (dec != null) {
      return double.parse('${dec.group(1)}.${dec.group(2)}');
    }

    // b) "<inteiro> euros [e <cêntimos>]" em dígitos (e também "<inteiro> euros")
    final ec =
        RegExp(r'(\d+)\s*(?:euros?|eur|€)\s*(?:e\s*(\d{1,2}))?').firstMatch(norm);
    if (ec != null) {
      final e = int.parse(ec.group(1)!);
      final c = ec.group(2) != null ? int.parse(ec.group(2)!) : 0;
      return e + c / 100.0;
    }

    // c) números por extenso ("doze euros e cinquenta", "vinte e cinco")
    final tokens = _tokens(norm);
    final w = _wordAmount(tokens);
    if (w != null) return w;

    // d) inteiro simples em dígitos
    final i = RegExp(r'\d+').firstMatch(norm);
    if (i != null) return double.parse(i.group(0)!);

    return null;
  }

  static double? _wordAmount(List<String> tokens) {
    final euroIdx =
        tokens.indexWhere((t) => t == 'euros' || t == 'euro' || t == 'eur');
    if (euroIdx >= 0) {
      final euros = _wordsToInt(tokens.sublist(0, euroIdx));
      final after = tokens
          .sublist(euroIdx + 1)
          .where((t) =>
              t != 'e' && t != 'com' && t != 'centimos' && t != 'cents')
          .toList();
      final cents = _wordsToInt(after);
      if (euros != null) return euros + (cents ?? 0) / 100.0;
      return null;
    }
    final run = _firstRun(tokens);
    return run?.toDouble();
  }

  /// Soma uma sequência de palavras-número (ignora as desconhecidas).
  static int? _wordsToInt(List<String> words) {
    var total = 0, current = 0;
    var any = false;
    for (final w in words) {
      if (w == 'e') continue;
      final v = _numberWords[w];
      if (v == null) continue;
      any = true;
      if (v == 1000) {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else {
        current += v;
      }
    }
    return any ? total + current : null;
  }

  /// Primeira "corrida" contígua de palavras-número (ligadas por "e").
  static int? _firstRun(List<String> tokens) {
    final start = tokens.indexWhere((t) => _numberWords.containsKey(t));
    if (start < 0) return null;
    final run = <String>[];
    var j = start;
    while (j < tokens.length) {
      final t = tokens[j];
      if (_numberWords.containsKey(t)) {
        run.add(t);
        j++;
      } else if (t == 'e' &&
          j + 1 < tokens.length &&
          _numberWords.containsKey(tokens[j + 1])) {
        run.add('e');
        j++;
      } else {
        break;
      }
    }
    return _wordsToInt(run);
  }

  // ------------------------------------------------------------------ //
  // Categoria
  // ------------------------------------------------------------------ //
  static _CatResult _matchCategory(String lower, List<Category> cats) {
    if (cats.isEmpty) return const _CatResult(null, false, null);
    final norm = _stripAccents(lower);
    // Nomes mais longos primeiro, para preferir o mais específico.
    final sorted = [...cats]
      ..sort((a, b) =>
          _stripAccents(b.name).length - _stripAccents(a.name).length);

    bool hasWord(String haystack, String needle) =>
        RegExp(r'\b' + RegExp.escape(needle) + r'\b').hasMatch(haystack);

    // 1) Ancorado depois da palavra "categoria".
    final kwd = RegExp(r'\bcategoria\b').firstMatch(norm);
    if (kwd != null) {
      final after = norm.substring(kwd.end);
      for (final c in sorted) {
        final cn = _stripAccents(c.name.toLowerCase());
        if (hasWord(after, cn)) return _CatResult(c, true, c.name);
      }
    }
    // 2) Em qualquer parte da frase.
    for (final c in sorted) {
      final cn = _stripAccents(c.name.toLowerCase());
      if (hasWord(norm, cn)) return _CatResult(c, true, c.name);
    }
    // 3) Sem correspondência → "Outros" (ou a primeira categoria).
    final outros = cats.where((c) => _stripAccents(c.name.toLowerCase()) == 'outros');
    final fallback = outros.isNotEmpty ? outros.first : cats.first;
    return _CatResult(fallback, false, null);
  }

  // ------------------------------------------------------------------ //
  // Descrição
  // ------------------------------------------------------------------ //
  static String _extractDescription(String text, String? matchedCatName) {
    // Caminho principal: palavra-chave "descrição" (com "é"/":"/"=" opcional).
    final key = RegExp(
      r'descri[cç][aã]o\s*(?:[:=]|é|eh|e)?\s*',
      caseSensitive: false,
      unicode: true,
    );
    final m = key.firstMatch(text);
    if (m != null) {
      var d = text.substring(m.end);
      // Se vier uma cláusula "categoria ..." a seguir, corta aí.
      final catCut =
          RegExp(r'\bcategoria\b', caseSensitive: false, unicode: true)
              .firstMatch(d);
      if (catCut != null) d = d.substring(0, catCut.start);
      return _clean(d);
    }

    // Sem palavra-chave: o que sobra depois de tirar prefixos, valor e categoria.
    var rest = ' $text ';
    rest = rest.replaceAll(
        RegExp(
            r'\b(criar?|cria|nov[ao]|registar?|regista|adicionar?|adiciona|despesa|gastei|gasto|categoria)\b',
            caseSensitive: false,
            unicode: true),
        ' ');
    rest = rest.replaceAll(RegExp(r'\d+([.,]\d+)?'), ' ');
    rest = rest.replaceAll(
        RegExp(r'\b(euros?|eur|c[êe]ntimos?|cents?)\b',
            caseSensitive: false, unicode: true),
        ' ');
    rest = rest.replaceAll('€', ' ');
    for (final w in _numberWords.keys) {
      rest = rest.replaceAll(
          RegExp(r'\b' + w + r'\b', caseSensitive: false), ' ');
    }
    if (matchedCatName != null) {
      rest = rest.replaceAll(
          RegExp(r'\b' + RegExp.escape(matchedCatName) + r'\b',
              caseSensitive: false, unicode: true),
          ' ');
    }
    // Tira preposições/conjunções no início.
    rest = _clean(rest);
    rest = rest.replaceFirst(
        RegExp(r'^(de|da|do|em|no|na|com|e|para)\b\s*',
            caseSensitive: false, unicode: true),
        '');
    return _clean(rest);
  }

  static String _clean(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '')
      .trim();

  // ------------------------------------------------------------------ //
  // Utilitários
  // ------------------------------------------------------------------ //
  static List<String> _tokens(String norm) => norm
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static String _stripAccents(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(_accents[ch] ?? ch);
    }
    return b.toString();
  }

  static const Map<String, String> _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Chaves já sem acentos (ver [_stripAccents]).
  static const Map<String, int> _numberWords = {
    'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'tres': 3,
    'quatro': 4, 'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9,
    'dez': 10, 'onze': 11, 'doze': 12, 'treze': 13, 'catorze': 14,
    'quatorze': 14, 'quinze': 15, 'dezasseis': 16, 'dezesseis': 16,
    'dezassete': 17, 'dezessete': 17, 'dezoito': 18, 'dezanove': 19,
    'dezenove': 19, 'vinte': 20, 'trinta': 30, 'quarenta': 40,
    'cinquenta': 50, 'sessenta': 60, 'setenta': 70, 'oitenta': 80,
    'noventa': 90, 'cem': 100, 'cento': 100, 'duzentos': 200, 'duzentas': 200,
    'trezentos': 300, 'trezentas': 300, 'quatrocentos': 400, 'quatrocentas': 400,
    'quinhentos': 500, 'quinhentas': 500, 'seiscentos': 600, 'seiscentas': 600,
    'setecentos': 700, 'setecentas': 700, 'oitocentos': 800, 'oitocentas': 800,
    'novecentos': 900, 'novecentas': 900, 'mil': 1000,
  };
}

class _CatResult {
  final Category? category;
  final bool matched;
  final String? matchedName;
  const _CatResult(this.category, this.matched, this.matchedName);
}
