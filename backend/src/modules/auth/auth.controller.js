// Controller: nhận request, gọi service, trả response
const asyncHandler = require('../../utils/asyncHandler');
const authService = require('./auth.service');

exports.register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.body);
  // 201: đã tạo user, đã gửi OTP, CHƯA cấp token
  res.status(201).json({
    user: result.user,
    message: result.message,
    requireVerification: result.requireVerification,
  });
});

exports.verifyEmail = asyncHandler(async (req, res) => {
  const result = await authService.verifyEmail(req.body);
  res.json({
    user: result.user,
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
});

exports.resendOtp = asyncHandler(async (req, res) => {
  const result = await authService.resendOtp(req.body);
  res.json(result);
});

exports.login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body);
  res.json({
    user: result.user,
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
});

exports.refresh = asyncHandler(async (req, res) => {
  const result = await authService.refresh(req.body.refresh_token);
  res.json({
    user: result.user,
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
});

exports.me = asyncHandler(async (req, res) => {
  const user = await authService.getMe(req.user.id);
  res.json({ user });
});

exports.logout = asyncHandler(async (req, res) => {
  await authService.logout(req.user.id);
  res.json({ message: 'Đã đăng xuất' });
});

exports.forgotPassword = asyncHandler(async (req, res) => {
  const result = await authService.forgotPassword(req.body);
  res.json(result);
});

exports.resetPassword = asyncHandler(async (req, res) => {
  const result = await authService.resetPassword(req.body);
  res.json(result);
});
