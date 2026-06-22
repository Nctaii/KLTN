import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/api_config.dart';
import '../models/scenario.dart';
import '../providers/scenario_provider.dart';
import 'plot_points_screen.dart';

// ---- Các lớp input mang theo id (null nếu là mục mới) ----
class _ItemInput {
  final int? id;
  final TextEditingController a;
  final TextEditingController b;
  String faction;
  _ItemInput({this.id, String a = '', String b = '', this.faction = 'chinh'})
      : a = TextEditingController(text: a),
        b = TextEditingController(text: b);
  void dispose() {
    a.dispose();
    b.dispose();
  }
}

class _ChoiceInput {
  final int? id;
  final TextEditingController label;
  _ChoiceInput({this.id, String label = ''})
      : label = TextEditingController(text: label);
  void dispose() => label.dispose();
}

class _PlotInput {
  final int? id;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController minChapters;
  final List<_ChoiceInput> choices;
  bool suggesting = false;
  _PlotInput({
    this.id,
    String title = '',
    String description = '',
    int minChapters = 2,
    List<_ChoiceInput>? choices,
  })  : title = TextEditingController(text: title),
        description = TextEditingController(text: description),
        minChapters = TextEditingController(text: minChapters.toString()),
        choices = choices ?? [];
  void dispose() {
    title.dispose();
    description.dispose();
    minChapters.dispose();
    for (final c in choices) {
      c.dispose();
    }
  }
}

class EditScenarioScreen extends ConsumerStatefulWidget {
  final ScenarioSummary scenario;
  const EditScenarioScreen({super.key, required this.scenario});
  @override
  ConsumerState<EditScenarioScreen> createState() =>
      _EditScenarioScreenState();
}

