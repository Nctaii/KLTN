import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_config.dart';
import '../auth/providers/auth_provider.dart';
import '../play/screen/play_screen.dart';
import '../scenario/providers/scenario_provider.dart';
import '../scenario/models/scenario.dart';
import '../scenario/screens/scenario_detail_screen.dart';
import '../play/providers/play_provider.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final listAsync = ref.watch(scenarioListProvider);
    final sessionsAsync = ref.watch(mySessionsProvider);
    final theme = Theme.of(context);
    final name = authState.valueOrNull?.displayName ??
        authState.valueOrNull?.username ??
        'bạn';

    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(scenarioListProvider);
          ref.invalidate(mySessionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Lời chào
            Text('Xin chào, $name 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('Hôm nay phiêu lưu vào thế giới nào?',
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 16),

            // 2 + 5. Banner nổi bật + hàng cuộn ngang (lấy từ danh sách scenario)
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
                final featured = scenarios.first; // nổi bật = cái đầu
                final latest = scenarios.take(8).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner(context, ref, featured, theme),
                    const SizedBox(height: 16),
                    // 3. Thẻ thống kê
                    _buildStats(theme, scenarios.length, sessionsAsync),
                    const SizedBox(height: 20),
                    // 4. Tiếp tục chơi
                    _buildContinue(context, ref, sessionsAsync, theme),
                    // 5. Hàng mới nhất cuộn ngang
                    const Text('Mới nhất',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: latest.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) =>
                            _miniCard(context, ref, latest[i], theme),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Mở chi tiết scenario
  void _openDetail(BuildContext context, WidgetRef ref, ScenarioSummary s) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScenarioDetailScreen(scenario: s),
    ));
    ref.invalidate(scenarioListProvider);
    ref.invalidate(mySessionsProvider);
  }

  // 2. Banner nổi bật
  Widget _buildBanner(
      BuildContext context, WidgetRef ref, ScenarioSummary s, ThemeData theme) {
    final cover = s.coverUrl;
    final fullCover = (cover != null && cover.isNotEmpty)
        ? '${ApiConfig.baseUrl}$cover'
        : null;
    return GestureDetector(
      onTap: () => _openDetail(context, ref, s),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          image: fullCover != null
              ? DecorationImage(
                  image: NetworkImage(fullCover),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.35),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Nổi bật',
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.onPrimary)),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: fullCover != null ? Colors.white : null,
                      )),
                  Text('${s.genres.join(", ")} · ${s.playCount} lượt chơi',
                      style: TextStyle(
                        fontSize: 12,
                        color: fullCover != null
                            ? Colors.white70
                            : theme.textTheme.bodySmall?.color,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Thẻ thống kê
  Widget _buildStats(ThemeData theme, int scenarioCount, AsyncValue sessionsAsync) {
    final playingCount = sessionsAsync.valueOrNull?.length ?? 0;
    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text('$value',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        stat('$scenarioCount', 'Scenario'),
        const SizedBox(width: 8),
        stat('$playingCount', 'Đang chơi'),
      ],
    );
  }

  // 4. Tiếp tục chơi (lượt dở gần nhất)
  Widget _buildContinue(BuildContext context, WidgetRef ref,
      AsyncValue sessionsAsync, ThemeData theme) {
    final sessions = sessionsAsync.valueOrNull;
    if (sessions == null || sessions.isEmpty) {
      return const SizedBox.shrink(); // không có lượt dở thì ẩn
    }
    final s = sessions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tiếp tục chơi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
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
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.storyTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('${s.chapterCount} chương · ${s.mcName ?? "?"}',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // 5. Thẻ nhỏ cho hàng cuộn ngang
  Widget _miniCard(BuildContext context, WidgetRef ref, ScenarioSummary s,
      ThemeData theme) {
    final cover = s.coverUrl;
    final fullCover = (cover != null && cover.isNotEmpty)
        ? '${ApiConfig.baseUrl}$cover'
        : null;
    return GestureDetector(
      onTap: () => _openDetail(context, ref, s),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                image: fullCover != null
                    ? DecorationImage(
                        image: NetworkImage(fullCover), fit: BoxFit.cover)
                    : null,
              ),
              child: fullCover == null
                  ? Icon(Icons.auto_stories,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5))
                  : null,
            ),
            const SizedBox(height: 4),
            Text(s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(s.genres.join(", "),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}