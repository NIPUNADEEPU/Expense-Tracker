import 'category.dart';

enum TransactionType {
  income,
  expense;

  String get displayName =>
      this == TransactionType.income ? 'Income' : 'Expense';
}

enum TransactionCurrency {
  inr,
  usd,
  eur,
  gbp,
  cad,
  aud,
  jpy,
  unknown;

  String get code {
    switch (this) {
      case TransactionCurrency.inr:
        return 'INR';
      case TransactionCurrency.usd:
        return 'USD';
      case TransactionCurrency.eur:
        return 'EUR';
      case TransactionCurrency.gbp:
        return 'GBP';
      case TransactionCurrency.cad:
        return 'CAD';
      case TransactionCurrency.aud:
        return 'AUD';
      case TransactionCurrency.jpy:
        return 'JPY';
      case TransactionCurrency.unknown:
        return 'UNKNOWN';
    }
  }

  String get symbol {
    switch (this) {
      case TransactionCurrency.inr:
        return '₹';
      case TransactionCurrency.usd:
        return '\$';
      case TransactionCurrency.eur:
        return '€';
      case TransactionCurrency.gbp:
        return '£';
      case TransactionCurrency.cad:
        return 'CA\$';
      case TransactionCurrency.aud:
        return 'A\$';
      case TransactionCurrency.jpy:
        return '¥';
      case TransactionCurrency.unknown:
        return '';
    }
  }

  String get displayName {
    switch (this) {
      case TransactionCurrency.inr:
        return 'INR — Indian Rupee';
      case TransactionCurrency.usd:
        return 'USD — US Dollar';
      case TransactionCurrency.eur:
        return 'EUR — Euro';
      case TransactionCurrency.gbp:
        return 'GBP — British Pound';
      case TransactionCurrency.cad:
        return 'CAD — Canadian Dollar';
      case TransactionCurrency.aud:
        return 'AUD — Australian Dollar';
      case TransactionCurrency.jpy:
        return 'JPY — Japanese Yen';
      case TransactionCurrency.unknown:
        return 'Unknown — Select currency';
    }
  }

  static TransactionCurrency fromStoredValue(dynamic value) {
    if (value is! String) {
      return TransactionCurrency.unknown;
    }

    for (final currency in TransactionCurrency.values) {
      if (currency.name == value || currency.code == value) {
        return currency;
      }
    }

    return TransactionCurrency.unknown;
  }
}

class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final ExpenseCategory category;
  final DateTime date;
  final TransactionCurrency currency;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.currency = TransactionCurrency.unknown,
  });

  // Convert to JSON for Firestore persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category.name,
      'date': date.toIso8601String(),
      'currency': currency.code,
    };
  }

  // Convert stored JSON back into a Transaction.
  // Older records without currency remain compatible.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.byName(json['type'] as String),
      category: _categoryFromStoredName(json['category'] as String),
      date: DateTime.parse(json['date'] as String),
      currency: TransactionCurrency.fromStoredValue(json['currency']),
    );
  }

  // Supports current categories and legacy stored category names.
  static ExpenseCategory _categoryFromStoredName(String value) {
    switch (value) {
      case 'salary':
        return ExpenseCategory.salary;
      case 'food':
        return ExpenseCategory.food;
      case 'travel':
        return ExpenseCategory.travel;
      case 'shopping':
        return ExpenseCategory.shopping;
      case 'bills':
        return ExpenseCategory.bills;
      case 'entertainment':
        return ExpenseCategory.entertainment;
      case 'home':
        return ExpenseCategory.home;
      case 'personalCare':
        return ExpenseCategory.personalCare;
      case 'financial':
        return ExpenseCategory.financial;
      case 'transport':
        return ExpenseCategory.transport;
      case 'rent':
        return ExpenseCategory.rent;
      case 'utilities':
        return ExpenseCategory.utilities;
      case 'personal':
        return ExpenseCategory.personal;
      case 'uncategorized':
        return ExpenseCategory.uncategorized;
      case 'other':
      default:
        return ExpenseCategory.other;
    }
  }
}