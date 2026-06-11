const express = require('express');
const ctrl = require('./user.controller');
const auth = require('../../middleware/auth.middleware');
const upload = require('./upload.config');

const router = express.Router();

router.get('/me', auth, ctrl.getMe);
router.patch('/me', auth, ctrl.updateMe);
router.post('/me/avatar', auth, upload.single('avatar'), ctrl.uploadAvatar);

module.exports = router;