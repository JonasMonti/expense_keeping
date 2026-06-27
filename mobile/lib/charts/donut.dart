/// Donut por categoria com o total ao centro — espelha donut_by_category() (charts.py).
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/format.dart';
import '../ui/theme.dart';

class CategoryDonut extends StatelessWidget {
  final List<CategoryTotal> rows;
  final double total;
  const CategoryDonut({super.key, required this.rows, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 76,
              startDegreeOffset: -90,
              sections: [
                for (final r in rows)
                  PieChartSectionData(
                    value: r.total,
                    color: hexColor(r.color),
                    radius: 26,
                    showTitle: false,
                    borderSide: BorderSide(color: AppColors.surface, width: 2),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total',
                  style: TextStyle(
                      fontFamily: kBody, fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(fmtMoneyCompact(total), style: display(28)),
            ],
          ),
        ],
      ),
    );
  }
}
