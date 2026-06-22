const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./scenario.service');
const aiSvc = require('../ai/ai.service');
const { uploadToCloudinary } = require('../../config/cloudinary');

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
  // Đẩy buffer lên Cloudinary, nhận URL https đầy đủ
  const coverUrl = await uploadToCloudinary(req.file.buffer, 'covers');
  const result = await svc.updateCover(req.user.id, req.params.id, coverUrl);
  res.json(result);
});

// DELETE /scenarios/:id -> xóa scenario của mình
exports.remove = asyncHandler(async (req, res) => {
  await svc.deleteScenario(req.user.id, req.params.id);
  res.json({ message: 'Đã xóa scenario' });
});

// PATCH /scenarios/:id -> sửa tên, mô tả
exports.update = asyncHandler(async (req, res) => {
  const result = await svc.updateScenarioInfo(req.user.id, req.params.id, {
    title: req.body.title,
    description: req.body.description,
  });
  res.json({ scenario: result });
});

// PUT /scenarios/:id/full -> cập nhật toàn bộ cấu hình scenario (đồng bộ)
exports.updateFull = asyncHandler(async (req, res) => {
  const result = await svc.updateScenarioFull(req.user.id, req.params.id, req.body);
  res.json({ scenario: result });
});

// POST /scenarios/suggest-plot-choices -> AI gợi ý lựa chọn cho một nút thắt
// Body: { plot_title, plot_description, world } (world: bối cảnh đang nhập, tùy chọn)
// POST /scenarios/suggest-plot-points -> AI sinh cả bộ nút thắt
exports.suggestPlotPoints = asyncHandler(async (req, res) => {
  const { count, world, xh, fnt, genre_ids, title } = req.body;
  const tempScenario = {
    title: title || 'Kịch bản',
    genres: (genre_ids || []).map((id) => ({ id })),
    world: world || null,
    xh: xh || null,
    fnt: fnt || null,
    key_characters: [],
  };
  const plotPoints = await aiSvc.suggestPlotPoints({
    scenario: tempScenario,
    count: count || 3,
  });
  res.json({ plot_points: plotPoints });
});

exports.suggestPlotChoices = asyncHandler(async (req, res) => {
  const { plot_title, plot_description, world, xh, fnt, genre_ids } = req.body;
  if (!plot_title) return res.status(400).json({ error: 'Thiếu tiêu đề nút thắt' });
  // Dựng một object scenario tạm từ dữ liệu tác giả đang nhập để AI có bối cảnh
  const tempScenario = {
    title: req.body.title || 'Kịch bản',
    genres: (genre_ids || []).map((id) => ({ id })),
    world: world || null,
    xh: xh || null,
    fnt: fnt || null,
    key_characters: [],
  };
  const choices = await aiSvc.suggestPlotChoices({
    scenario: tempScenario,
    plotTitle: plot_title,
    plotDescription: plot_description,
  });
  res.json({ choices });
});