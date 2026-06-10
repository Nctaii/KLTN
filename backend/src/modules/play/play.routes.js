const express = require('express');
const ctrl = require('./play.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router();

// LƯU Ý thứ tự: route cụ thể phải đứng TRƯỚC /:sessionId
router.get('/', auth, ctrl.listMine);
router.post('/start', auth, ctrl.start);
router.delete('/by-story/:storyId', auth, ctrl.deleteByStory);
router.post('/:sessionId/continue', auth, ctrl.continue);
router.get('/:sessionId', auth, ctrl.get);

module.exports = router;