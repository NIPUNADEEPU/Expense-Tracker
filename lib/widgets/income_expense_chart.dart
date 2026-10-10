import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/transaction_analytics.dart';

class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({
    super.key,
    required this.transactions,
    required this.year,
    required this.month,
    this.monthCount = 6,
  }) : assert(monthCount > 0);

  final List<Transaction> transactions;
  final int year;
  final int month;
  final int monthCount;

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periods = List.generate(monthCount, (index) {
      final date = DateTime(year, month - monthCount + index + 1);
      return _MonthlyTotals(
        date: date,
        income: TransactionAnalytics.total(
          transactions,
          type: TransactionType.income,
          year: date.year,
          month: date.month,
        ),
        expenses: TransactionAnalytics.total(
          transactions,
          type: TransactionType.expense,
          year: date.year,
          month: date.month,
        ),
      );
    });
    final maxAmount = periods.fold<double>(
      0,
      (maxValue, period) =>
          math.max(maxValue, math.max(period.income, period.expenses)),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Income vs expenses',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Monthly totals through ${DateFormat('MMMM yyyy').format(DateTime(year, month))}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _MonthlyBars(periods: periods, maxAmount: maxAmount),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _ChartLegend(color: Color(0xFF10B981), label: 'Income'),
                SizedBox(width: 24),
                _ChartLegend(color: Color(0xFFF87171), label: 'Expenses'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyTotals {
  const _MonthlyTotals({
    required this.date,
    required this.income,
    required this.expenses,
  });

  final DateTime date;
  final double income;
  final double expenses;
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.periods, required this.maxAmount});

  final List<_MonthlyTotals> periods;
  final double maxAmount;

  static const _incomeColor = Color(0xFF10B981);
  static const _expenseColor = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 178,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight = constraints.maxHeight;
                final barWidth = (constraints.maxWidth / (periods.length * 3.4))
                    .clamp(5.0, 18.0);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(
                          color: theme.dividerColor.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: periods.map((period) {
                        final incomeHeight = maxAmount == 0
                            ? 0.0
                            : chartHeight * period.income / maxAmount;
                        final expenseHeight = maxAmount == 0
                            ? 0.0
                            : chartHeight * period.expenses / maxAmount;
                        final monthLabel = DateFormat(
                          'MMM',
                        ).format(period.date);

                        return Expanded(
                          child: Tooltip(
                            message:
                                '${DateFormat('MMMM yyyy').format(period.date)}\n'
                                'Income: ${IncomeExpenseChart._currency.format(period.income)}\n'
                                'Expenses: ${IncomeExpenseChart._currency.format(period.expenses)}',
                            child: Semantics(
                              label:
                                  '${DateFormat('MMMM yyyy').format(period.date)}: '
                                  'income ${IncomeExpenseChart._currency.format(period.income)}, '
                                  'expenses ${IncomeExpenseChart._currency.format(period.expenses)}',
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          _Bar(
                                            width: barWidth,
                                            height: incomeHeight,
                                            color: _incomeColor,
                                          ),
                                          const SizedBox(width: 3),
                                          _Bar(
                                            width: barWidth,
                                            height: expenseHeight,
                                            color: _expenseColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    monthLabel,
                                    maxLines: 1,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var line = 1; line <= 3; line++) {
      final y = size.height * line / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
