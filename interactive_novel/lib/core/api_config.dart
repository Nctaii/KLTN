class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:3000';
  // static const String baseUrl = 'https://interactive-novel-api-9flb.onrender.com';
  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path; // URL Cloudinary đầy đủ
    return '$baseUrl$path'; // ảnh cũ kiểu /uploads/...
  }
}