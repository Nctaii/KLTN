import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/play_service.dart';
import '../models/play_models.dart';

part 'play_provider.g.dart';

@riverpod
PlayService playService(Ref ref) => PlayService(ref.watch(dioProvider));

// Danh sách lượt chơi đang dở của user
@riverpod
class MySessions extends _$MySessions {
  @override
  Future<List<PlaySessionSummary>> build() async {
    return ref.read(playServiceProvider).listMySessions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(playServiceProvider).listMySessions(),
    );
  }
}