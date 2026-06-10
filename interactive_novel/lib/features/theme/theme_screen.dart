import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import 'theme_provider.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn giao diện')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: appThemes.values.map((opt) {
          final selected = opt.type == current;
          return GestureDetector(
            onTap: () =>
                ref.read(themeNotifierProvider.notifier).setTheme(opt.type),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: opt.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? opt.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          color: opt.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, color: opt.accent, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Đoạn truyện mẫu để xem trước cảm giác
                  Text(
                    'Ngươi bước qua cánh cổng đá phủ rêu. Linh khí dày đặc đến mức gần như chạm được...',
                    style: TextStyle(
                      color: opt.textPrimary,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dải màu mẫu
                  Row(
                    children: [
                      _swatch(opt.background),
                      _swatch(opt.surfaceAlt),
                      _swatch(opt.accent),
                      _swatch(opt.textSecondary),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: opt.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Nút mẫu',
                          style: TextStyle(
                            color: opt.accentText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _swatch(Color c) => Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
      );
}