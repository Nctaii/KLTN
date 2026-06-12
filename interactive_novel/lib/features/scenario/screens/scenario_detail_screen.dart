import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_config.dart';
import '../../play/screen/play_screen.dart';
import '../models/scenario.dart';
import '../models/interaction.dart';
import '../providers/scenario_provider.dart';

class ScenarioDetailScreen extends ConsumerStatefulWidget {
  final ScenarioSummary scenario;
  const ScenarioDetailScreen({super.key, required this.scenario});
  @override
  ConsumerState<ScenarioDetailScreen> createState() =>
      _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends ConsumerState<ScenarioDetailScreen> {
  final _commentCtrl = TextEditingController();
  LikeInfo? _likeInfo;
  List<ScenarioComment> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(scenarioServiceProvider);
      final like = await svc.getLikeInfo(widget.scenario.id);
      final comments = await svc.listComments(widget.scenario.id);
      setState(() {
        _likeInfo = like;
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải: $e')),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      final updated = await ref
          .read(scenarioServiceProvider)
          .toggleLike(widget.scenario.id);
      setState(() => _likeInfo = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref
          .read(scenarioServiceProvider)
          .addComment(widget.scenario.id, text);
      _commentCtrl.clear();
      final comments = await ref
          .read(scenarioServiceProvider)
          .listComments(widget.scenario.id);
      setState(() {
        _comments = comments;
        _posting = false;
      });
    } catch (e) {
      setState(() => _posting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi bình luận: $e')),
        );
      }
    }
  }

  Future<void> _play() async {
    List<Map<String, dynamic>> personalities = [];
    try {
      final full = await ref
          .read(scenarioServiceProvider)
          .getScenarioFull(widget.scenario.id);
      final list = (full['personalities'] as List?) ?? [];
      personalities = list.cast<Map<String, dynamic>>();
    } catch (_) {}

    if (!mounted) return;

    final nameCtrl = TextEditingController();
    String? selectedPersonality;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Nhập vai'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhân vật (để trống dùng mặc định)',
                  ),
                ),
                if (personalities.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Chọn tính cách nhân vật (tùy chọn):',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: personalities.map((p) {
                      final name = (p['name'] ?? '').toString();
                      final selected = selectedPersonality == name;
                      return ChoiceChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: (v) => setDialog(() {
                          selectedPersonality = v ? name : null;
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
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
                    storyId: widget.scenario.id,
                    storyTitle: widget.scenario.title,
                    mcName: name.isEmpty ? null : name,
                    personality: selectedPersonality,
                  ),
                ));
              },
              child: const Text('Bắt đầu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final theme = Theme.of(context);
    final cover = s.coverUrl;
    final fullCover = (cover != null && cover.isNotEmpty)
        ? '${ApiConfig.baseUrl}$cover'
        : null;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Ảnh bìa lớn kiểu poster + tiêu đề nổi trên ảnh
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.colorScheme.surface,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (fullCover != null)
                          Image.network(fullCover, fit: BoxFit.cover)
                        else
                          Container(
                            color: theme.colorScheme.surface,
                            child: Icon(Icons.auto_stories,
                                size: 80,
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.4)),
                          ),
                        // Lớp phủ gradient để chữ nổi rõ
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                                theme.scaffoldBackgroundColor,
                              ],
                              stops: const [0.35, 0.7, 1.0],
                            ),
                          ),
                        ),
                        // Tiêu đề + thể loại ở đáy ảnh
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 6,
                                children: s.genres
                                    .map((g) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(g,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme
                                                    .colorScheme.onPrimary,
                                              )),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 10),
                              Text(s.title,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 8,
                                          color: Colors.black54)
                                    ],
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng chỉ số: lượt chơi + thích
                        Row(
                          children: [
                            _statPill(theme, Icons.play_arrow_rounded,
                                '${s.playCount}', 'lượt chơi'),
                            const SizedBox(width: 12),
                            _likePill(theme),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Nút Chơi lớn nổi bật
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _play,
                            icon: const Icon(Icons.play_circle_fill),
                            label: const Text('Bắt đầu phiêu lưu',
                                style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 54)),
                          ),
                        ),
                        if (s.description != null &&
                            s.description!.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Text('Giới thiệu',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(s.description!,
                              style: const TextStyle(height: 1.6)),
                        ],
                        const SizedBox(height: 24),
                        Divider(color: theme.dividerColor),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Bình luận (${_comments.length})',
                                style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Ô viết comment
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Viết bình luận...',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: _posting
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color:
                                                theme.colorScheme.onPrimary))
                                    : Icon(Icons.send,
                                        color: theme.colorScheme.onPrimary),
                                onPressed: _posting ? null : _postComment,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text('Chưa có bình luận nào.',
                                  style: TextStyle(
                                      color:
                                          theme.textTheme.bodySmall?.color)),
                            ),
                          ),
                        ..._comments.map((c) => _commentTile(theme, c)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statPill(
      ThemeData theme, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: theme.textTheme.bodySmall?.color)),
        ],
      ),
    );
  }

  Widget _likePill(ThemeData theme) {
    final liked = _likeInfo?.likedByMe == true;
    return InkWell(
      onTap: _toggleLike,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: liked
              ? Colors.red.shade400.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border,
                size: 20, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text('${_likeInfo?.likeCount ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _commentTile(ThemeData theme, ScenarioComment c) {
    final av = c.authorAvatar;
    final fullAv = (av != null && av.isNotEmpty)
        ? '${ApiConfig.baseUrl}$av'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            backgroundImage: fullAv != null ? NetworkImage(fullAv) : null,
            child: fullAv == null
                ? Icon(Icons.person,
                    size: 20, color: theme.colorScheme.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      )),
                  const SizedBox(height: 4),
                  Text(c.content, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}