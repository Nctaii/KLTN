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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(scenarioListProvider);
          ref.invalidate(mySessionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // 1. Lời chào
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Xin chào, $name 👋',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Hôm nay phiêu lưu vào thế giới nào?',
                                style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            listAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi tải: $e'),
              data: (scenarios) {
                if (scenarios.isEmpty) {
                  return _emptyState(theme);
                }
                final featured = scenarios.first;
                final latest = scenarios.take(8).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner(context, ref, featured, theme),
                    const SizedBox(height: 18),
                    _buildStats(theme, scenarios.length, sessionsAsync),
                    const SizedBox(height: 22),
                    _buildContinue(context, ref, sessionsAsync, theme),
                    Row(
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
                        const Text('Mới nhất',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 175,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: latest.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
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

  Widget _emptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.auto_stories,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('Chưa có scenario nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Hãy tạo scenario đầu tiên ở tab Khám phá!',
              style: TextStyle(color: theme.textTheme.bodySmall?.color)),
        ],
      ),
    );
  }

  void _openDetail(
      BuildContext context, WidgetRef ref, ScenarioSummary s) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScenarioDetailScreen(scenario: s),
    ));
    ref.invalidate(scenarioListProvider);
    ref.invalidate(mySessionsProvider);
  }

  // 2. Banner nổi bật - lớn, gradient đẹp
  Widget _buildBanner(
      BuildContext context, WidgetRef ref, ScenarioSummary s, ThemeData theme) {
    final cover = s.coverUrl;
    final fullCover = (cover != null && cover.isNotEmpty)
        ? ApiConfig.imageUrl(cover)
        : null;
    return GestureDetector(
      onTap: () => _openDetail(context, ref, s),
      child: Container(
        height: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surface,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (fullCover != null)
              Image.network(fullCover, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.5),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
                child: Icon(Icons.auto_stories,
                    size: 60,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4)),
              ),
            // Gradient phủ để chữ nổi
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            // Nhãn nổi bật
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 14, color: theme.colorScheme.onPrimary),
                    const SizedBox(width: 4),
                    Text('Nổi bật',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimary)),
                  ],
                ),
              ),
            ),
            // Tiêu đề + meta
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text('${s.playCount} lượt chơi',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(width: 10),
                      Text(s.genres.join(', '),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Thẻ thống kê
  Widget _buildStats(
      ThemeData theme, int scenarioCount, AsyncValue sessionsAsync) {
    final playingCount = sessionsAsync.valueOrNull?.length ?? 0;
    Widget stat(IconData icon, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        stat(Icons.menu_book, '$scenarioCount', 'Scenario'),
        const SizedBox(width: 12),
        stat(Icons.play_circle_outline, '$playingCount', 'Đang chơi'),
      ],
    );
  }

  // 4. Tiếp tục chơi
  Widget _buildContinue(BuildContext context, WidgetRef ref,
      AsyncValue sessionsAsync, ThemeData theme) {
    final sessions = sessionsAsync.valueOrNull;
    if (sessions == null || sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    final s = sessions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            const Text('Tiếp tục chơi',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book,
                      color: theme.colorScheme.onPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.storyTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${s.chapterCount} chương · ${s.mcName ?? "?"}',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  // 5. Thẻ nhỏ cuộn ngang
  Widget _miniCard(BuildContext context, WidgetRef ref, ScenarioSummary s,
      ThemeData theme) {
    final cover = s.coverUrl;
    final fullCover = (cover != null && cover.isNotEmpty)
        ? '${ApiConfig.baseUrl}$cover'
        : null;
    return GestureDetector(
      onTap: () => _openDetail(context, ref, s),
      child: SizedBox(
        width: 125,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 115,
              width: 125,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: fullCover != null
                  ? Image.network(fullCover, fit: BoxFit.cover)
                  : Center(
                      child: Icon(Icons.auto_stories,
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.5)),
                    ),
            ),
            const SizedBox(height: 6),
            Text(s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(s.genres.join(", "),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}