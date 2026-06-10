# Flutter Auth — Kiểm tra backend KLTN

Ứng dụng Flutter tối giản chỉ gồm chức năng xác thực (đăng ký / đăng nhập / trang chính),
dùng **Riverpod** để quản lý trạng thái, kết nối tới backend Node.js của đề tài.

## Cấu trúc

```
lib/
├── core/api_config.dart                  địa chỉ backend (baseUrl)
├── features/auth/
│   ├── models/auth_user.dart             model người dùng
│   ├── data/
│   │   ├── token_storage.dart            lưu token an toàn (secure storage)
│   │   └── auth_service.dart             gọi API /auth (Dio)
│   ├── providers/auth_provider.dart      Riverpod: AuthNotifier giữ trạng thái
│   └── screens/
│       ├── login_screen.dart
│       ├── register_screen.dart
│       └── home_screen.dart              hiện thông tin user sau khi đăng nhập
└── main.dart                             ProviderScope + AuthGate điều hướng
```

## Các bước chạy

### 1. Tạo khung dự án Flutter (nếu chưa có)
Thư mục này chỉ chứa `lib/` và `pubspec.yaml`. Để chạy được trên máy, cần các
file nền tảng (android/, ios/...). Cách dễ nhất:

```bash
# Tạo dự án Flutter mới ở chỗ khác
flutter create my_auth_app
# Rồi copy đè thư mục lib/ và file pubspec.yaml từ gói này vào my_auth_app/
```

Hoặc nếu bạn đã có sẵn dự án Flutter, chỉ cần copy nội dung `lib/` và phần
dependencies trong `pubspec.yaml` vào.

### 2. Cài thư viện
```bash
flutter pub get
```

### 3. SINH CODE Riverpod (BẮT BUỘC)
Provider dùng code generation, cần sinh file `auth_provider.g.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Nếu thiếu bước này, app sẽ báo lỗi "auth_provider.g.dart not found".
Khi đang phát triển, có thể chạy chế độ tự động:
```bash
dart run build_runner watch -d
```

### 4. Chỉnh địa chỉ backend
Mở `lib/core/api_config.dart`, đặt `baseUrl` đúng môi trường:
- Android emulator:  `http://10.0.2.2:3000`   (mặc định)
- iOS simulator:     `http://localhost:3000`
- Điện thoại thật:   `http://<IP-LAN-máy-tính>:3000`

### 5. Bật backend, rồi chạy app
```bash
# (terminal 1) trong thư mục backend
npm run dev

# (terminal 2) trong thư mục Flutter
flutter run
```

## Cách kiểm tra
1. App mở ra màn hình Đăng nhập.
2. Bấm "Đăng ký", nhập email/username/mật khẩu mới → backend tạo user, app
   tự chuyển sang Trang chính hiển thị thông tin user.
3. Đăng xuất, đăng nhập lại bằng tài khoản vừa tạo.
4. Tắt app mở lại: nhờ token lưu trong secure storage + hàm build() của
   AuthNotifier, app tự đăng nhập lại nếu token còn hạn.

## Vai trò của Riverpod ở đây
- `AuthNotifier` (AsyncNotifier) giữ trạng thái đăng nhập kiểu `AsyncValue<AuthUser?>`.
- UI dùng `ref.watch(authNotifierProvider)` để phản ứng theo trạng thái
  (loading / data / error) mà không cần quản lý cờ thủ công.
- `AuthGate` đọc cùng provider đó để tự điều hướng giữa Login và Home.
