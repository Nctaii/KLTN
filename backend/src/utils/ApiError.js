// Lớp lỗi có kèm mã HTTP và (tùy chọn) tên trường gây lỗi
class ApiError extends Error {
  constructor(statusCode, message, field = null) {
    super(message);
    this.statusCode = statusCode;
    this.field = field; // 'email' | 'username' | ... để client hiển thị đúng ô
  }
}
module.exports = ApiError;