import 'package:flutter/material.dart';

enum ExpenseCategory {
  // Income category
  salary,

  // General expense categories from Pou
  food,
  transport,
  rent,
  utilities,

  // ML expense categories
  travel,
  shopping,
  bills,
  entertainment,
  home,
  personalCare,
  financial,

  // Additional categories retained for compatibility
  uncategorized,
  personal,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.salary:
        return 'Salary';
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.rent:
        return 'Rent';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.travel:
        return 'Travel';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.home:
        return 'Home';
      case ExpenseCategory.personalCare:
        return 'Personal Care';
      case ExpenseCategory.financial:
        return 'Financial';
      case ExpenseCategory.uncategorized:
        return 'Uncategorized';
      case ExpenseCategory.personal:
        return 'Personal';
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
        return Icons.directions_bus_rounded;
      case ExpenseCategory.rent:
        return Icons.house_rounded;
      case ExpenseCategory.utilities:
        return Icons.electrical_services_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.entertainment:
        return Icons.local_play_rounded;
      case ExpenseCategory.home:
        return Icons.home_rounded;
      case ExpenseCategory.personalCare:
        return Icons.spa_rounded;
      case ExpenseCategory.financial:
        return Icons.account_balance_rounded;
      case ExpenseCategory.uncategorized:
        return Icons.help_outline_rounded;
      case ExpenseCategory.personal:
        return Icons.people_alt_outlined;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.salary:
        return const Color(0xFF10B981);
      case ExpenseCategory.food:
        return const Color(0xFFF97316);
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6);
      case ExpenseCategory.rent:
        return const Color(0xFF6366F1);
      case ExpenseCategory.utilities:
        return const Color(0xFFEAB308);
      case ExpenseCategory.travel:
        return const Color(0xFF3B82F6);
      case ExpenseCategory.shopping:
        return const Color(0xFFEC4899);
      case ExpenseCategory.bills:
        return const Color(0xFFEAB308);
      case ExpenseCategory.entertainment:
        return const Color(0xFF8B5CF6);
      case ExpenseCategory.home:
        return const Color(0xFF6366F1);
      case ExpenseCategory.personalCare:
        return const Color(0xFF14B8A6);
      case ExpenseCategory.financial:
        return const Color(0xFF64748B);
      case ExpenseCategory.uncategorized:
        return const Color(0xFF9CA3AF);
      case ExpenseCategory.personal:
        return const Color(0xFF06B6D4);
      case ExpenseCategory.other:
        return const Color(0xFF6B7280);
    }
  }
}