import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interactive_novel/features/play/screen/play_screen.dart';
import '../providers/scenario_provider.dart';
import 'create_scenario_screen.dart';
import '../../play/providers/play_provider.dart';
import '../widgets/scenario_card.dart';
import 'scenario_detail_screen.dart';

class ScenarioListScreen extends ConsumerStatefulWidget {
  const ScenarioListScreen({super.key});
  @override
  ConsumerState<ScenarioListScreen> createState() =>
      _ScenarioListScreenState();
}

class _ScenarioListScreenState extends ConsumerState<ScenarioListScreen> {
  String _selectedGenre = 'Tất cả'; // bộ lọc đang chọn

  @override
  Widget build(BuildContext context) {
    final ref = this.ref; // để các đoạn code cũ dùng 'ref' vẫn chạy
    final listAsync = ref.watch(scenarioListProvider);

    Future<void> _startPlay(
      BuildContext context, WidgetRef ref, String storyId, String title) async {
    // Kiểm tra đã có lượt chơi cho scenario này chưa
    final sessions = ref.read(mySessionsProvider).valueOrNull ?? [];
    final hasOld = sessions.any((s) => s.storyId == storyId);

    if (hasOld) {
      // Hỏi xác nhận xóa lượt cũ
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã có lượt chơi'),
          content: Text(
            'Bạn đã có một lượt chơi dở cho "$title". '
            'Bắt đầu lượt mới sẽ xóa tiến trình cũ. Tiếp tục?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa & chơi mới'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      // Xóa lượt cũ
      try {
        await ref.read(playServiceProvider).deleteByStory(storyId);
        await ref.read(mySessionsProvider.notifier).refresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không xóa được lượt cũ: $e')),
          );
        }
        return;
      }
    }

    // Hộp thoại nhập tên nhân vật
    if (!context.mounted) return;
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
      body: Column(
        children: [
          // Thanh lọc thể loại
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: ['Tất cả', 'Tiên hiệp', 'Fantasy'].map((g) {
                final selected = _selectedGenre == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedGenre = g),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(scenarioListProvider.notifier).refresh(),
              child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 100),
              Center(child: Text('Lỗi tải danh sách: $e')),
            ],
          ),
          data: (allScenarios) {
            // Lọc theo thể loại đang chọn
            final scenarios = _selectedGenre == 'Tất cả'
                ? allScenarios
                : allScenarios
                    .where((s) => s.genres.contains(_selectedGenre))
                    .toList();
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
                return ScenarioCard(
                  scenario: s,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ScenarioDetailScreen(scenario: s),
                    ));
                    // Quay về làm mới danh sách (like/comment có thể đã đổi)
                    ref.read(scenarioListProvider.notifier).refresh();
                  },
                );
              },
            );
          },
              ),
            ),
          ),
        ],
      ),
    );
  }
}