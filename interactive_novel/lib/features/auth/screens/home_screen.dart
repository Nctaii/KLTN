import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/play/screen/play_screen.dart';
import '../providers/auth_provider.dart';
import '../models/auth_user.dart';
import '../../theme/theme_screen.dart';
import '../../scenario/screens/scenario_list_screen.dart';
import '../../play/providers/play_provider.dart';

class HomeScreen extends ConsumerWidget {
  final AuthUser user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chính'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Đổi giao diện',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ThemeScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Đăng nhập thành công!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text('ID: ${user.id}'),
            Text('Email: ${user.email}'),
            Text('Username: ${user.username}'),
            Text('Role: ${user.role}'),
            if (user.displayName != null)
              Text('Tên hiển thị: ${user.displayName}'),
              const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ScenarioListScreen(),
                ));
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Khám phá & tạo scenario'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Đang chơi dở',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _MySessionsList(),
          ],
        ),
      ),
    );
  }
}

// Danh sách lượt chơi đang dở, hiển thị trên trang chính
class _MySessionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mySessionsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Lỗi tải lượt chơi: $e'),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Chưa có lượt chơi nào.'),
          );
        }
        return Column(
          children: sessions.map((s) {
            return Card(
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                title: Text(s.storyTitle),
                subtitle: Text(
                  '${s.mcName ?? "?"} · ${s.chapterCount} chương',
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlayScreen(
                      storyId: s.storyId,
                      storyTitle: s.storyTitle,
                      existingSessionId: s.sessionId, // mở lại lượt cũ
                    ),
                  ));
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
