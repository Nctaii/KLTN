import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/play_models.dart';
import '../providers/play_provider.dart';

class PlayScreen extends ConsumerStatefulWidget {
  final String storyId;
  final String storyTitle;
  final String? mcName;
  final String? existingSessionId; // có giá trị = mở lại lượt cũ
  final String? personality; // tính cách người chơi chọn (có thể null)
  const PlayScreen({
    super.key,
    required this.storyId,
    required this.storyTitle,
    this.mcName,
    this.existingSessionId,
    this.personality,
  });

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  bool _optionsExpanded = true;
  final _pageController = PageController();
  final _customCtrl = TextEditingController();

  String? _sessionId;
  final List<Chapter> _chapters = [];
  bool _loading = true;
  String? _error;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final p = _pageController.page?.round() ?? 0;
      if (p != _currentPage) setState(() => _currentPage = p);
    });
    if (widget.existingSessionId != null) {
      _resumePlay();
    } else {
      _startPlay();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _startPlay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(playServiceProvider)
          .start(widget.storyId, widget.mcName, widget.personality);
      setState(() {
        _sessionId = r.sessionId;
        _chapters.add(r.chapter);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _resumePlay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chapters = await ref
          .read(playServiceProvider)
          .getPlaythrough(widget.existingSessionId!);
      setState(() {
        _sessionId = widget.existingSessionId;
        _chapters.addAll(chapters);
        _loading = false;
      });
      await Future.delayed(const Duration(milliseconds: 100));
      if (_chapters.isNotEmpty) {
        _pageController.jumpToPage(_chapters.length - 1);
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _continue({String? optionId, String? custom}) async {
    setState(() => _loading = true);
    try {
      final chapter = await ref.read(playServiceProvider).continuePlay(
            _sessionId!,
            optionId: optionId,
            customDirection: custom,
          );
      setState(() {
        _chapters.add(chapter);
        _loading = false;
        _customCtrl.clear();
      });
      await Future.delayed(const Duration(milliseconds: 100));
      _pageController.animateToPage(
        _chapters.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi sinh chương: $e')),
        );
      }
    }
  }

  void _openCustomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tự viết hướng đi'),
        content: TextField(
          controller: _customCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập điều bạn muốn nhân vật làm tiếp theo...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _customCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _continue(custom: text);
            },
            child: const Text('Viết tiếp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storyTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_chapters.isNotEmpty)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: 'Mục lục',
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
        ],
      ),
      endDrawer: _buildChapterDrawer(theme),
      body: _buildBody(theme),
    );
  }

  Widget _buildChapterDrawer(ThemeData theme) {
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
                itemCount: _chapters.length,
                itemBuilder: (context, i) {
                  final ch = _chapters[i];
                  final preview =
                      ch.content.replaceAll('\n', ' ').trim();
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

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Không thể bắt đầu:\n$_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startPlay,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chapters.isEmpty && _loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text('Đang sáng tác chương mở đầu...',
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Chỉ báo trang nhỏ ở trên
        if (_chapters.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_chapters.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _chapters.length,
            itemBuilder: (context, i) {
              final ch = _chapters[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nhãn số chương trang trí
                    Row(
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
                      ],
                    ),
                    if (ch.chosenDirection != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                                color: theme.colorScheme.primary, width: 3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right,
                                size: 16,
                                color: theme.textTheme.bodySmall?.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(ch.chosenDirection!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: theme.textTheme.bodySmall?.color,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SelectableText(
                      ch.content,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.85,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ),
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final lastChapter = _chapters.last;
    // Chỉ hiện lựa chọn khi đang ở chương cuối
    final atLastChapter = _currentPage == _chapters.length - 1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        top: false,
        child: _loading
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text('Đang sáng tác chương tiếp theo...',
                        style: TextStyle(
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              )
            : !atLastChapter
                // Không ở chương cuối -> gợi ý quay lại chương cuối
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton.icon(
                      onPressed: () => _pageController.animateToPage(
                        _chapters.length - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      icon: const Icon(Icons.fast_forward),
                      label: const Text('Tới chương mới nhất để chơi tiếp'),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.alt_route,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Bạn sẽ làm gì tiếp theo?',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(_optionsExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up),
                            tooltip:
                                _optionsExpanded ? 'Thu gọn' : 'Mở rộng',
                            onPressed: () => setState(
                                () => _optionsExpanded = !_optionsExpanded),
                          ),
                        ],
                      ),
                      if (_optionsExpanded) ...[
                        const SizedBox(height: 6),
                        ...lastChapter.options.asMap().entries.map((e) {
                          final idx = e.key;
                          final opt = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              onPressed: () => _continue(optionId: opt.id),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('${idx + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        )),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(opt.label)),
                                ],
                              ),
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: _openCustomDialog,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Tự viết hướng đi khác'),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}