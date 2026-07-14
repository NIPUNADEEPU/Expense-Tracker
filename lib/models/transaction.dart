import 'category.dart';

enum TransactionType {
  income,
  expense;

  String get displayName => this == TransactionType.income ? 'Income' : 'Expense';
}

class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final ExpenseCategory category;
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  });

  // Convert to JSON (optional, but good for future persistence)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'date': date.toIso8601String(),
    };
  }

  // Parse from JSON (optional)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.byName(json['type'] as String),
      category: ExpenseCategory.values.byName(json['category'] as String),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
