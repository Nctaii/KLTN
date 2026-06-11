const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./user.service');

exports.getMe = asyncHandler(async (req, res) => {
  const profile = await svc.getProfile(req.user.id);
  res.json({ profile });
});

exports.updateMe = asyncHandler(async (req, res) => {
  const profile = await svc.updateProfile(req.user.id, {
    displayName: req.body.display_name,
  });
  res.json({ profile });
});

exports.uploadAvatar = asyncHandler(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Thiếu file ảnh' });
  }
  const avatarUrl = `/uploads/${req.file.filename}`;
  const profile = await svc.updateAvatar(req.user.id, avatarUrl);
  res.json({ profile });
});