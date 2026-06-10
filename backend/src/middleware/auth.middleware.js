// Middleware kiểm tra access token trong header Authorization
const { verifyAccessToken } = require('../utils/jwt');
const ApiError = require('../utils/ApiError');

module.exports = (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return next(new ApiError(401, 'Thiếu access token'));
  }
  try {
    const payload = verifyAccessToken(token);
    req.user = { id: payload.sub, role: payload.role }; // gắn thông tin user vào request
    next();
  } catch (err) {
    return next(new ApiError(401, 'Access token không hợp lệ hoặc đã hết hạn'));
  }
};
