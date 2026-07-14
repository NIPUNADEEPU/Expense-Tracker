import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'providers/expense_provider.dart';
import 'screens/dashboard_screen.dart';

void main() {
  // Ensure status bar styling is transparent & matches theme
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0F0F12),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the ExpenseProvider state notifier at the root of the app
    return ExpenseScope(
      notifier: ExpenseProvider(),
      child: MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark, // Default to premium dark mode
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F12), // Premium deep pitch charcoal
          cardColor: const Color(0xFF191920), // Slightly lighter charcoal for cards
          dividerColor: const Color(0xFF2E2E38),
          
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8B5CF6), // Indigo / Violet primary
            onPrimary: Colors.white,
            secondary: Color(0xFF10B981), // Emerald accent
            onSecondary: Colors.white,
            surface: Color(0xFF191920),
            onSurface: Color(0xFFF3F4F6),
            error: Color(0xFFEF4444), // Rose red for expense/errors
            onError: Colors.white,
          ),
          
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F0F12),
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF3F4F6),
            ),
            iconTheme: IconThemeData(color: Color(0xFFF3F4F6)),
          ),
          
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF8B5CF6);
                }
                return const Color(0xFF191920);
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.white70;
              }),
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFF191920),
            disabledColor: Colors.grey,
            selectedColor: const Color(0xFF8B5CF6),
            secondarySelectedColor: const Color(0xFF8B5CF6),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
            secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            brightness: Brightness.dark,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.transparent),
            ),
          ),
          
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold, color: Color(0xFFF3F4F6)),
            titleMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, color: Color(0xFFF3F4F6)),
            bodyLarge: TextStyle(fontFamily: 'Roboto', color: Color(0xFFE5E7EB)),
            bodyMedium: TextStyle(fontFamily: 'Roboto', color: Color(0xFF9CA3AF)),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
