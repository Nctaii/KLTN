import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/play/screen/play_screen.dart';
import '../providers/scenario_provider.dart';
import 'create_scenario_screen.dart';

class ScenarioListScreen extends ConsumerWidget {
  const ScenarioListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(scenarioListProvider);

    void _startPlay(BuildContext context, String storyId, String title) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập vai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đặt tên cho nhân vật của bạn trong "$title".'),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên nhân vật (để trống dùng mặc định)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayScreen(
                  storyId: storyId,
                  storyTitle: title,
                  mcName: name.isEmpty ? null : name,
                ),
              ));
            },
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

    return Scaffold(
      appBar: AppBar(title: const Text('Khám phá scenario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CreateScenarioScreen(),
          ));
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo mới'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(scenarioListProvider.notifier).refresh(),
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 100),
              Center(child: Text('Lỗi tải danh sách: $e')),
            ],
          ),
          data: (scenarios) {
            if (scenarios.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('Chưa có scenario nào. Hãy tạo mới!')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: scenarios.length,
              itemBuilder: (context, i) {
                final s = scenarios[i];
                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(s.title),
                    subtitle: Text(
                      '${s.genres.join(", ")} · ${s.playCount} lượt chơi',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _startPlay(context, s.id, s.title);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}