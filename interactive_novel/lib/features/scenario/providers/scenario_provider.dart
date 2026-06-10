import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/scenario_service.dart';
import '../models/scenario.dart';

part 'scenario_provider.g.dart';

@riverpod
ScenarioService scenarioService(Ref ref) =>
    ScenarioService(ref.watch(dioProvider));

// Danh sách scenario đã publish (tự nạp khi đọc)
@riverpod
class ScenarioList extends _$ScenarioList {
  @override
  Future<List<ScenarioSummary>> build() async {
    return ref.read(scenarioServiceProvider).listPublished();
  }

  // Nạp lại danh sách (sau khi tạo mới)
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(scenarioServiceProvider).listPublished(),
    );
  }
}