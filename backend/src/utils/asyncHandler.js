// Bọc controller async để tự chuyển lỗi sang middleware xử lý lỗi
module.exports = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
