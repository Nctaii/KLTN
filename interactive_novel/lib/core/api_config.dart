// Cấu hình địa chỉ backend.
// LƯU Ý quan trọng về baseUrl tùy môi trường chạy:
//  - Android emulator:    http://10.0.2.2:3000  (10.0.2.2 = localhost của máy tính)
//  - iOS simulator:       http://localhost:3000
//  - Điện thoại thật:     http://<IP-máy-tính-trong-LAN>:3000  (vd 192.168.1.10:3000)
//  - Flutter web/desktop: http://localhost:3000
class ApiConfig {
  // static const String baseUrl = 'http://10.0.2.2:3000';
  static const String baseUrl = 'https://interactive-novel-api-9flb.onrender.com';
}
