const asyncHandler = require('../../utils/asyncHandler');
const authService = require('./auth.service');

exports.register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.body);
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
  if (result.requires2FA) {
    return res.json({
      user: result.user,
      requires_2fa: true,
      temp_token: result.tempToken,
    });
  }
  res.json({
    user: result.user,
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
});

exports.googleAuth = asyncHandler(async (req, res) => {
  const result = await authService.loginWithGoogle(req.body);
  if (result.requires2FA) {
    return res.json({
      user: result.user,
      requires_2fa: true,
      temp_token: result.tempToken,
    });
  }
  res.json({
    user: result.user,
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
});

exports.setup2fa = asyncHandler(async (req, res) => {
  const result = await authService.setup2fa(req.user.id);
  res.json(result);
});

exports.verifySetup2fa = asyncHandler(async (req, res) => {
  const result = await authService.verifySetup2fa(req.user.id, req.body.code);
  res.json(result);
});

exports.verify2fa = asyncHandler(async (req, res) => {
  const result = await authService.verify2fa(req.body);
  res.json({
    user: result.user,
    access_token: result.accessToken,
    refresh_token: result.refreshToken,
  });
});

exports.disable2fa = asyncHandler(async (req, res) => {
  const result = await authService.disable2fa(req.user.id, req.body.code);
  res.json(result);
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
