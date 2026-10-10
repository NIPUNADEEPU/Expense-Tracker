import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/transaction_analytics.dart';

class ExpenseCategoryChart extends StatelessWidget {
  const ExpenseCategoryChart({
    super.key,
    required this.transactions,
    required this.year,
    required this.month,
  });

  final List<Transaction> transactions;
  final int year;
  final int month;

  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = TransactionAnalytics.spendingByCategory(
      transactions,
      year: year,
      month: month,
    ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = categories.fold<double>(0, (sum, entry) => sum + entry.value);
    final slices = <_ExpenseSlice>[
      ...categories
          .take(4)
          .map(
            (entry) => _ExpenseSlice(
              label: entry.key.displayName,
              amount: entry.value,
              color: entry.key.color,
              icon: entry.key.icon,
            ),
          ),
    ];
    final remaining = categories
        .skip(4)
        .fold<double>(0, (sum, entry) => sum + entry.value);
    if (remaining > 0) {
      slices.add(
        _ExpenseSlice(
          label: 'Other categories',
          amount: remaining,
          color: const Color(0xFF94A3B8),
          icon: Icons.more_horiz_rounded,
        ),
      );
    }

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
              'Spending by category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat('MMMM yyyy').format(DateTime(year, month)),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'No spending recorded for this period.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final chart = _ExpenseDonut(
                    slices: slices,
                    total: total,
                    formatter: _currency,
                  );
                  final legend = Column(
                    children: slices
                        .map(
                          (slice) => _ExpenseLegendRow(
                            slice: slice,
                            total: total,
                            formatter: _currency,
                          ),
                        )
                        .toList(),
                  );

                  if (constraints.maxWidth < 370) {
                    return Column(
                      children: [chart, const SizedBox(height: 14), legend],
                    );
                  }

                  return Row(
                    children: [
                      chart,
                      const SizedBox(width: 14),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseSlice {
  const _ExpenseSlice({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
}

class _ExpenseDonut extends StatelessWidget {
  const _ExpenseDonut({
    required this.slices,
    required this.total,
    required this.formatter,
  });

  final List<_ExpenseSlice> slices;
  final double total;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final colors = slices.map((slice) => slice.color).toList();

    return Semantics(
      label: 'Expense category chart. Total ${formatter.format(total)}.',
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(160),
              painter: _DonutPainter(
                values: slices.map((slice) => slice.amount).toList(),
                colors: colors,
                total: total,
                trackColor: Theme.of(
                  context,
                ).dividerColor.withValues(alpha: 0.25),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(27),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatter.format(total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'total spent',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseLegendRow extends StatelessWidget {
  const _ExpenseLegendRow({
    required this.slice,
    required this.total,
    required this.formatter,
  });

  final _ExpenseSlice slice;
  final double total;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total == 0 ? 0.0 : slice.amount / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: slice.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(slice.icon, size: 16, color: slice.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatter.format(slice.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(share * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.total,
    required this.trackColor,
  });

  final List<double> values;
  final List<Color> colors;
  final double total;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 18.0;
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      final gap = math.min(0.035, sweep * 0.12);
      final paint = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        math.max(0, sweep - gap),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.trackColor != trackColor ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.colors, colors);
}
