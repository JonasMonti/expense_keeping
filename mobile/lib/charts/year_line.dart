/// Linha com o total gasto em cada mês do ano — espelha year_line() (charts.py).
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../ui/format.dart';
import '../ui/theme.dart';

class YearLineChart extends StatelessWidget {
  final List<MonthTotal> rows; // 12 meses (Jan→Dez)
  final int highlightMonth; // mês selecionado, marcador maior
  const YearLineChart({
    super.key,
    required this.rows,
    required this.highlightMonth,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = rows.fold<double>(0, (m, r) => r.total > m ? r.total : m);
    final spots = [
      for (final r in rows) FlSpot((r.month - 1).toDouble(), r.total),
    ];

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 11,
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.18,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i > 11) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(mesesCurtoPt[i],
                        style: TextStyle(
                            fontFamily: kBody,
                            fontSize: 11,
                            color: AppColors.muted)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              tooltipBorder: BorderSide(color: AppColors.border),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${mesesCurtoPt[s.x.round()]}\n${fmtMoney(s.y)}',
                        display(13),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) {
                  final isSel = spot.x.round() == highlightMonth - 1;
                  return FlDotCirclePainter(
                    radius: isSel ? 6 : 3,
                    color: AppColors.accent,
                    strokeWidth: 2,
                    strokeColor: AppColors.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withAlpha(31), // ~.12
              ),
            ),
          ],
        ),
      ),
    );
  }
}
