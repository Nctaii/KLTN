import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scenario.dart';
import '../providers/scenario_provider.dart';

// Trang quản lý nút thắt cốt truyện (dùng cho cả tạo và sửa scenario).
// Nhận danh sách nút thắt + bối cảnh, trả về danh sách đã chỉnh khi pop.
class PlotPointsScreen extends ConsumerStatefulWidget {
  final List<PlotPointData> initial;
  final int genre;
  final Map<String, dynamic> world; // bối cảnh để AI sinh
  final Map<String, dynamic>? xh;
  final String title;

  const PlotPointsScreen({
    super.key,
    required this.initial,
    required this.genre,
    required this.world,
    this.xh,
    this.title = '',
  });

  @override
  ConsumerState<PlotPointsScreen> createState() => _PlotPointsScreenState();
}

class _PlotPointsScreenState extends ConsumerState<PlotPointsScreen> {
  late List<PlotPointData> _plots;
  final _countCtrl = TextEditingController(text: '5');
  bool _generating = false;
  final Set<int> _suggestingIdx = {};

  // Khung truyện cần đủ 3 trường cốt lõi thì AI mới sinh nút thắt chất lượng
  bool get _frameReady {
    final w = widget.world;
    bool ok(String k) => (w[k]?.toString().trim().isNotEmpty ?? false);
    return ok('world_setting') && ok('protagonist_role') && ok('final_goal');
  }

  List<String> get _missingFields {
    final w = widget.world;
    final missing = <String>[];
    if ((w['world_setting']?.toString().trim().isEmpty ?? true)) {
      missing.add('Bối cảnh thế giới');
    }
    if ((w['protagonist_role']?.toString().trim().isEmpty ?? true)) {
      missing.add('Thân phận nhân vật chính');
    }
    if ((w['final_goal']?.toString().trim().isEmpty ?? true)) {
      missing.add('Mục tiêu cuối');
    }
    return missing;
  }

  @override
  void initState() {
    super.initState();
    _plots = widget.initial
        .map((p) => PlotPointData(
              id: p.id,
              title: p.title,
              description: p.description,
              minChapters: p.minChapters,
              choices: p.choices
                  .map((c) => PlotChoiceData(id: c.id, label: c.label))
                  .toList(),
            ))
        .toList();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAll() async {
    if (!_frameReady) return;
    final count = int.tryParse(_countCtrl.text.trim()) ?? 5;
    setState(() => _generating = true);
    try {
      final result = await ref.read(scenarioServiceProvider).suggestPlotPoints(
            count: count,
            title: widget.title,
            genreIds: [widget.genre],
            world: widget.world,
            xh: widget.xh,
          );
      setState(() {
        for (final pp in result) {
          _plots.add(PlotPointData(
            title: pp.title,
            description: pp.description ?? '',
            minChapters: pp.minChapters,
            choices:
                pp.choices.map((c) => PlotChoiceData(label: c.label)).toList(),
          ));
        }
      });
      if (mounted && result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI chưa sinh được, thử lại nhé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi sinh nút thắt: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _suggestChoices(int idx) async {
    final pp = _plots[idx];
    if (pp.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy nhập tiêu đề nút thắt trước')),
      );
      return;
    }
    setState(() => _suggestingIdx.add(idx));
    try {
      final choices = await ref.read(scenarioServiceProvider).suggestPlotChoices(
            plotTitle: pp.title,
            plotDescription: pp.description,
            genreIds: [widget.genre],
            world: widget.world,
            xh: widget.xh,
          );
      setState(() {
        for (final c in choices) {
          pp.choices.add(PlotChoiceData(label: c.label));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi gợi ý: $e')));
      }
    } finally {
      if (mounted) setState(() => _suggestingIdx.remove(idx));
    }
  }

  void _save() {
    final cleaned = _plots.where((p) => p.title.trim().isNotEmpty).toList();
    Navigator.of(context).pop(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nút thắt cốt truyện'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Xong', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI sinh nút thắt',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Để AI thiết kế sẵn một bộ nút thắt dựa trên bối cảnh. Kết quả được thêm vào danh sách.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (!_frameReady) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cần điền đủ khung truyện trước khi AI sinh: ${_missingFields.join(", ")}.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số nút',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_generating || !_frameReady)
                              ? null
                              : _generateAll,
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.auto_awesome),
                          label: Text(_generating ? 'Đang sinh...' : 'AI sinh'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Danh sách nút thắt (${_plots.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton.filled(
                onPressed: () => setState(() => _plots.add(PlotPointData())),
                icon: const Icon(Icons.add),
                tooltip: 'Thêm nút thắt thủ công',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_plots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                    'Chưa có nút thắt nào.\nDùng AI sinh hoặc thêm thủ công.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ..._plots.asMap().entries.map((e) => _buildCard(e.key, e.value)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard(int i, PlotPointData pp) {
    final suggesting = _suggestingIdx.contains(i);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Nút thắt ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: i == 0
                    ? null
                    : () => setState(() {
                          final t = _plots.removeAt(i);
                          _plots.insert(i - 1, t);
                        }),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: i == _plots.length - 1
                    ? null
                    : () => setState(() {
                          final t = _plots.removeAt(i);
                          _plots.insert(i + 1, t);
                        }),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _plots.removeAt(i)),
              ),
            ]),
            TextFormField(
              initialValue: pp.title,
              decoration: const InputDecoration(labelText: 'Tiêu đề nút thắt'),
              onChanged: (v) => pp.title = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: pp.description,
              decoration: const InputDecoration(labelText: 'Mô tả tình huống'),
              maxLines: 2,
              onChanged: (v) => pp.description = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: pp.minChapters.toString(),
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Số chương tối thiểu'),
              onChanged: (v) => pp.minChapters = int.tryParse(v) ?? 2,
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('Các lựa chọn')),
              TextButton.icon(
                onPressed: suggesting ? null : () => _suggestChoices(i),
                icon: suggesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI gợi ý'),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () =>
                    setState(() => pp.choices.add(PlotChoiceData())),
              ),
            ]),
            ...pp.choices.asMap().entries.map((ce) {
              final ci = ce.key;
              final c = ce.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: c.label,
                      decoration: InputDecoration(
                          labelText: 'Lựa chọn ${ci + 1}', isDense: true),
                      onChanged: (v) => c.label = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => pp.choices.removeAt(ci)),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}