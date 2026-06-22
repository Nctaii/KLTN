import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scenario.dart';
import '../providers/scenario_provider.dart';
import 'plot_points_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateScenarioScreen extends ConsumerStatefulWidget {
  const CreateScenarioScreen({super.key});
  @override
  ConsumerState<CreateScenarioScreen> createState() =>
      _CreateScenarioScreenState();
}

class _CreateScenarioScreenState
    extends ConsumerState<CreateScenarioScreen> {
  // Các controller cho trường nhập
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _worldSetting = TextEditingController();
  final _protagonist = TextEditingController();
  final _mcName = TextEditingController();
  final _enemy = TextEditingController();
  final _goal = TextEditingController();
  final _cultivationNote = TextEditingController();

  // Thể loại đang chọn (1 = Tiên hiệp, 2 = Fantasy)
    int _genre = 1;
  // đường dẫn ảnh bìa đã chọn (chưa upload)
    String? _coverPath; 

  // Danh sách nhân vật quan trọng (động)
  final List<({TextEditingController name, TextEditingController role})>
      _characters = [];

  // Danh sách cảnh giới (động, chỉ dùng cho tiên hiệp)
  final List<TextEditingController> _realms = [];

  // Tiên hiệp: linh căn NV chính, tông môn, công pháp
  final _mcSpiritRoot = TextEditingController();
  final List<_SectInput> _sects = []; // tông môn: tên + phe (chinh/ta)
  final List<TextEditingController> _techniques = [];

  // Nút thắt cốt truyện (mọi thể loại) - quản lý ở trang riêng
  final List<PlotPointData> _plotPoints = [];

  final _magicSystem = TextEditingController();
  final List<TextEditingController> _classes = [];
  final List<TextEditingController> _races = [];
  final List<TextEditingController> _personalities = []; // tính cách cho người chơi chọn

  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _title, _desc, _worldSetting, _protagonist,
      _mcName, _enemy, _goal, _cultivationNote
    ]) {
      c.dispose();
    }
    for (final c in _characters) {
      c.name.dispose();
      c.role.dispose();
    }
    for (final c in _realms) {
      c.dispose();
    }
    _mcSpiritRoot.dispose();
    for (final s in _sects) {
      s.name.dispose();
    }
    for (final c in _techniques) {
      c.dispose();
    }
    super.dispose();
    _magicSystem.dispose();
    for (final c in _classes) c.dispose();
    for (final c in _races) c.dispose();
    for (final c in _personalities) c.dispose();
  }

  void _addCharacter() {
    setState(() {
      _characters.add((
        name: TextEditingController(),
        role: TextEditingController(),
      ));
    });
  }

  void _addRealm() {
    setState(() => _realms.add(TextEditingController()));
  }

  void _addSect() =>
      setState(() => _sects.add(_SectInput(TextEditingController(), 'chinh')));
  void _addTechnique() =>
      setState(() => _techniques.add(TextEditingController()));

  // Mở trang quản lý nút thắt riêng, nhận kết quả trả về
  Future<void> _openPlotPoints() async {
    final result = await Navigator.of(context).push<List<PlotPointData>>(
      MaterialPageRoute(
        builder: (_) => PlotPointsScreen(
          initial: _plotPoints,
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
        _plotPoints
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _addClass() => setState(() => _classes.add(TextEditingController()));
  void _addRace() => setState(() => _races.add(TextEditingController()));
  void _addPersonality() =>
      setState(() => _personalities.add(TextEditingController()));

  bool get _isFantasy => _genre == 2;

  bool get _isXianxia => _genre == 1;

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _coverPath = picked.path);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên scenario')),
      );
      return;
    }
    setState(() => _submitting = true);

    final input = ScenarioInput(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      genreIds: [_genre],
      worldSetting: _worldSetting.text.trim(),
      protagonistRole: _protagonist.text.trim(),
      defaultMcName: _mcName.text.trim(),
      enemyDescription: _enemy.text.trim(),
      finalGoal: _goal.text.trim(),
      keyCharacters: _characters
          .where((c) => c.name.text.trim().isNotEmpty)
          .map((c) => KeyCharacter(
                name: c.name.text.trim(),
                role: c.role.text.trim(),
              ))
          .toList(),
      personalities: _personalities
          .map((p) => p.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      cultivationNote: _isXianxia ? _cultivationNote.text.trim() : '',
      mcSpiritRoot: _isXianxia ? _mcSpiritRoot.text.trim() : '',
      sects: _isXianxia
          ? _sects
              .where((s) => s.name.text.trim().isNotEmpty)
              .map((s) => Sect(name: s.name.text.trim(), faction: s.faction))
              .toList()
          : [],
      techniques: _isXianxia
          ? _techniques
              .map((t) => t.text.trim())
              .where((t) => t.isNotEmpty)
              .map((t) => Technique(name: t))
              .toList()
          : [],
      realms: _isXianxia
          ? _realms
              .where((r) => r.text.trim().isNotEmpty)
              .toList()
              .asMap()
              .entries
              .map((e) => Realm(name: e.value.text.trim(), tier: e.key + 1))
              .toList()
          : [],
      magicSystem: _isFantasy ? _magicSystem.text.trim() : '',
      classes: _isFantasy
          ? _classes.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
          : [],
      races: _isFantasy
          ? _races.map((r) => r.text.trim()).where((t) => t.isNotEmpty).toList()
          : [],
      plotPoints: _plotPoints
          .where((pp) => pp.title.trim().isNotEmpty)
          .map((pp) => PlotPoint(
                title: pp.title.trim(),
                description: pp.description.trim(),
                minChapters: pp.minChapters,
                choices: pp.choices
                    .map((c) => c.label.trim())
                    .where((t) => t.isNotEmpty)
                    .map((t) => PlotChoice(label: t))
                    .toList(),
              ))
          .toList(),
    );

    try {
      final newId = await ref.read(scenarioServiceProvider).create(input);
      // Nếu có chọn ảnh bìa -> upload cho scenario vừa tạo
      if (_coverPath != null) {
        await ref.read(scenarioServiceProvider).uploadCover(newId, _coverPath!);
      }
      await ref.read(scenarioListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo scenario thành công')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tạo thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo scenario mới')),
      body: ListView(
        
        padding: const EdgeInsets.all(16),
        children: [
          _label('Thông tin chung'),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tên scenario *'),
          ),

          const SizedBox(height: 12),
          // Khu chọn ảnh bìa
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                image: _coverPath != null
                    ? DecorationImage(
                        image: FileImage(File(_coverPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _coverPath == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40),
                          SizedBox(height: 8),
                          Text('Chọn ảnh bìa (tùy chọn)'),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Mô tả ngắn'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          _label('Thể loại'),
          Wrap(
            spacing: 8,
            children: [
              Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tiên hiệp'),
                selected: _genre == 1,
                onSelected: (_) => setState(() => _genre = 1),
              ),
              ChoiceChip(
                label: const Text('Fantasy'),
                selected: _genre == 2,
                onSelected: (_) => setState(() => _genre = 2),
              ),
            ],
          ),
            ],
          ),
          const SizedBox(height: 20),

          _label('Cấu hình thế giới'),
          TextField(
            controller: _worldSetting,
            decoration: const InputDecoration(labelText: 'Bối cảnh thế giới'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _protagonist,
            decoration:
                const InputDecoration(labelText: 'Thân phận nhân vật chính'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mcName,
            decoration: const InputDecoration(
              labelText: 'Tên mặc định nhân vật chính (tùy chọn)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _enemy,
            decoration: const InputDecoration(labelText: 'Kẻ thù'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goal,
            decoration:
                const InputDecoration(labelText: 'Mục đích cuối cùng'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Nhân vật quan trọng (động)
          Row(
            children: [
              _label('Nhân vật quan trọng'),
              const Spacer(),
              IconButton.filled(
                onPressed: _addCharacter,
                icon: const Icon(Icons.add),
                tooltip: 'Thêm nhân vật',
              ),
            ],
          ),
          ..._characters.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Card(
              color: theme.colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Nhân vật ${i + 1}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() {
                            c.name.dispose();
                            c.role.dispose();
                            _characters.removeAt(i);
                          }),
                        ),
                      ],
                    ),
                    TextField(
                      controller: c.name,
                      decoration: const InputDecoration(labelText: 'Tên'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: c.role,
                      decoration: const InputDecoration(
                        labelText: 'Thân phận (vd: sư phụ, phản diện)',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Tính cách nhân vật (cho người chơi chọn khi bắt đầu) - mọi thể loại
          Row(
            children: [
              const Expanded(
                child: Text('Tính cách nhân vật (cho người chơi chọn)'),
              ),
              IconButton.filled(
                onPressed: _addPersonality,
                icon: const Icon(Icons.add),
                tooltip: 'Thêm tính cách',
              ),
            ],
          ),
          ..._personalities.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: e.value,
                      decoration: InputDecoration(
                        labelText: 'Tính cách ${i + 1}',
                        hintText: 'vd: Chính trực, nhân hậu',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      e.value.dispose();
                      _personalities.removeAt(i);
                    }),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),

          // Nút thắt cốt truyện (mọi thể loại) - mở trang riêng
          _label('Nút thắt cốt truyện'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Các cột mốc quan trọng dẫn dắt câu chuyện. Quản lý ở trang riêng (có thể nhờ AI sinh).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openPlotPoints,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text('Quản lý nút thắt (${_plotPoints.length})'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Phần tiên hiệp: chỉ hiện khi chọn thể loại Tiên hiệp
          if (_isXianxia) ...[
            _label('Hệ thống tu luyện (Tiên hiệp)'),
            TextField(
              controller: _cultivationNote,
              decoration: const InputDecoration(
                labelText: 'Mô tả hệ thống tu luyện',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Các cảnh giới (từ thấp đến cao)')),
                IconButton.filled(
                  onPressed: _addRealm,
                  icon: const Icon(Icons.add),
                  tooltip: 'Thêm cảnh giới',
                ),
              ],
            ),
            ..._realms.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: 'Cảnh giới ${i + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        e.value.dispose();
                        _realms.removeAt(i);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Linh căn / thể chất nhân vật chính
            _label('Linh căn / thể chất nhân vật chính'),
            TextField(
              controller: _mcSpiritRoot,
              decoration: const InputDecoration(
                labelText: 'VD: Ngũ hành tạp linh căn, Thiên linh căn hệ Hỏa...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Tông môn (chính phái + tà phái)
            Row(
              children: [
                const Expanded(child: Text('Tông môn (chính phái / tà phái)')),
                IconButton.filled(
                  onPressed: _addSect,
                  icon: const Icon(Icons.add),
                  tooltip: 'Thêm tông môn',
                ),
              ],
            ),
            ..._sects.asMap().entries.map((e) {
              final i = e.key;
              final sect = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: sect.name,
                        decoration: InputDecoration(
                          labelText: 'Tên tông môn ${i + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: sect.faction,
                      items: const [
                        DropdownMenuItem(
                            value: 'chinh', child: Text('Chính phái')),
                        DropdownMenuItem(value: 'ta', child: Text('Tà phái')),
                      ],
                      onChanged: (v) =>
                          setState(() => sect.faction = v ?? 'chinh'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        sect.name.dispose();
                        _sects.removeAt(i);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Công pháp đặc trưng
            Row(
              children: [
                const Expanded(child: Text('Công pháp đặc trưng')),
                IconButton.filled(
                  onPressed: _addTechnique,
                  icon: const Icon(Icons.add),
                  tooltip: 'Thêm công pháp',
                ),
              ],
            ),
            ..._techniques.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: 'Công pháp ${i + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        e.value.dispose();
                        _techniques.removeAt(i);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          // Phần Fantasy: chỉ hiện khi chọn thể loại Fantasy
          if (_isFantasy) ...[
            _label('Thế giới Fantasy'),
            TextField(
              controller: _magicSystem,
              decoration: const InputDecoration(
                labelText: 'Hệ thống ma pháp',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Lớp nhân vật')),
                IconButton.filled(
                  onPressed: _addClass,
                  icon: const Icon(Icons.add),
                  tooltip: 'Thêm lớp',
                ),
              ],
            ),
            ..._classes.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(labelText: 'Lớp ${i + 1}'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        e.value.dispose();
                        _classes.removeAt(i);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Chủng tộc')),
                IconButton.filled(
                  onPressed: _addRace,
                  icon: const Icon(Icons.add),
                  tooltip: 'Thêm chủng tộc',
                ),
              ],
            ),
            ..._races.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(labelText: 'Chủng tộc ${i + 1}'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        e.value.dispose();
                        _races.removeAt(i);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          SizedBox(
            height: 50,
            child: _submitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Tạo scenario'),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
}
// Dữ liệu nhập cho một tông môn (tên + phe), dùng trong màn tạo scenario
class _SectInput {
  final TextEditingController name;
  String faction; // 'chinh' hoặc 'ta'
  _SectInput(this.name, this.faction);
}