import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/api_config.dart';
import '../models/scenario.dart';
import '../providers/scenario_provider.dart';

class EditScenarioScreen extends ConsumerStatefulWidget {
  final ScenarioSummary scenario;
  const EditScenarioScreen({super.key, required this.scenario});
  @override
  ConsumerState<EditScenarioScreen> createState() =>
      _EditScenarioScreenState();
}

class _EditScenarioScreenState extends ConsumerState<EditScenarioScreen> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  String? _newCoverPath; // ảnh mới chọn (chưa upload)
  bool _saving = false;
  bool _picking = false; // đang chọn ảnh, tránh gọi chồng

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.scenario.title);
    _desc = TextEditingController(text: widget.scenario.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_picking) return; // đang chọn rồi thì bỏ qua
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e')),
        );
      }
    } finally {
      _picking = false; // mở khóa dù thành công hay lỗi
    }
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
      await svc.updateInfo(
        widget.scenario.id,
        title: _title.text.trim(),
        description: _desc.text.trim(),
      );
      // Nếu chọn ảnh mới -> upload
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oldCover = widget.scenario.coverUrl;
    final fullOldCover = (oldCover != null && oldCover.isNotEmpty)
        ? ApiConfig.imageUrl(oldCover)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sửa scenario')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ảnh bìa (mới chọn > ảnh cũ > placeholder)
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
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40),
                          SizedBox(height: 8),
                          Text('Chọn ảnh bìa'),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tên scenario'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Mô tả'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _save,
                    child: const Text('Lưu thay đổi'),
                  ),
          ),
        ],
      ),
    );
  }
}