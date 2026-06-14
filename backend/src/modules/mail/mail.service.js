// Gửi email qua Brevo REST API (không dùng SMTP, hoạt động được trên Render free tier)
require('dotenv').config();

async function sendOtpEmail(toEmail, otp) {
  const ttl = process.env.OTP_TTL_MINUTES || 10;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color:#3f51b5;">Xác minh email</h2>
      <p>Cảm ơn bạn đã đăng ký <b>Tiểu Thuyết Tương Tác</b>.</p>
      <p>Mã xác minh của bạn là:</p>
      <p style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color:#222;">${otp}</p>
      <p>Mã có hiệu lực trong ${ttl} phút.</p>
      <p style="color:#888; font-size:13px;">Nếu bạn không thực hiện đăng ký này, hãy bỏ qua email.</p>
    </div>`;

  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sender: {
        name: process.env.BREVO_SENDER_NAME || 'Tiểu Thuyết Tương Tác',
        email: process.env.BREVO_SENDER_EMAIL,
      },
      to: [{ email: toEmail }],
      subject: 'Mã xác minh tài khoản',
      textContent: `Mã xác minh của bạn là: ${otp} (hiệu lực ${ttl} phút)`,
      htmlContent: html,
    }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(`Brevo API error ${res.status}: ${err.message || 'unknown'}`);
  }
}

async function verifyConnection() {
  if (!process.env.BREVO_API_KEY || !process.env.BREVO_SENDER_EMAIL) {
    console.warn('Cảnh báo: BREVO_API_KEY hoặc BREVO_SENDER_EMAIL chưa được cấu hình');
    return false;
  }
  return true;
}

module.exports = { sendOtpEmail, verifyConnection };
