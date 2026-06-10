const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./play.service');

// POST /play/start  { story_id, mc_name? }
exports.start = asyncHandler(async (req, res) => {
  const { story_id, mc_name } = req.body;
  const result = await svc.startPlay(req.user.id, story_id, mc_name);
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
