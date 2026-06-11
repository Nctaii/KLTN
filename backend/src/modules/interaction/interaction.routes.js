const express = require('express');
const ctrl = require('./interaction.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router({ mergeParams: true });

router.post('/like', auth, ctrl.toggleLike);
router.get('/like', auth, ctrl.getLikeInfo);
router.get('/comments', ctrl.listComments);
router.post('/comments', auth, ctrl.addComment);

module.exports = router;