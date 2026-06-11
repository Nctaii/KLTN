const asyncHandler = require('../../utils/asyncHandler');
const svc = require('./interaction.service');

exports.toggleLike = asyncHandler(async (req, res) => {
  const result = await svc.toggleLike(req.user.id, req.params.storyId);
  res.json(result);
});

exports.getLikeInfo = asyncHandler(async (req, res) => {
  const result = await svc.getLikeInfo(req.user.id, req.params.storyId);
  res.json(result);
});

exports.addComment = asyncHandler(async (req, res) => {
  const comment = await svc.addComment(req.user.id, req.params.storyId, req.body.content);
  res.status(201).json({ comment });
});

exports.listComments = asyncHandler(async (req, res) => {
  const comments = await svc.listComments(req.params.storyId);
  res.json({ comments });
});