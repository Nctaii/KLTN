const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./scenario.service');

exports.create = asyncHandler(async (req, res) => {
  const story = await svc.createScenario(req.user.id, req.body);
  res.status(201).json({ scenario: story });
});

exports.getOne = asyncHandler(async (req, res) => {
  const full = await svc.getScenarioFull(req.params.id);
  res.json({ scenario: full });
});

exports.list = asyncHandler(async (req, res) => {
  const items = await svc.listPublished();
  res.json({ scenarios: items });
});

exports.publish = asyncHandler(async (req, res) => {
  const story = await svc.publishScenario(req.params.id, req.user.id);
  res.json({ scenario: story });
});

// GET /scenarios/mine -> scenario của chính user
exports.listMine = asyncHandler(async (req, res) => {
  const items = await svc.listMyScenarios(req.user.id);
  res.json({ scenarios: items });
});

// POST /scenarios/:id/cover -> upload ảnh bìa
exports.uploadCover = asyncHandler(async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Thiếu file ảnh' });
  const coverUrl = `/uploads/${req.file.filename}`;
  const result = await svc.updateCover(req.user.id, req.params.id, coverUrl);
  res.json(result);
});

// DELETE /scenarios/:id -> xóa scenario của mình
exports.remove = asyncHandler(async (req, res) => {
  await svc.deleteScenario(req.user.id, req.params.id);
  res.json({ message: 'Đã xóa scenario' });
});
