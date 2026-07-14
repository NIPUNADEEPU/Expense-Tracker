import 'package:flutter/material.dart';

enum ExpenseCategory {
  salary,
  food,
  transport,
  rent,
  utilities,
  entertainment,
  shopping,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.salary:
        return 'Salary';
      case ExpenseCategory.food:
        return 'Food & Dining';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.rent:
        return 'Rent & Housing';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.salary:
        return Icons.account_balance_wallet_rounded;
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_rounded;
      case ExpenseCategory.rent:
        return Icons.home_rounded;
      case ExpenseCategory.utilities:
        return Icons.bolt_rounded;
      case ExpenseCategory.entertainment:
        return Icons.local_play_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.salary:
        return const Color(0xFF10B981); // Emerald Green
      case ExpenseCategory.food:
        return const Color(0xFFF97316); // Orange
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6); // Blue
      case ExpenseCategory.rent:
        return const Color(0xFF6366F1); // Indigo
      case ExpenseCategory.utilities:
        return const Color(0xFFEAB308); // Yellow / Amber
      case ExpenseCategory.entertainment:
        return const Color(0xFF8B5CF6); // Purple
      case ExpenseCategory.shopping:
        return const Color(0xFFEC4899); // Pink
      case ExpenseCategory.other:
        return const Color(0xFF6B7280); // Slate / Grey
    }
  }
}
