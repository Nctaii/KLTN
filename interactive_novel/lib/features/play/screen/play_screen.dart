import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/play_models.dart';
import '../providers/play_provider.dart';

class PlayScreen extends ConsumerStatefulWidget {
  final String storyId;
  final String storyTitle;
  final String? mcName;
  final String? existingSessionId; // có giá trị = mở lại lượt cũ
  const PlayScreen({
    super.key,
    required this.storyId,
    required this.storyTitle,
    this.mcName,
    this.existingSessionId,
  });

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  final _pageController = PageController();
  final _customCtrl = TextEditingController();

  String? _sessionId;
  final List<Chapter> _chapters = [];
  bool _loading = true; // đang tải/sinh chương
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingSessionId != null) {
      _resumePlay(); // mở lại lượt cũ
    } else {
      _startPlay(); // bắt đầu mới
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
          .start(widget.storyId, widget.mcName);
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

  // Mở lại lượt chơi cũ: tải toàn bộ chương, nhảy tới chương cuối
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
      // Nhảy tới chương cuối sau khi build xong
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

  // Chơi tiếp: chọn option hoặc tự viết
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
      // Lật sang trang chương mới
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
        title: Text(widget.storyTitle),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Lỗi khi bắt đầu chơi
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Không thể bắt đầu: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startPlay,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    // Đang sinh chương đầu tiên
    if (_chapters.isEmpty && _loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang sáng tác chương mở đầu...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Vùng đọc chương: lật trang qua lại
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _chapters.length,
            itemBuilder: (context, i) {
              final ch = _chapters[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chương ${ch.chapterNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (ch.chosenDirection != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '↳ ${ch.chosenDirection}',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      ch.content,
                      style: const TextStyle(fontSize: 16, height: 1.7),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),

        // Thanh điều khiển dưới: chỉ thị trang + lựa chọn (ở chương cuối)
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final lastChapter = _chapters.last;
    // Đang xem chương cuối hay không (để hiện lựa chọn)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Đang sáng tác chương tiếp theo...'),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bạn sẽ làm gì tiếp theo?',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Các lựa chọn AI gợi ý
                  ...lastChapter.options.map((opt) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: () => _continue(optionId: opt.id),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(14),
                          ),
                          child: Text(opt.label),
                        ),
                      )),
                  // Nút tự viết
                  TextButton.icon(
                    onPressed: _openCustomDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('Tự viết hướng đi khác'),
                  ),
                ],
              ),
      ),
    );
  }
}