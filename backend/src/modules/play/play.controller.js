const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./play.service');

// POST /play/start  { story_id, mc_name?, personality? }
exports.start = asyncHandler(async (req, res) => {
  const { story_id, mc_name, personality } = req.body;
  const result = await svc.startPlay(req.user.id, story_id, mc_name, personality);
  res.status(201).json(result);
});

// POST /play/:sessionId/continue  { option_id? , custom_direction? }
exports.continue = asyncHandler(async (req, res) => {
  const result = await svc.continuePlay(
    req.user.id,
    req.params.sessionId,
    req.body
  );
  res.status(201).json(result);
});

// GET /play/:sessionId
exports.get = asyncHandler(async (req, res) => {
  const result = await svc.getPlaythrough(req.user.id, req.params.sessionId);
  res.json(result);
});

// POST /play/:sessionId/rewind  { chapter_id }  -> quay lại nút thắt
exports.rewind = asyncHandler(async (req, res) => {
  const result = await svc.rewindToPlotPoint(
    req.user.id,
    req.params.sessionId,
    req.body.chapter_id
  );
  res.json(result);
});

// POST /play/:sessionId/rewind-combat  { chapter_id }  -> quay lại đầu trận combat
exports.rewindCombat = asyncHandler(async (req, res) => {
  const result = await svc.rewindToCombat(
    req.user.id,
    req.params.sessionId,
    req.body.chapter_id
  );
  res.json(result);
});

// POST /play/:sessionId/publish  { publish: true|false, share_title? } -> xuất bản / cập nhật / gỡ
exports.publish = asyncHandler(async (req, res) => {
  const result = await svc.setPublish(
    req.user.id,
    req.params.sessionId,
    req.body.publish !== false, // mặc định true
    req.body.share_title
  );
  res.json(result);
});

// GET /play/published -> danh sách lượt chơi công khai (không cần đăng nhập)
exports.listPublished = asyncHandler(async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
  const offset = parseInt(req.query.offset, 10) || 0;
  const sessions = await svc.listPublished({ limit, offset });
  res.json({ sessions });
});

// GET /play/published/:sessionId -> xem chi tiết lượt chơi công khai (chỉ đọc)
exports.getPublished = asyncHandler(async (req, res) => {
  const result = await svc.getPublishedPlaythrough(req.params.sessionId);
  res.json(result);
});

// GET /play  -> danh sách lượt chơi của user
exports.listMine = asyncHandler(async (req, res) => {
  const sessions = await svc.listMySessions(req.user.id);
  res.json({ sessions });
});

// DELETE /play/by-story/:storyId  -> xóa các lượt chơi của user cho scenario này
exports.deleteByStory = asyncHandler(async (req, res) => {
  await svc.deleteSessionsByStory(req.user.id, req.params.storyId);
  res.json({ message: 'Đã xóa lượt chơi cũ' });
});