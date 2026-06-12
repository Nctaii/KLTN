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

  // Màu nhấn phụ (sáng hơn accent) - tạo điểm nhấn gradient/sống động
  Color get accentSoft => Color.lerp(accent, Colors.white, 0.18)!;

  // Chuyển bảng màu thành ThemeData để MaterialApp dùng
  ThemeData toThemeData() {
    final base = ColorScheme.dark(
      surface: surface,
      primary: accent,
      onPrimary: accentText,
      secondary: accentSoft,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: base,
      // Màu gợn sóng khi chạm (ripple) dịu hơn
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.06),

      // AppBar: phẳng, hòa với nền, tiêu đề đậm
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),

      // Ô nhập: nền surface, bo góc lớn, viền nhấn khi focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
      ),

      // Nút chính: cao, bo tròn nhiều, chữ đậm, không đổ bóng thô
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentText,
          minimumSize: const Size(0, 50),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // Nút viền: dùng cho lựa chọn hướng đi
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: accent.withValues(alpha: 0.45), width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // Nút chữ: màu nhấn
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentSoft),
      ),

      // Thẻ: bo góc lớn, đổ bóng rất nhẹ, viền mảnh
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaceAlt.withValues(alpha: 0.6), width: 1),
        ),
      ),

      // Chip (chọn thể loại, tính cách): bo tròn, nổi bật khi chọn
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        side: BorderSide(color: surfaceAlt, width: 1),
        labelStyle: TextStyle(color: textPrimary, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: accentText, fontSize: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Thanh điều hướng dưới: nền surface, nhãn gọn
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.22),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accent : textSecondary);
        }),
      ),

      // Dialog: bo góc lớn
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // SnackBar: nổi, bo góc
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceAlt,
        contentTextStyle: TextStyle(color: textPrimary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: surfaceAlt.withValues(alpha: 0.6),
        thickness: 1,
      ),

      // Kiểu chữ: phân cấp rõ ràng hơn, dòng đọc truyện thoáng
      textTheme: TextTheme(
        headlineSmall: TextStyle(
            color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        titleLarge: TextStyle(
            color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textPrimary, height: 1.7),
        bodyMedium: TextStyle(color: textPrimary, height: 1.6),
        bodySmall: TextStyle(color: textSecondary, height: 1.4),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Bảng tra ba theme — màu lấy đúng từ ba palette đã chọn
const Map<AppThemeType, AppThemeOption> appThemes = {
  AppThemeType.purple: AppThemeOption(
    type: AppThemeType.purple,
    label: 'Tím huyền ảo',
    background: Color(0xFF14141C),
    surface: Color(0xFF1E1E2C),
    surfaceAlt: Color(0xFF2C2C3E),
    accent: Color(0xFF7C6FF0),
    accentText: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFE6E3F5),
    textSecondary: Color(0xFFA39DC4),
  ),
  AppThemeType.amber: AppThemeOption(
    type: AppThemeType.amber,
    label: 'Nâu hổ phách',
    background: Color(0xFF18130E),
    surface: Color(0xFF241D17),
    surfaceAlt: Color(0xFF332A20),
    accent: Color(0xFFE0A82E),
    accentText: Color(0xFF18130E),
    textPrimary: Color(0xFFEDE3D2),
    textSecondary: Color(0xFFC2A878),
  ),
  AppThemeType.teal: AppThemeOption(
    type: AppThemeType.teal,
    label: 'Xanh ngọc lam',
    background: Color(0xFF0D1819),
    surface: Color(0xFF152528),
    surfaceAlt: Color(0xFF1C2E30),
    accent: Color(0xFF24B79F),
    accentText: Color(0xFF0D1819),
    textPrimary: Color(0xFFD3E8E4),
    textSecondary: Color(0xFF7BC3B7),
  ),
};