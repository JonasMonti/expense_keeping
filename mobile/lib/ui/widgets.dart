/// Componentes de apresentação — espelham hero/kpi/category_list de src/ui.py.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'format.dart';
import 'theme.dart';

/// Cartão genérico com a estética da app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20),
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: cardDecoration,
        padding: padding,
        child: child,
      );
}

/// Etiqueta em maiúsculas (eyebrow).
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: kBody,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
          color: AppColors.faint,
        ),
      );
}

/// Valor monetário grande (Space Grotesk, € esbatido).
class MoneyBig extends StatelessWidget {
  final double value;
  const MoneyBig(this.value, {super.key});
  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          text: fmtNumber(value),
          style: display(46),
          children: [
            TextSpan(
              text: ' $kCurrency',
              style: display(25, color: AppColors.muted, weight: FontWeight.w500),
            ),
          ],
        ),
      );
}

/// Hero: etiqueta + total grande + linha de sub-estatísticas.
/// (Nome HeroCard para não colidir com o widget Hero do Flutter.)
class HeroCard extends StatelessWidget {
  final String label;
  final double total;
  final List<Widget> stats;
  const HeroCard({
    super.key,
    required this.label,
    required this.total,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label),
            const SizedBox(height: 8),
            MoneyBig(total),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: stats,
              ),
            ],
          ],
        ),
      );
}

/// Texto de sub-estatística com partes a negrito (cor ink).
Widget statText(String prefix, {String? bold, String? suffix}) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(fontFamily: kBody, fontSize: 13.5, color: AppColors.muted),
      children: [
        TextSpan(text: prefix),
        if (bold != null)
          TextSpan(
            text: bold,
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w600),
          ),
        if (suffix != null) TextSpan(text: suffix),
      ],
    ),
  );
}

/// Título de secção (Space Grotesk).
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(text, style: display(17, weight: FontWeight.w600)),
      );
}

/// Lista "onde gastaste mais": nome + %, valor, barra de progresso colorida.
class CategoryBars extends StatelessWidget {
  final List<CategoryTotal> rows;
  final double total;
  const CategoryBars({super.key, required this.rows, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in rows) _row(r),
      ],
    );
  }

  Widget _row(CategoryTotal r) {
    final pct = total > 0 ? r.total / total * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontFamily: kBody,
                        fontSize: 14.5,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(text: '${r.icon} ${r.category}'),
                      TextSpan(
                        text: '  ${pct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.faint,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
              Text(fmtNumber(r.total), style: display(15)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.bg,
              valueColor: AlwaysStoppedAnimation(hexColor(r.color)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de emoji com fundo tingido pela cor da categoria (≈ color + "22").
class CategoryChip extends StatelessWidget {
  final String icon;
  final String color;
  final double size;
  const CategoryChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hexColor(color, alpha: 0x22),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(icon, style: TextStyle(fontSize: size * 0.5)),
      );
}

/// Linha de despesa no histórico (swipe-to-delete tratado no ecrã).
class ExpenseRow extends StatelessWidget {
  final ExpenseView e;
  const ExpenseRow(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              fmtDate(e.spentOn),
              style: const TextStyle(
                  fontFamily: kBody,
                  fontSize: 12.5,
                  color: AppColors.faint,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          CategoryChip(icon: e.icon, color: e.color, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontFamily: kBody, fontSize: 14.5),
                children: [
                  TextSpan(
                    text: e.category,
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w500),
                  ),
                  if (e.description.isNotEmpty)
                    TextSpan(
                      text: ' — ${e.description}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(fmtMoney(e.amount), style: display(15)),
        ],
      ),
    );
  }
}
