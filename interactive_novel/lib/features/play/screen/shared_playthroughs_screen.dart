import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/play_models.dart';
import '../providers/play_provider.dart';

// Danh sách các lượt chơi được chia sẻ công khai
class SharedPlaythroughsScreen extends ConsumerStatefulWidget {
  const SharedPlaythroughsScreen({super.key});
  @override
  ConsumerState<SharedPlaythroughsScreen> createState() =>
      _SharedPlaythroughsScreenState();
}

class _SharedPlaythroughsScreenState
    extends ConsumerState<SharedPlaythroughsScreen> {
  late Future<List<PublishedSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(playServiceProvider).listPublished();
  }

  void _reload() {
    setState(() {
      _future = ref.read(playServiceProvider).listPublished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lượt chơi chia sẻ')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<PublishedSession>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Lỗi tải: ${snap.error}'),
                ),
              ]);
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('Chưa có lượt chơi nào được chia sẻ.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ReadPlaythroughScreen(sessionId: s.sessionId),
                      )),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.auto_stories,
                                  color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.authorName ?? "Ẩn danh"} · ${s.mcName ?? "?"} · ${s.chapterCount} chương',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.textTheme.bodySmall?.color),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Màn đọc một lượt chơi công khai (chỉ đọc, tuần tự)
class ReadPlaythroughScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ReadPlaythroughScreen({super.key, required this.sessionId});
  @override
  ConsumerState<ReadPlaythroughScreen> createState() =>
      _ReadPlaythroughScreenState();
}

class _ReadPlaythroughScreenState
    extends ConsumerState<ReadPlaythroughScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  PublishedPlaythrough? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final p = _pageController.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final pt =
          await ref.read(playServiceProvider).getPublished(widget.sessionId);
      setState(() {
        _data = pt;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đọc truyện')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đọc truyện')),
        body: Center(child: Text('Lỗi tải: $_error')),
      );
    }
    final pt = _data!;
    final chapters = pt.chapters;

    return Scaffold(
      endDrawer: _buildChapterDrawer(theme, chapters),
      appBar: AppBar(
        title: Text(pt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'Mục lục',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: chapters.isEmpty
          ? const Center(child: Text('Lượt chơi này chưa có chương nào.'))
          : Column(
              children: [
                // Thanh thông tin + chỉ số chương
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pt.storyTitle} · ${pt.authorName ?? "Ẩn danh"} · NV: ${pt.mcName ?? "?"}',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chương ${_currentPage + 1} / ${chapters.length}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                // PageView: vuốt sang hai bên để chuyển chương
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: chapters.length,
                    itemBuilder: (context, i) {
                      final ch = chapters[i];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('CHƯƠNG ${ch.chapterNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: theme.colorScheme.primary,
                                  )),
                            ),
                            if (ch.chosenDirection != null &&
                                ch.chosenDirection!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.subdirectory_arrow_right,
                                        size: 16,
                                        color:
                                            theme.textTheme.bodySmall?.color),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          'Đã chọn: ${ch.chosenDirection}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              color: theme
                                                  .textTheme.bodySmall?.color)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(ch.content,
                                style: const TextStyle(
                                    fontSize: 16, height: 1.7)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Thanh điều hướng trước/sau
                SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentPage > 0
                                ? () => _pageController.animateToPage(
                                      _currentPage - 1,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    )
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Trước'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentPage < chapters.length - 1
                                ? () => _pageController.animateToPage(
                                      _currentPage + 1,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    )
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Sau'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChapterDrawer(ThemeData theme, List<PublishedChapter> chapters) {
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Mục lục',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      )),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  final ch = chapters[i];
                  final preview = ch.content.replaceAll('\n', ' ').trim();
                  final snippet = preview.length > 60
                      ? '${preview.substring(0, 60)}...'
                      : preview;
                  final isCurrent = i == _currentPage;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary
                                .withValues(alpha: 0.18),
                        child: Text('${ch.chapterNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                            )),
                      ),
                      title: Text('Chương ${ch.chapterNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(snippet,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(context);
                        _pageController.jumpToPage(i);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}