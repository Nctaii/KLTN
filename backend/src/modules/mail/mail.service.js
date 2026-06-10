// Gửi email qua Gmail SMTP bằng nodemailer
const nodemailer = require('nodemailer');
require('dotenv').config();

let transporter = null;
function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT || '587', 10),
      secure: false, // false cho port 587 (STARTTLS)
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }
  return transporter;
}

async function sendOtpEmail(toEmail, otp) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color:#3f51b5;">Xác minh email</h2>
      <p>Cảm ơn bạn đã đăng ký <b>Tiểu Thuyết Tương Tác</b>.</p>
      <p>Mã xác minh của bạn là:</p>
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color:#222;">${otp}</p>
      <p>Mã có hiệu lực trong ${process.env.OTP_TTL_MINUTES || 10} phút.</p>
      <p style="color:#888; font-size:13px;">Nếu bạn không thực hiện đăng ký này, hãy bỏ qua email.</p>
    </div>`;

  await getTransporter().sendMail({
    from,
    to: toEmail,
    subject: 'Mã xác minh tài khoản',
    text: `Mã xác minh của bạn là: ${otp} (hiệu lực ${process.env.OTP_TTL_MINUTES || 10} phút)`,
    html,
  });
}

async function verifyConnection() {
  try {
    await getTransporter().verify();
    return true;
  } catch (err) {
    console.warn('Cảnh báo: SMTP chưa sẵn sàng -', err.message);
    return false;
  }
}

module.exports = { sendOtpEmail, verifyConnection };
