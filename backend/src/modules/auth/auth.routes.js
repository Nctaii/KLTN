const express = require('express');
const ctrl = require('./auth.controller');
const auth = require('../../middleware/auth.middleware');

const router = express.Router();

// Email/password
router.post('/register', ctrl.register);
router.post('/verify-email', ctrl.verifyEmail);
router.post('/resend-otp', ctrl.resendOtp);
router.post('/login', ctrl.login);
router.post('/refresh', ctrl.refresh);
router.get('/me', auth, ctrl.me);
router.post('/logout', auth, ctrl.logout);
router.post('/forgot-password', ctrl.forgotPassword);
router.post('/reset-password', ctrl.resetPassword);

// Google OAuth
router.post('/google', ctrl.googleAuth);

// TOTP 2FA
router.post('/2fa/setup', auth, ctrl.setup2fa);         // bước 1: lấy QR code
router.post('/2fa/verify-setup', auth, ctrl.verifySetup2fa); // bước 2: xác nhận, bật 2FA
router.post('/2fa/verify', ctrl.verify2fa);              // hoàn thành login khi 2FA bật
router.post('/2fa/disable', auth, ctrl.disable2fa);     // tắt 2FA

module.exports = router;
