# Backend - Ứng dụng nhập vai tiểu thuyết tương tác

Backend Node.js + Express + PostgreSQL + JWT cho khóa luận tốt nghiệp.

## Công nghệ
- Express: web framework
- pg: driver PostgreSQL (SQL thuần)
- jsonwebtoken: JWT access + refresh token
- bcrypt: băm mật khẩu và refresh token
- @anthropic-ai/sdk: gọi Claude sinh chương truyện

## Cài đặt

```bash
npm install
cp .env.example .env   # rồi điền DATABASE_URL, JWT secrets, OPENAI_API_KEY
```

Tạo CSDL (chạy file schema đã có):

```bash
createdb interactive_novel
psql -d interactive_novel -f ../interactive_novel_schema.sql
```

## Chạy

```bash
npm run dev    # chế độ dev (nodemon)
npm start      # chế độ thường
```

Server mặc định: http://localhost:3000

## Cấu trúc thư mục

```
src/
├── config/db.js              kết nối PostgreSQL (pool + transaction)
├── middleware/
│   ├── auth.middleware.js     xác thực JWT
│   └── error.middleware.js    xử lý lỗi tập trung
├── utils/                     jwt, asyncHandler, ApiError
├── modules/
│   ├── auth/                  đăng ký, đăng nhập, refresh, me, logout
│   ├── scenario/              tạo & quản lý cấu hình thế giới
│   ├── play/                  lượt chơi: bắt đầu, sinh chương, chọn hướng
│   └── ai/                    gọi LLM sinh chương + lựa chọn
├── app.js                     ráp Express
└── server.js                  khởi động
```

## API chính

### Auth
- `POST /auth/register`  { email, username, password }
- `POST /auth/login`     { email, password }
- `POST /auth/refresh`   { refresh_token }
- `GET  /auth/me`        (cần Bearer token)
- `POST /auth/logout`    (cần Bearer token)

### Scenario
- `GET  /scenarios`             danh sách đã publish
- `GET  /scenarios/:id`         chi tiết cấu hình
- `POST /scenarios`             tạo mới (cần đăng nhập)
- `POST /scenarios/:id/publish` publish

### Play
- `POST /play/start`                  { story_id, mc_name? } → tạo session + AI sinh chương 1
- `POST /play/:sessionId/continue`    { option_id? , custom_direction? } → AI sinh chương kế tiếp
- `GET  /play/:sessionId`             đọc lại toàn bộ chương
