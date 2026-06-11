import 'package:flutter/material.dart';
import '../../../core/api_config.dart';
import '../models/scenario.dart';

class ScenarioCard extends StatelessWidget {
  final ScenarioSummary scenario;
  final VoidCallback onTap;
  const ScenarioCard({super.key, required this.scenario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = scenario.coverUrl;
    final fullCover = (cover != null && cover.isNotEmpty)
        ? '${ApiConfig.baseUrl}$cover'
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh bìa (hoặc nền gradient nếu chưa có ảnh)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: fullCover != null
                  ? Image.network(
                      fullCover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(theme),
                    )
                  : _placeholder(theme),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (scenario.genres.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      scenario.genres.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (scenario.description != null &&
                      scenario.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      scenario.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Ba chỉ số kèm icon
                  Row(
                    children: [
                      _stat(theme, Icons.play_arrow, scenario.playCount),
                      const SizedBox(width: 16),
                      _stat(theme, Icons.favorite, scenario.likeCount),
                      const SizedBox(width: 16),
                      _stat(theme, Icons.comment, scenario.commentCount),
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

  // Nền thay thế khi chưa có ảnh
  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.auto_stories,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, IconData icon, int value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}