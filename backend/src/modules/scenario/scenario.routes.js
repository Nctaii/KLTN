const express = require('express');
const ctrl = require('./scenario.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router();

router.get('/', ctrl.list);               // duyệt scenario đã publish (công khai)
router.get('/:id', ctrl.getOne);          // xem chi tiết
router.post('/', auth, ctrl.create);      // tạo (cần đăng nhập)
router.post('/:id/publish', auth, ctrl.publish);

module.exports = router;
