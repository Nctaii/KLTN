import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/auth/providers/auth_provider.dart';
import 'package:interactive_novel/features/scenario/providers/scenario_provider.dart';
import 'package:interactive_novel/features/scenario/screens/scenario_list_screen.dart';

// Tab Home: lời chào + vài scenario nổi bật
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final listAsync = ref.watch(scenarioListProvider);
    final theme = Theme.of(context);

    final name = authState.valueOrNull?.username ?? 'bạn';

    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(scenarioListProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Xin chào, $name 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Khám phá thế giới truyện tương tác',
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scenario nổi bật',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            listAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Lỗi tải: $e'),
              data: (scenarios) {
                if (scenarios.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có scenario nào. Hãy tạo ở tab Khám phá!'),
                  );
                }
                // Lấy tối đa 5 cái đầu làm "nổi bật"
                final featured = scenarios.take(5).toList();
                return Column(
                  children: featured.map((s) {
                    return Card(
                      color: theme.colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(s.title),
                        subtitle: Text(
                          '${s.genres.join(", ")} · ${s.playCount} lượt chơi',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Chuyển sang xem chi tiết trong Discover
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ScenarioListScreen(),
                          ));
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}