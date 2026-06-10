// Middleware xử lý lỗi tập trung: trả JSON thống nhất, kèm field nếu có
const ApiError = require('../utils/ApiError');

module.exports = (err, req, res, next) => {
  if (err instanceof ApiError) {
    const body = { error: err.message };
    if (err.field) body.field = err.field;
    return res.status(err.statusCode).json(body);
  }
  if (err.code === '23505') {
    return res.status(409).json({ error: 'Dữ liệu đã tồn tại (trùng lặp)' });
  }
  console.error('Lỗi không lường trước:', err);
  return res.status(500).json({ error: 'Lỗi máy chủ nội bộ' });
};