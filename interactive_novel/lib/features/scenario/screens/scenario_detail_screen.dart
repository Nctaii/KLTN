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

class _ScenarioDetailScreenState
    extends ConsumerState<ScenarioDetailScreen> {
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
      final updated =
          await ref.read(scenarioServiceProvider).toggleLike(widget.scenario.id);
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
      await ref.read(scenarioServiceProvider).addComment(widget.scenario.id, text);
      _commentCtrl.clear();
      final comments =
          await ref.read(scenarioServiceProvider).listComments(widget.scenario.id);
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

  void _play() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập vai'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên nhân vật (để trống dùng mặc định)',
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
                ),
              ));
            },
            child: const Text('Bắt đầu'),
          ),
        ],
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
      appBar: AppBar(title: Text(s.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Ảnh bìa
                if (fullCover != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(fullCover, fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(s.genres.join(' · '),
                          style: TextStyle(color: theme.colorScheme.primary)),
                      if (s.description != null) ...[
                        const SizedBox(height: 12),
                        Text(s.description!, style: const TextStyle(height: 1.5)),
                      ],
                      const SizedBox(height: 16),
                      // Hàng nút: like + chơi
                      Row(
                        children: [
                          InkWell(
                            onTap: _toggleLike,
                            child: Row(
                              children: [
                                Icon(
                                  _likeInfo?.likedByMe == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text('${_likeInfo?.likeCount ?? 0}'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Icon(Icons.play_arrow,
                              size: 18, color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text('${s.playCount}'),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _play,
                            icon: const Icon(Icons.play_circle),
                            label: const Text('Chơi'),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text('Bình luận (${_comments.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
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
                          IconButton(
                            icon: _posting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send),
                            onPressed: _posting ? null : _postComment,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Danh sách comment
                      if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Chưa có bình luận nào.',
                              style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color)),
                        ),
                      ..._comments.map((c) {
                        // Dựng URL avatar đầy đủ (nếu có)
                        final av = c.authorAvatar;
                        final fullAv = (av != null && av.isNotEmpty)
                            ? '${ApiConfig.baseUrl}$av'
                            : null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar nhỏ bên trái
                              CircleAvatar(
                                radius: 15,
                                backgroundImage:
                                    fullAv != null ? NetworkImage(fullAv) : null,
                                child: fullAv == null
                                    ? const Icon(Icons.person, size: 20)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              // Tên đậm + nội dung
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(c.content),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}