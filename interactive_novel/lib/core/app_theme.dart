import 'package:flutter/material.dart';

// Danh sách các theme có sẵn trong app
enum AppThemeType { purple, amber, teal }

// Thông tin hiển thị + bảng màu của mỗi theme
class AppThemeOption {
  final AppThemeType type;
  final String label; // tên hiển thị cho người dùng
  final Color background; // nền chính
  final Color surface; // nền thẻ / ô nhập
  final Color surfaceAlt; // nền nút phụ
  final Color accent; // màu nhấn (nút chính)
  final Color accentText; // màu chữ trên nút nhấn
  final Color textPrimary; // chữ chính
  final Color textSecondary; // chữ phụ

  const AppThemeOption({
    required this.type,
    required this.label,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.accentText,
    required this.textPrimary,
    required this.textSecondary,
  });

  // Chuyển bảng màu thành ThemeData để MaterialApp dùng
  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: accent,
        onPrimary: accentText,
        secondary: accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary, height: 1.7),
        bodyMedium: TextStyle(color: textPrimary, height: 1.7),
        titleLarge: TextStyle(color: textPrimary),
      ),
    );
  }
}

// Bảng tra ba theme — màu lấy đúng từ ba palette đã chọn
const Map<AppThemeType, AppThemeOption> appThemes = {
  AppThemeType.purple: AppThemeOption(
    type: AppThemeType.purple,
    label: 'Tím huyền ảo',
    background: Color(0xFF16161F),
    surface: Color(0xFF1E1E2C),
    surfaceAlt: Color(0xFF2C2C3E),
    accent: Color(0xFF6A5CD8),
    accentText: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFCFCCE0),
    textSecondary: Color(0xFFB8B2D8),
  ),
  AppThemeType.amber: AppThemeOption(
    type: AppThemeType.amber,
    label: 'Nâu hổ phách',
    background: Color(0xFF1A1613),
    surface: Color(0xFF241D17),
    surfaceAlt: Color(0xFF332A20),
    accent: Color(0xFFC8941F),
    accentText: Color(0xFF1A1613),
    textPrimary: Color(0xFFE0D6C5),
    textSecondary: Color(0xFFD4B78A),
  ),
  AppThemeType.teal: AppThemeOption(
    type: AppThemeType.teal,
    label: 'Xanh ngọc lam',
    background: Color(0xFF0F1A1C),
    surface: Color(0xFF152528),
    surfaceAlt: Color(0xFF1C2E30),
    accent: Color(0xFF1D9E8A),
    accentText: Color(0xFF0F1A1C),
    textPrimary: Color(0xFFC5DEDB),
    textSecondary: Color(0xFF7FD4C8),
  ),
};