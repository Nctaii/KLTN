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
        ? ApiConfig.imageUrl(cover)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh bìa với tiêu đề + thể loại nổi trên ảnh
              Stack(
                children: [
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
                  // Gradient phủ dưới để chữ nổi
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Nhãn thể loại góc trên
                  if (scenario.genres.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Wrap(
                        spacing: 6,
                        children: scenario.genres
                            .map((g) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(g,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onPrimary,
                                      )),
                                ))
                            .toList(),
                      ),
                    ),
                  // Tiêu đề dưới đáy ảnh
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Text(
                      scenario.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Phần dưới: mô tả + chỉ số
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scenario.description != null &&
                        scenario.description!.isNotEmpty) ...[
                      Text(
                        scenario.description!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        _stat(theme, Icons.play_arrow_rounded,
                            scenario.playCount),
                        const SizedBox(width: 10),
                        _stat(theme, Icons.favorite, scenario.likeCount,
                            color: Colors.red.shade400),
                        const SizedBox(width: 10),
                        _stat(theme, Icons.chat_bubble,
                            scenario.commentCount),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.4),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  // Chỉ số dạng pill nhỏ
  Widget _stat(ThemeData theme, IconData icon, int value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14, color: color ?? theme.textTheme.bodySmall?.color),
          const SizedBox(width: 4),
          Text('$value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodySmall?.color,
              )),
        ],
      ),
    );
  }
}