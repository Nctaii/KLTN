import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scenario.dart';
import '../providers/scenario_provider.dart';
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

  final _magicSystem = TextEditingController();
  final List<TextEditingController> _classes = [];
  final List<TextEditingController> _races = [];

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
    super.dispose();
    _magicSystem.dispose();
    for (final c in _classes) c.dispose();
    for (final c in _races) c.dispose();
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

  void _addClass() => setState(() => _classes.add(TextEditingController()));
  void _addRace() => setState(() => _races.add(TextEditingController()));

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
      cultivationNote: _isXianxia ? _cultivationNote.text.trim() : '',
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