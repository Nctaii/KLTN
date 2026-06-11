import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/shell/main_shell.dart';
import 'core/app_theme.dart';
import 'features/theme/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theo dõi theme đang chọn -> đổi theme là app đổi màu ngay
    final themeType = ref.watch(themeNotifierProvider);
    final themeData = appThemes[themeType]!.toThemeData();

    return MaterialApp(
      title: 'Tiểu Thuyết Tương Tác',
      theme: themeData,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginScreen(),
      data: (user) =>
          user == null ? const LoginScreen() : const MainShell(),
    );
  }
}