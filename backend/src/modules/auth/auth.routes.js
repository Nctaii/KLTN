const express = require('express');
const ctrl = require('./auth.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router();

router.post('/register', ctrl.register);
router.post('/verify-email', ctrl.verifyEmail);   // xác minh OTP
router.post('/resend-otp', ctrl.resendOtp);        // gửi lại OTP
router.post('/login', ctrl.login);
router.post('/refresh', ctrl.refresh);
router.get('/me', auth, ctrl.me);
router.post('/logout', auth, ctrl.logout);

module.exports = router;