class _EditScenarioScreenState extends ConsumerState<EditScenarioScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _worldSetting = TextEditingController();
  final _protagonist = TextEditingController();
  final _mcName = TextEditingController();
  final _enemy = TextEditingController();
  final _goal = TextEditingController();
  final _cultivationNote = TextEditingController();
  final _mcSpiritRoot = TextEditingController();
  final _magicSystem = TextEditingController();

  // các danh sách (mang id)
  final List<_ItemInput> _characters = []; // a=name, b=role
  final List<_ItemInput> _personalities = []; // a=name
  final List<_ItemInput> _realms = []; // a=name
  final List<_ItemInput> _sects = []; // a=name, faction
  final List<_ItemInput> _techniques = []; // a=name
  final List<_ItemInput> _classes = []; // a=name (fantasy)
  final List<_ItemInput> _races = []; // a=name (fantasy)
  final List<_PlotInput> _plots = [];

  int _genre = 1; // 1 tiên hiệp, 2 fantasy
  String? _newCoverPath;
  bool _loading = true;
  bool _saving = false;
  bool _picking = false;
  String? _error;

  bool get _isXianxia => _genre == 1;
  bool get _isFantasy => _genre == 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref
          .read(scenarioServiceProvider)
          .getScenarioFull(widget.scenario.id);
      _title.text = (s['title'] ?? '').toString();
      _desc.text = (s['description'] ?? '').toString();

      // thể loại
      final genres = (s['genres'] as List?) ?? [];
      if (genres.isNotEmpty) {
        _genre = _toInt(genres.first['id']) ?? 1;
      }

      // world
      final w = s['world'] as Map<String, dynamic>?;
      if (w != null) {
        _worldSetting.text = (w['world_setting'] ?? '').toString();
        _protagonist.text = (w['protagonist_role'] ?? '').toString();
        _mcName.text = (w['default_mc_name'] ?? '').toString();
        _enemy.text = (w['enemy_description'] ?? '').toString();
        _goal.text = (w['final_goal'] ?? '').toString();
      }

      // nhân vật
      for (final c in (s['key_characters'] as List?) ?? []) {
        _characters.add(_ItemInput(
          id: _toInt(c['id']),
          a: (c['name'] ?? '').toString(),
          b: (c['role'] ?? '').toString(),
        ));
      }
      // tính cách
      for (final p in (s['personalities'] as List?) ?? []) {
        _personalities.add(_ItemInput(
          id: _toInt(p['id']),
          a: (p['name'] ?? '').toString(),
        ));
      }

      // tiên hiệp
      final xh = s['xh'] as Map<String, dynamic>?;
      if (xh != null) {
        _cultivationNote.text = (xh['cultivation_note'] ?? '').toString();
        _mcSpiritRoot.text = (xh['mc_spirit_root'] ?? '').toString();
        for (final r in (xh['realms'] as List?) ?? []) {
          _realms.add(_ItemInput(
            id: _toInt(r['id']),
            a: (r['name'] ?? '').toString(),
          ));
        }
        for (final sc in (xh['sects'] as List?) ?? []) {
          _sects.add(_ItemInput(
            id: _toInt(sc['id']),
            a: (sc['name'] ?? '').toString(),
            faction: (sc['faction'] ?? 'chinh').toString(),
          ));
        }
        for (final t in (xh['techniques'] as List?) ?? []) {
          _techniques.add(_ItemInput(
            id: _toInt(t['id']),
            a: (t['name'] ?? '').toString(),
          ));
        }
      }

      // fantasy
      final fnt = s['fnt'] as Map<String, dynamic>?;
      if (fnt != null) {
        _magicSystem.text = (fnt['magic_system'] ?? '').toString();
        for (final c in (fnt['classes'] as List?) ?? []) {
          _classes.add(_ItemInput(
            id: _toInt(c['id']),
            a: (c['name'] ?? '').toString(),
          ));
        }
        for (final r in (fnt['races'] as List?) ?? []) {
          _races.add(_ItemInput(
            id: _toInt(r['id']),
            a: (r['name'] ?? '').toString(),
          ));
        }
      }

      // nút thắt
      for (final pp in (s['plot_points'] as List?) ?? []) {
        final choices = <_ChoiceInput>[];
        for (final c in (pp['choices'] as List?) ?? []) {
          choices.add(_ChoiceInput(
            id: _toInt(c['id']),
            label: (c['label'] ?? '').toString(),
          ));
        }
        _plots.add(_PlotInput(
          id: _toInt(pp['id']),
          title: (pp['title'] ?? '').toString(),
          description: (pp['description'] ?? '').toString(),
          minChapters: _toInt(pp['min_chapters']) ?? 2,
          choices: choices,
        ));
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title, _desc, _worldSetting, _protagonist, _mcName, _enemy, _goal,
      _cultivationNote, _mcSpiritRoot, _magicSystem,
    ]) {
      c.dispose();
    }
    for (final l in [
      _characters, _personalities, _realms, _sects, _techniques, _classes, _races,
    ]) {
      for (final it in l) {
        it.dispose();
      }
    }
    for (final p in _plots) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_picking) return;
    _picking = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _newCoverPath = picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    } finally {
      _picking = false;
    }
  }


  // Mở trang quản lý nút thắt riêng (giữ id để đồng bộ an toàn)
  Future<void> _openPlotPoints() async {
    final initial = _plots
        .map((p) => PlotPointData(
              id: p.id,
              title: p.title.text,
              description: p.description.text,
              minChapters: int.tryParse(p.minChapters.text.trim()) ?? 2,
              choices: p.choices
                  .map((c) => PlotChoiceData(id: c.id, label: c.label.text))
                  .toList(),
            ))
        .toList();
    final result = await Navigator.of(context).push<List<PlotPointData>>(
      MaterialPageRoute(
        builder: (_) => PlotPointsScreen(
          initial: initial,
          genre: _genre,
          title: _title.text.trim(),
          world: {
            'world_setting': _worldSetting.text.trim(),
            'protagonist_role': _protagonist.text.trim(),
            'enemy_description': _enemy.text.trim(),
            'final_goal': _goal.text.trim(),
          },
          xh: _isXianxia
              ? {
                  'cultivation_note': _cultivationNote.text.trim(),
                  'mc_spirit_root': _mcSpiritRoot.text.trim(),
                }
              : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        for (final p in _plots) {
          p.dispose();
        }
        _plots
          ..clear()
          ..addAll(result.map((d) => _PlotInput(
                id: d.id,
                title: d.title,
                description: d.description,
                minChapters: d.minChapters,
                choices: d.choices
                    .map((c) => _ChoiceInput(id: c.id, label: c.label))
                    .toList(),
              )));
      });
    }
  }

  // Parse id/số an toàn: backend có thể trả BIGINT dạng String hoặc num
  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> _buildBody() {
    List<Map<String, dynamic>> mapItems(
            List<_ItemInput> list, String keyA, [String? keyB]) =>
        list
            .where((it) => it.a.text.trim().isNotEmpty)
            .map((it) => {
                  if (it.id != null) 'id': it.id,
                  keyA: it.a.text.trim(),
                  if (keyB != null) keyB: it.b.text.trim(),
                })
            .toList();

    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'world': {
        'world_setting': _worldSetting.text.trim(),
        'protagonist_role': _protagonist.text.trim(),
        'default_mc_name': _mcName.text.trim(),
        'enemy_description': _enemy.text.trim(),
        'final_goal': _goal.text.trim(),
      },
      'key_characters': mapItems(_characters, 'name', 'role'),
      'personalities': mapItems(_personalities, 'name'),
      'plot_points': _plots
          .where((p) => p.title.text.trim().isNotEmpty)
          .map((p) => {
                if (p.id != null) 'id': p.id,
                'title': p.title.text.trim(),
                'description': p.description.text.trim(),
                'min_chapters': int.tryParse(p.minChapters.text.trim()) ?? 2,
                'choices': p.choices
                    .where((c) => c.label.text.trim().isNotEmpty)
                    .map((c) => {
                          if (c.id != null) 'id': c.id,
                          'label': c.label.text.trim(),
                        })
                    .toList(),
              })
          .toList(),
    };

    if (_isXianxia) {
      body['xh'] = {
        'cultivation_note': _cultivationNote.text.trim(),
        'mc_spirit_root': _mcSpiritRoot.text.trim(),
        'realms': _realms
            .where((r) => r.a.text.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => {
                  if (e.value.id != null) 'id': e.value.id,
                  'name': e.value.a.text.trim(),
                  'tier': e.key + 1,
                })
            .toList(),
        'sects': _sects
            .where((s) => s.a.text.trim().isNotEmpty)
            .map((s) => {
                  if (s.id != null) 'id': s.id,
                  'name': s.a.text.trim(),
                  'faction': s.faction,
                })
            .toList(),
        'techniques': mapItems(_techniques, 'name'),
      };
    }
    if (_isFantasy) {
      body['fnt'] = {
        'magic_system': _magicSystem.text.trim(),
        'has_mana': true,
        'classes': mapItems(_classes, 'name'),
        'races': mapItems(_races, 'name'),
      };
    }
    return body;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên không được trống')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = ref.read(scenarioServiceProvider);
      await svc.updateFull(widget.scenario.id, _buildBody());
      if (_newCoverPath != null) {
        await svc.uploadCover(widget.scenario.id, _newCoverPath!);
      }
      ref.invalidate(myScenariosProvider);
      ref.invalidate(scenarioListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thay đổi')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  // Danh sách item đơn giản (1 ô) có thêm/xóa
  List<Widget> _simpleList(
      String label, List<_ItemInput> list, VoidCallback onAdd) {
    return [
      Row(children: [
        Expanded(child: Text(label)),
        IconButton.filled(onPressed: onAdd, icon: const Icon(Icons.add)),
      ]),
      ...list.asMap().entries.map((e) {
        final i = e.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: e.value.a,
                decoration: InputDecoration(labelText: '$label ${i + 1}'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() {
                e.value.dispose();
                list.removeAt(i);
              }),
            ),
          ]),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sửa scenario')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sửa scenario')),
        body: Center(child: Text('Lỗi tải: $_error')),
      );
    }

    final oldCover = widget.scenario.coverUrl;
    final fullOldCover = (oldCover != null && oldCover.isNotEmpty)
        ? ApiConfig.imageUrl(oldCover)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sửa scenario')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ảnh bìa
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                image: _newCoverPath != null
                    ? DecorationImage(
                        image: FileImage(File(_newCoverPath!)), fit: BoxFit.cover)
                    : (fullOldCover != null
                        ? DecorationImage(
                            image: NetworkImage(fullOldCover), fit: BoxFit.cover)
                        : null),
              ),
              child: (_newCoverPath == null && fullOldCover == null)
                  ? const Center(child: Text('Chọn ảnh bìa'))
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tên scenario'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Mô tả'),
            maxLines: 3,
          ),

          _sectionTitle('Bối cảnh thế giới'),
          TextField(controller: _worldSetting, decoration: const InputDecoration(labelText: 'Bối cảnh'), maxLines: 2),
          const SizedBox(height: 8),
          TextField(controller: _protagonist, decoration: const InputDecoration(labelText: 'Thân phận NV chính')),
          const SizedBox(height: 8),
          TextField(controller: _mcName, decoration: const InputDecoration(labelText: 'Tên mặc định NV chính')),
          const SizedBox(height: 8),
          TextField(controller: _enemy, decoration: const InputDecoration(labelText: 'Kẻ thù'), maxLines: 2),
          const SizedBox(height: 8),
          TextField(controller: _goal, decoration: const InputDecoration(labelText: 'Mục tiêu cuối'), maxLines: 2),

          _sectionTitle('Nhân vật quan trọng'),
          Row(children: [
            const Expanded(child: Text('Nhân vật')),
            IconButton.filled(
              onPressed: () => setState(() => _characters.add(_ItemInput())),
              icon: const Icon(Icons.add),
            ),
          ]),
          ..._characters.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: e.value.a,
                    decoration: InputDecoration(labelText: 'Tên ${i + 1}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: e.value.b,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    e.value.dispose();
                    _characters.removeAt(i);
                  }),
                ),
              ]),
            );
          }),

          _sectionTitle('Tính cách (cho người chơi chọn)'),
          ..._simpleList('Tính cách', _personalities,
              () => setState(() => _personalities.add(_ItemInput()))),

          // Nút thắt
          _sectionTitle('Nút thắt cốt truyện'),
          const Text('Quản lý ở trang riêng (thêm/sửa/xóa/sắp xếp, AI sinh).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openPlotPoints,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text('Quản lý nút thắt (${_plots.length})'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          // Tiên hiệp
          if (_isXianxia) ...[
            _sectionTitle('Hệ thống tu luyện (Tiên hiệp)'),
            TextField(controller: _cultivationNote, decoration: const InputDecoration(labelText: 'Mô tả tu luyện'), maxLines: 2),
            const SizedBox(height: 8),
            TextField(controller: _mcSpiritRoot, decoration: const InputDecoration(labelText: 'Linh căn/thể chất NV chính'), maxLines: 2),
            const SizedBox(height: 12),
            ..._simpleList('Cảnh giới', _realms,
                () => setState(() => _realms.add(_ItemInput()))),
            const SizedBox(height: 12),
            // Tông môn (có phe)
            Row(children: [
              const Expanded(child: Text('Tông môn (chính/tà)')),
              IconButton.filled(
                onPressed: () => setState(() => _sects.add(_ItemInput())),
                icon: const Icon(Icons.add),
              ),
            ]),
            ..._sects.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: e.value.a,
                      decoration: InputDecoration(labelText: 'Tông môn ${i + 1}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: e.value.faction,
                    items: const [
                      DropdownMenuItem(value: 'chinh', child: Text('Chính')),
                      DropdownMenuItem(value: 'ta', child: Text('Tà')),
                    ],
                    onChanged: (v) =>
                        setState(() => e.value.faction = v ?? 'chinh'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      e.value.dispose();
                      _sects.removeAt(i);
                    }),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 12),
            ..._simpleList('Công pháp', _techniques,
                () => setState(() => _techniques.add(_ItemInput()))),
          ],

          // Fantasy
          if (_isFantasy) ...[
            _sectionTitle('Hệ thống Fantasy'),
            TextField(controller: _magicSystem, decoration: const InputDecoration(labelText: 'Hệ thống ma pháp'), maxLines: 2),
            const SizedBox(height: 12),
            ..._simpleList('Lớp', _classes,
                () => setState(() => _classes.add(_ItemInput()))),
            const SizedBox(height: 12),
            ..._simpleList('Chủng tộc', _races,
                () => setState(() => _races.add(_ItemInput()))),
          ],

          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _save,
                    child: const Text('Lưu thay đổi'),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

}