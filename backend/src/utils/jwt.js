// Tạo và xác thực JWT (access + refresh token)
const jwt = require('jsonwebtoken');
require('dotenv').config();

function signAccessToken(payload) {
  return jwt.sign(payload, process.env.JWT_ACCESS_SECRET, {
    expiresIn: process.env.ACCESS_TOKEN_TTL || '15m',
  });
}

function signRefreshToken(payload) {
  const days = parseInt(process.env.REFRESH_TOKEN_TTL_DAYS || '7', 10);
  return jwt.sign(payload, process.env.JWT_REFRESH_SECRET, {
    expiresIn: `${days}d`,
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, process.env.JWT_ACCESS_SECRET);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, process.env.JWT_REFRESH_SECRET);
}

// Token tạm thời 5 phút, dùng để hoàn thành bước 2FA sau khi verify password thành công
function signTempToken(payload) {
  return jwt.sign(
    { ...payload, purpose: '2fa_pending' },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: '5m' }
  );
}

function verifyTempToken(token) {
  const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
  if (payload.purpose !== '2fa_pending') throw new Error('Invalid token purpose');
  return payload;
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  signTempToken,
  verifyTempToken,
};
