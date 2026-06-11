import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/play/screen/play_screen.dart';
import '../play/providers/play_provider.dart';
import '../scenario/providers/scenario_provider.dart';
import '../scenario/screens/edit_scenario_screen.dart';

// Tab Saves: lượt chơi dở + scenario của tôi tạo
class SavesTab extends ConsumerWidget {
  const SavesTab({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa scenario'),
        content: Text(
          'Xóa "$title"? Mọi lượt chơi, bình luận, lượt thích liên quan '
          'cũng sẽ bị xóa và không khôi phục được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(scenarioServiceProvider).deleteScenario(id);
      // Làm mới cả hai danh sách (scenario của tôi + danh sách chung)
      ref.invalidate(myScenariosProvider);
      ref.invalidate(scenarioListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa scenario')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(mySessionsProvider);
    final myScenariosAsync = ref.watch(myScenariosProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Đã lưu')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySessionsProvider);
          ref.invalidate(myScenariosProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Mục 1: Lượt chơi dở ---
            const Text(
              'Đang chơi dở',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            sessionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi: $e'),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Chưa có lượt chơi nào.'),
                  );
                }
                return Column(
                  children: sessions.map((s) {
                    return Card(
                      color: theme.colorScheme.surface,
                      child: ListTile(
                        title: Text(s.storyTitle),
                        subtitle: Text('${s.mcName ?? "?"} · ${s.chapterCount} chương'),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PlayScreen(
                              storyId: s.storyId,
                              storyTitle: s.storyTitle,
                              existingSessionId: s.sessionId,
                            ),
                          ));
                          ref.invalidate(mySessionsProvider);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),
            // --- Mục 2: Scenario của tôi ---
            const Text(
              'Scenario của tôi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            myScenariosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi: $e'),
              data: (scenarios) {
                if (scenarios.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Bạn chưa tạo scenario nào.'),
                  );
                }
                return Column(
                  children: scenarios.map((s) {
                    return Card(
                      color: theme.colorScheme.surface,
                      child: ListTile(
                        title: Text(s.title),
                        subtitle: Text('${s.genres.join(", ")} · ${s.playCount} lượt chơi'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Sửa',
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      EditScenarioScreen(scenario: s),
                                ));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Xóa scenario',
                              onPressed: () =>
                                  _confirmDelete(context, ref, s.id, s.title),
                            ),
                          ],
                        ),
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