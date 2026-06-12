import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/play/screen/play_screen.dart';
import '../play/providers/play_provider.dart';
import '../scenario/providers/scenario_provider.dart';
import '../scenario/screens/edit_scenario_screen.dart';

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
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(scenarioServiceProvider).deleteScenario(id);
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
          padding: const EdgeInsets.all(20),
          children: [
            _sectionHeader(theme, Icons.history, 'Đang chơi dở'),
            const SizedBox(height: 12),
            sessionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi: $e'),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return _emptyHint(theme, 'Chưa có lượt chơi nào.');
                }
                return Column(
                  children: sessions.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await Navigator.of(context).push(
                                MaterialPageRoute(
                              builder: (_) => PlayScreen(
                                storyId: s.storyId,
                                storyTitle: s.storyTitle,
                                existingSessionId: s.sessionId,
                              ),
                            ));
                            ref.invalidate(mySessionsProvider);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.menu_book,
                                      color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.storyTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '${s.mcName ?? "?"} · ${s.chapterCount} chương',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .textTheme.bodySmall?.color)),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.play_arrow_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 28),
            _sectionHeader(theme, Icons.create, 'Scenario của tôi'),
            const SizedBox(height: 12),
            myScenariosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi: $e'),
              data: (scenarios) {
                if (scenarios.isEmpty) {
                  return _emptyHint(theme, 'Bạn chưa tạo scenario nào.');
                }
                return Column(
                  children: scenarios.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${s.genres.join(", ")} · ${s.playCount} lượt chơi',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme.bodySmall?.color)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Sửa',
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                  builder: (_) =>
                                      EditScenarioScreen(scenario: s),
                                )),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.shade400),
                                tooltip: 'Xóa',
                                onPressed: () => _confirmDelete(
                                    context, ref, s.id, s.title),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _emptyHint(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(text,
            style: TextStyle(color: theme.textTheme.bodySmall?.color)),
      ),
    );
  }
}