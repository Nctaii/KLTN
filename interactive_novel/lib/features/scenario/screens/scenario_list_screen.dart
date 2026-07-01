import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/scenario_provider.dart';
import 'create_scenario_screen.dart';
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
    final ref = this.ref;
    final listAsync = ref.watch(scenarioListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Khám phá')),
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
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['Tất cả', 'Tiên hiệp', 'Fantasy'].map((g) {
                final selected = _selectedGenre == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedGenre = g),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.textTheme.bodyMedium?.color,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text('Lỗi tải danh sách: $e')),
                  ],
                ),
                data: (allScenarios) {
                  final scenarios = _selectedGenre == 'Tất cả'
                      ? allScenarios
                      : allScenarios
                          .where((s) => s.genres.contains(_selectedGenre))
                          .toList();
                  if (scenarios.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Icon(Icons.search_off,
                            size: 56,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _selectedGenre == 'Tất cả'
                                ? 'Chưa có scenario nào. Hãy tạo mới!'
                                : 'Chưa có scenario thể loại $_selectedGenre.',
                            style: TextStyle(
                                color: theme.textTheme.bodySmall?.color),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: scenarios.length,
                    itemBuilder: (context, i) {
                      final s = scenarios[i];
                      return ScenarioCard(
                        scenario: s,
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ScenarioDetailScreen(scenario: s),
                          ));
                          ref
                              .read(scenarioListProvider.notifier)
                              .refresh();
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