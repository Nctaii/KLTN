import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

part 'theme_provider.g.dart';

// Notifier giữ theme đang chọn, đọc/ghi xuống shared_preferences
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  static const _key = 'app_theme';

  @override
  AppThemeType build() {
    // Mặc định tím; giá trị thật được nạp bất đồng bộ trong _load()
    _load();
    return AppThemeType.purple;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      final found = AppThemeType.values.where((t) => t.name == saved);
      if (found.isNotEmpty) state = found.first;
    }
  }

  // Đổi theme và lưu lại lựa chọn
  Future<void> setTheme(AppThemeType type) async {
    state = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, type.name);
  }
}