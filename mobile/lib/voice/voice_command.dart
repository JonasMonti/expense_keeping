/// Interpretação de comandos de voz em pt-PT: além de **criar** despesas,
/// reconhece **apagar** e **editar** a última despesa.
///
/// Sem dependências de UI nem de base de dados — recebe a frase falada e a
/// lista de categorias e devolve a intenção + os campos relevantes. Frases:
///   • criar:  "gastei 12,50 em almoço ontem"
///   • apagar: "apaga a última despesa" / "cancela isso"
///   • editar: "muda o valor da última para 20 euros"
///             "muda a categoria da última para transportes"
///             "edita a última despesa" (sem campo → abrir formulário)
library;

import '../models/models.dart';
import 'expense_parser.dart';

enum VoiceIntent { create, delete, edit }

class VoiceCommand {
  final VoiceIntent intent;

  /// Preenchido quando [intent] é [VoiceIntent.create].
  final ParsedExpense? create;

  /// Campos a alterar quando [intent] é [VoiceIntent.edit] (null = não mexer).
  final double? newAmount;
  final Category? newCategory;
  final DateTime? newDate;
  final String? newDescription;

  const VoiceCommand._({
    required this.intent,
    this.create,
    this.newAmount,
    this.newCategory,
    this.newDate,
    this.newDescription,
  });

  /// Há pelo menos um campo concreto a alterar (caso contrário, na edição,
  /// quem usa abre o formulário para o utilizador escolher).
  bool get hasEditChange =>
      newAmount != null ||
      newCategory != null ||
      newDate != null ||
      newDescription != null;

  static VoiceCommand parse(String input, List<Category> categories,
      {DateTime? now}) {
    final norm = _stripAccents(input.trim().toLowerCase());

    if (_isDelete(norm)) {
      return const VoiceCommand._(intent: VoiceIntent.delete);
    }

    if (_isEdit(norm)) {
      // Reaproveita o parser de despesas para extrair valor/categoria/data.
      final p = ExpenseParser.parse(input, categories, now: now);
      final hasDescKwd = RegExp(r'\bdescri[cç][aã]o\b',
              caseSensitive: false, unicode: true)
          .hasMatch(input);
      return VoiceCommand._(
        intent: VoiceIntent.edit,
        newAmount: p.amount,
        newCategory: p.categoryMatched ? p.category : null,
        newDate: p.date,
        newDescription:
            hasDescKwd && p.description.isNotEmpty ? p.description : null,
      );
    }

    return VoiceCommand._(
      intent: VoiceIntent.create,
      create: ExpenseParser.parse(input, categories, now: now),
    );
  }

  // ------------------------------------------------------------------ //
  // Classificação de intenção (sobre texto já sem acentos)
  // ------------------------------------------------------------------ //
  static final RegExp _deleteVerb = RegExp(
      r'\b(apaga|apagar|apague|cancela|cancelar|cancele|anula|anular|anule|elimina|eliminar|elimine|remove|remover|apagada?)\b');

  static final RegExp _editVerb = RegExp(
      r'\b(edita|editar|edite|altera|alterar|altere|muda|mudar|mude|corrige|corrigir|corrige|atualiza|atualizar|troca|trocar)\b');

  static bool _isDelete(String norm) => _deleteVerb.hasMatch(norm);

  static bool _isEdit(String norm) =>
      !_deleteVerb.hasMatch(norm) && _editVerb.hasMatch(norm);

  static String _stripAccents(String s) {
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }
}
