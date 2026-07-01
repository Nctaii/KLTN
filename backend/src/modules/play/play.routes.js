const express = require('express');
const ctrl = require('./play.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router();

// LƯU Ý thứ tự: route cụ thể phải đứng TRƯỚC /:sessionId
router.get('/', auth, ctrl.listMine);
router.get('/published', ctrl.listPublished);
router.get('/published/:sessionId', ctrl.getPublished);
router.post('/start', auth, ctrl.start);
router.delete('/by-story/:storyId', auth, ctrl.deleteByStory);
router.post('/:sessionId/continue', auth, ctrl.continue);
router.post('/:sessionId/rewind', auth, ctrl.rewind);
router.post('/:sessionId/rewind-combat', auth, ctrl.rewindCombat);
router.post('/:sessionId/publish', auth, ctrl.publish);
router.get('/:sessionId', auth, ctrl.get);

module.exports = router;