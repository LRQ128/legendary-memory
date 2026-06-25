import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color incomeOrange = Color(0xFFFF9800);
  static const Color expenseRed = Color(0xFFEF5350);
  static const Color bgColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
          primary: primaryGreen,
          secondary: incomeOrange,
        ),
        scaffoldBackgroundColor: bgColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
        ),
      );

  static const Map<String, Color> categoryColors = {
    '餐饮': Color(0xFFFF7043),
    '交通': Color(0xFF42A5F5),
    '购物': Color(0xFFEC407A),
    '娱乐': Color(0xFFAB47BC),
    '居住': Color(0xFF66BB6A),
    '通讯': Color(0xFF26C6DA),
    '医疗': Color(0xFFEF5350),
    '教育': Color(0xFF7E57C2),
    '人情': Color(0xFFFFCA28),
    '服饰': Color(0xFFFF8A65),
    '日用品': Color(0xFF8D6E63),
    '其他': Color(0xFFBDBDBD),
    '工资': Color(0xFFFF9800),
    '奖金': Color(0xFFFF5722),
    '理财': Color(0xFF4CAF50),
    '兼职': Color(0xFF03A9F4),
  };
}
