import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Đổ dữ liệu hiện tại vào ô (chạy một lần)
  void _initFields(String? currentName) {
    if (!_initialized) {
      _nameCtrl.text = currentName ?? '';
      _initialized = true;
    }
  }

  // Chọn ảnh từ thư viện và upload
  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // thu nhỏ để file nhẹ
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(profileServiceProvider).uploadAvatar(picked.path);
      // Làm mới thông tin user trên toàn app
      ref.invalidate(authNotifierProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Lưu tên hiển thị
  Future<void> _saveName() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(profileServiceProvider)
          .updateProfile(displayName: _nameCtrl.text.trim());
      ref.invalidate(authNotifierProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin')),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    _initFields(user?.displayName ?? user?.username);

    // Dựng URL avatar đầy đủ (server trả đường dẫn tương đối)
    final avatarUrl = user?.avatarUrl;
    final fullAvatarUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? '${ApiConfig.baseUrl}$avatarUrl'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          // Avatar + nút đổi ảnh
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundImage:
                      fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                  child: fullAvatarUrl == null
                      ? const Icon(Icons.person, size: 56)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 18),
                      onPressed: _loading ? null : _pickAndUpload,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên hiển thị'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveName,
                    child: const Text('Lưu thay đổi'),
                  ),
          ),
        ],
      ),
    );
  }
}