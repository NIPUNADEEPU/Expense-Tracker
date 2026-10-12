import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '\u20B9',
  decimalDigits: 0,
);

class SmsCategoryReviewDialog extends StatelessWidget {
  const SmsCategoryReviewDialog({
    super.key,
    required this.transaction,
    required this.index,
    required this.total,
  });

  final Transaction transaction;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight =
        (media.size.height -
                media.viewInsets.vertical -
                media.viewPadding.vertical -
                48)
            .clamp(0.0, 600.0)
            .toDouble();
    final categoryOptions = ExpenseCategory.values
        .where(
          (category) =>
              category != ExpenseCategory.salary &&
              category != ExpenseCategory.uncategorized,
        )
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a category ($index/$total)',
                style:
                    Theme.of(context).dialogTheme.titleTextStyle ??
                    Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                transaction.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(_inr.format(transaction.amount)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: categoryOptions.length,
                  itemBuilder: (context, optionIndex) {
                    final category = categoryOptions[optionIndex];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(category.icon, color: category.color),
                      title: Text(category.displayName),
                      onTap: () => Navigator.pop(context, category),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Review later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
