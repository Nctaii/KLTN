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
