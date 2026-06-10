const express = require('express');
const ctrl = require('./play.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router();

// LƯU Ý thứ tự: route cụ thể (/ , /start) phải đứng TRƯỚC /:sessionId
// nếu không /:sessionId sẽ "nuốt" mất các route khác.
router.get('/', auth, ctrl.listMine);
router.post('/start', auth, ctrl.start);
router.post('/:sessionId/continue', auth, ctrl.continue);
router.get('/:sessionId', auth, ctrl.get);

module.exports = router;