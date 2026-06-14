const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const { authenticator } = require('otplib');
const { query, withTransaction } = require('../../config/db');
const {
  signAccessToken,
  signRefreshToken,
  signTempToken,
  verifyTempToken,
} = require('../../utils/jwt');
const ApiError = require('../../utils/ApiError');
const mailService = require('../mail/mail.service');

authenticator.options = { window: 1 }; // cho phép lệch 1 chu kỳ 30s (đồng hồ không đồng bộ)

const REQUIRE_EMAIL_VERIFICATION =
  process.env.REQUIRE_EMAIL_VERIFICATION !== 'false';
const MAX_OTP_ATTEMPTS = 5;

let _googleClient = null;
function getGoogleClient() {
  if (!_googleClient) _googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
  return _googleClient;
}

function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    username: row.username,
    role: row.role,
    is_verified: row.is_verified,
    totp_enabled: row.totp_enabled ?? false,
  };
}

async function issueTokens(user) {
  const payload = { sub: user.id, role: user.role };
  const accessToken = signAccessToken(payload);
  const refreshToken = signRefreshToken(payload);
  const tokenHash = await bcrypt.hash(refreshToken, 10);
  const days = parseInt(process.env.REFRESH_TOKEN_TTL_DAYS || '7', 10);
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, now() + ($3 || ' days')::interval)`,
    [user.id, tokenHash, days]
  );
  return { accessToken, refreshToken };
}

async function createAndSendOtp(userId, email, purpose = 'verify_email') {
  const otp = ('' + crypto.randomInt(0, 1000000)).padStart(6, '0');
  const otpHash = await bcrypt.hash(otp, 10);
  const ttl = parseInt(process.env.OTP_TTL_MINUTES || '10', 10);
  await query(
    `UPDATE email_otps SET consumed = TRUE
     WHERE user_id = $1 AND purpose = $2 AND consumed = FALSE`,
    [userId, purpose]
  );
  await query(
    `INSERT INTO email_otps (user_id, otp_hash, purpose, expires_at)
     VALUES ($1, $2, $3, now() + ($4 || ' minutes')::interval)`,
    [userId, otpHash, purpose, ttl]
  );
  await mailService.sendOtpEmail(email, otp);
}

// ─── Đăng ký ────────────────────────────────────────────────────────────────

async function register({ email, username, password }) {
  console.log('>>> REQUIRE_EMAIL_VERIFICATION =', REQUIRE_EMAIL_VERIFICATION);
  if (!email || !username || !password) {
    throw new ApiError(400, 'Thiếu email, username hoặc password');
  }
  if (password.length < 6) {
    throw new ApiError(400, 'Mật khẩu phải từ 6 ký tự trở lên');
  }
  const passwordHash = await bcrypt.hash(password, 10);

  const { rows: dupName } = await query(
    `SELECT id FROM users WHERE username = $1 AND email <> $2`,
    [username, email]
  );
  if (dupName[0]) {
    throw new ApiError(409, 'Tên đăng nhập đã được sử dụng', 'username');
  }

  const { rows: existing } = await query(
    `SELECT id, is_verified FROM users WHERE email = $1`,
    [email]
  );

  let user;
  if (existing[0]) {
    if (existing[0].is_verified) {
      throw new ApiError(409, 'Email này đã được đăng ký và xác minh', 'email');
    }
    const { rows } = await query(
      `UPDATE users SET username = $1, password_hash = $2, updated_at = now()
       WHERE id = $3 RETURNING id, email, username, role, is_verified, totp_enabled`,
      [username, passwordHash, existing[0].id]
    );
    user = rows[0];
    await query(
      `UPDATE user_profiles SET display_name = $1 WHERE user_id = $2`,
      [username, user.id]
    );
  } else {
    user = await withTransaction(async (client) => {
      const { rows } = await client.query(
        `INSERT INTO users (email, username, password_hash, is_verified)
         VALUES ($1, $2, $3, $4) RETURNING id, email, username, role, is_verified, totp_enabled`,
        [email, username, passwordHash, !REQUIRE_EMAIL_VERIFICATION]
      );
      const u = rows[0];
      await client.query(
        `INSERT INTO user_profiles (user_id, display_name) VALUES ($1, $2)`,
        [u.id, username]
      );
      return u;
    });
  }

  if (REQUIRE_EMAIL_VERIFICATION) {
    await createAndSendOtp(user.id, user.email);
    return {
      user: publicUser(user),
      message: 'Đã gửi mã xác minh tới email. Vui lòng kiểm tra hộp thư.',
      requireVerification: true,
    };
  }
  return {
    user: publicUser(user),
    message: 'Đăng ký thành công.',
    requireVerification: false,
  };
}

// ─── Xác minh OTP ───────────────────────────────────────────────────────────

async function verifyEmail({ email, otp }) {
  if (!email || !otp) throw new ApiError(400, 'Thiếu email hoặc mã OTP');

  const { rows: urows } = await query(
    `SELECT id, email, username, role, is_verified, totp_enabled FROM users WHERE email = $1`,
    [email]
  );
  const user = urows[0];
  if (!user) throw new ApiError(404, 'Không tìm thấy tài khoản');
  if (user.is_verified) {
    throw new ApiError(400, 'Tài khoản đã được xác minh trước đó');
  }

  const { rows: orows } = await query(
    `SELECT * FROM email_otps
     WHERE user_id = $1 AND purpose = 'verify_email' AND consumed = FALSE
       AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1`,
    [user.id]
  );
  const record = orows[0];
  if (!record) {
    throw new ApiError(400, 'Mã xác minh đã hết hạn. Vui lòng yêu cầu mã mới.');
  }
  if (record.attempts >= MAX_OTP_ATTEMPTS) {
    throw new ApiError(429, 'Nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới.');
  }

  const ok = await bcrypt.compare(otp, record.otp_hash);
  if (!ok) {
    await query(`UPDATE email_otps SET attempts = attempts + 1 WHERE id = $1`, [record.id]);
    throw new ApiError(400, 'Mã xác minh không đúng');
  }

  await query(`UPDATE email_otps SET consumed = TRUE WHERE id = $1`, [record.id]);
  await query(`UPDATE users SET is_verified = TRUE WHERE id = $1`, [user.id]);

  user.is_verified = true;
  const tokens = await issueTokens(user);
  return { user: publicUser(user), ...tokens };
}

async function resendOtp({ email }) {
  if (!email) throw new ApiError(400, 'Thiếu email');
  const { rows } = await query(
    `SELECT id, email, is_verified FROM users WHERE email = $1`,
    [email]
  );
  const user = rows[0];
  if (!user) throw new ApiError(404, 'Không tìm thấy tài khoản');
  if (user.is_verified) throw new ApiError(400, 'Tài khoản đã được xác minh');
  await createAndSendOtp(user.id, user.email);
  return { message: 'Đã gửi lại mã xác minh.' };
}

// ─── Đăng nhập ──────────────────────────────────────────────────────────────

async function login({ email, password }) {
  const { rows } = await query(
    `SELECT id, email, username, password_hash, role, is_active, is_verified, totp_enabled
     FROM users WHERE email = $1`,
    [email]
  );
  const user = rows[0];
  if (!user || !user.is_active) {
    throw new ApiError(401, 'Email hoặc mật khẩu không đúng');
  }
  if (!user.password_hash) {
    throw new ApiError(401, 'Tài khoản này đăng nhập bằng Google');
  }
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    throw new ApiError(401, 'Email hoặc mật khẩu không đúng');
  }
  if (!user.is_verified) {
    throw new ApiError(403, 'Tài khoản chưa xác minh email. Vui lòng kiểm tra hộp thư.');
  }

  if (user.totp_enabled) {
    const tempToken = signTempToken({ sub: user.id, role: user.role });
    return { user: publicUser(user), requires2FA: true, tempToken };
  }

  const tokens = await issueTokens(user);
  return { user: publicUser(user), ...tokens };
}

// ─── Google OAuth ────────────────────────────────────────────────────────────

async function loginWithGoogle({ idToken }) {
  if (!idToken) throw new ApiError(400, 'Thiếu idToken');

  let googlePayload;
  try {
    const ticket = await getGoogleClient().verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    googlePayload = ticket.getPayload();
  } catch {
    throw new ApiError(401, 'Google token không hợp lệ');
  }

  const { sub: googleId, email, name, picture } = googlePayload;

  // Tìm theo google_id trước, sau đó theo email
  const { rows: byGoogle } = await query(
    `SELECT id, email, username, role, is_verified, totp_enabled FROM users WHERE google_id = $1`,
    [googleId]
  );

  let user;
  if (byGoogle[0]) {
    user = byGoogle[0];
  } else {
    const { rows: byEmail } = await query(
      `SELECT id, email, username, role, is_verified, totp_enabled FROM users WHERE email = $1`,
      [email]
    );

    if (byEmail[0]) {
      // Liên kết google_id với tài khoản email/password đã có
      await query(
        `UPDATE users SET google_id = $1, is_verified = TRUE WHERE id = $2`,
        [googleId, byEmail[0].id]
      );
      user = { ...byEmail[0], is_verified: true };
    } else {
      // Tạo tài khoản mới từ Google
      let username = (name || email.split('@')[0])
        .replace(/\s+/g, '_')
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, '');
      const { rows: dupName } = await query(
        `SELECT id FROM users WHERE username = $1`,
        [username]
      );
      if (dupName[0]) username = `${username}_${Date.now()}`;

      user = await withTransaction(async (client) => {
        const { rows } = await client.query(
          `INSERT INTO users (email, username, google_id, is_verified, totp_enabled)
           VALUES ($1, $2, $3, TRUE, FALSE)
           RETURNING id, email, username, role, is_verified, totp_enabled`,
          [email, username, googleId]
        );
        const u = rows[0];
        await client.query(
          `INSERT INTO user_profiles (user_id, display_name, avatar_url) VALUES ($1, $2, $3)`,
          [u.id, name || username, picture || null]
        );
        return u;
      });
    }
  }

  if (user.totp_enabled) {
    const tempToken = signTempToken({ sub: user.id, role: user.role });
    return { user: publicUser(user), requires2FA: true, tempToken };
  }

  const tokens = await issueTokens(user);
  return { user: publicUser(user), ...tokens };
}

// ─── TOTP 2FA ────────────────────────────────────────────────────────────────

async function setup2fa(userId) {
  const { rows } = await query(
    `SELECT email, totp_enabled FROM users WHERE id = $1`,
    [userId]
  );
  const user = rows[0];
  if (!user) throw new ApiError(404, 'Không tìm thấy người dùng');
  if (user.totp_enabled) throw new ApiError(400, '2FA đã được bật');

  const secret = authenticator.generateSecret();
  const otpauthUrl = authenticator.keyuri(
    user.email,
    process.env.APP_NAME || 'Tiểu Thuyết Tương Tác',
    secret
  );

  // Lưu secret tạm (chưa enabled), user phải verify mã trước khi bật chính thức
  await query(`UPDATE users SET totp_secret = $1 WHERE id = $2`, [secret, userId]);
  return { otpauthUrl, secret };
}

async function verifySetup2fa(userId, code) {
  if (!code) throw new ApiError(400, 'Thiếu mã xác thực');
  const { rows } = await query(
    `SELECT totp_secret, totp_enabled FROM users WHERE id = $1`,
    [userId]
  );
  const user = rows[0];
  if (!user) throw new ApiError(404, 'Không tìm thấy người dùng');
  if (user.totp_enabled) throw new ApiError(400, '2FA đã được bật');
  if (!user.totp_secret) throw new ApiError(400, 'Chưa khởi tạo 2FA, hãy gọi /auth/2fa/setup trước');

  const isValid = authenticator.verify({ token: code, secret: user.totp_secret });
  if (!isValid) throw new ApiError(400, 'Mã xác thực không đúng');

  await query(`UPDATE users SET totp_enabled = TRUE WHERE id = $1`, [userId]);
  return { message: 'Bật 2FA thành công' };
}

async function verify2fa({ tempToken, code }) {
  if (!tempToken || !code) throw new ApiError(400, 'Thiếu tempToken hoặc code');

  let payload;
  try {
    payload = verifyTempToken(tempToken);
  } catch {
    throw new ApiError(401, 'Token không hợp lệ hoặc đã hết hạn (5 phút)');
  }

  const { rows } = await query(
    `SELECT id, email, username, role, is_verified, totp_enabled, totp_secret
     FROM users WHERE id = $1`,
    [payload.sub]
  );
  const user = rows[0];
  if (!user || !user.totp_enabled || !user.totp_secret) {
    throw new ApiError(400, '2FA chưa được bật trên tài khoản này');
  }

  const isValid = authenticator.verify({ token: code, secret: user.totp_secret });
  if (!isValid) throw new ApiError(400, 'Mã xác thực không đúng');

  const tokens = await issueTokens(user);
  return { user: publicUser(user), ...tokens };
}

async function disable2fa(userId, code) {
  if (!code) throw new ApiError(400, 'Thiếu mã xác thực');
  const { rows } = await query(
    `SELECT totp_secret, totp_enabled FROM users WHERE id = $1`,
    [userId]
  );
  const user = rows[0];
  if (!user) throw new ApiError(404, 'Không tìm thấy người dùng');
  if (!user.totp_enabled) throw new ApiError(400, '2FA chưa được bật');

  const isValid = authenticator.verify({ token: code, secret: user.totp_secret });
  if (!isValid) throw new ApiError(400, 'Mã xác thực không đúng');

  await query(
    `UPDATE users SET totp_enabled = FALSE, totp_secret = NULL WHERE id = $1`,
    [userId]
  );
  return { message: 'Tắt 2FA thành công' };
}

// ─── Token & Account ─────────────────────────────────────────────────────────

async function refresh(refreshToken) {
  if (!refreshToken) throw new ApiError(400, 'Thiếu refresh token');
  let payload;
  try {
    const { verifyRefreshToken } = require('../../utils/jwt');
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw new ApiError(401, 'Refresh token không hợp lệ');
  }
  const { rows } = await query(
    `SELECT id, token_hash FROM refresh_tokens
     WHERE user_id = $1 AND revoked = FALSE AND expires_at > now()`,
    [payload.sub]
  );
  let matched = null;
  for (const r of rows) {
    if (await bcrypt.compare(refreshToken, r.token_hash)) {
      matched = r;
      break;
    }
  }
  if (!matched) throw new ApiError(401, 'Phiên đăng nhập đã hết hạn');

  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE id = $1`, [matched.id]);
  const { rows: urows } = await query(
    `SELECT id, email, username, role, is_verified, totp_enabled FROM users WHERE id = $1`,
    [payload.sub]
  );
  const tokens = await issueTokens(urows[0]);
  return { user: publicUser(urows[0]), ...tokens };
}

async function getMe(userId) {
  const { rows } = await query(
    `SELECT u.id, u.email, u.username, u.role, u.is_verified, u.totp_enabled,
            p.display_name, p.avatar_url
     FROM users u LEFT JOIN user_profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );
  if (!rows[0]) throw new ApiError(404, 'Không tìm thấy người dùng');
  return rows[0];
}

async function logout(userId) {
  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1`, [userId]);
}

async function forgotPassword({ email }) {
  if (!email) throw new ApiError(400, 'Thiếu email');
  const { rows } = await query(
    `SELECT id, is_verified FROM users WHERE email = $1`,
    [email]
  );
  const user = rows[0];
  if (user && user.is_verified) {
    await createAndSendOtp(user.id, email, 'reset_password');
  }
  return { message: 'Nếu email tồn tại, mã đặt lại mật khẩu đã được gửi.' };
}

async function resetPassword({ email, otp, newPassword }) {
  if (!email || !otp || !newPassword) {
    throw new ApiError(400, 'Thiếu email, mã OTP hoặc mật khẩu mới');
  }
  if (newPassword.length < 6) {
    throw new ApiError(400, 'Mật khẩu phải từ 6 ký tự trở lên');
  }
  const { rows: urows } = await query(`SELECT id FROM users WHERE email = $1`, [email]);
  const user = urows[0];
  if (!user) throw new ApiError(400, 'Mã không hợp lệ hoặc đã hết hạn');

  const { rows: orows } = await query(
    `SELECT * FROM email_otps
     WHERE user_id = $1 AND purpose = 'reset_password' AND consumed = FALSE
       AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1`,
    [user.id]
  );
  const record = orows[0];
  if (!record) {
    throw new ApiError(400, 'Mã đặt lại đã hết hạn. Vui lòng yêu cầu mã mới.');
  }
  if (record.attempts >= MAX_OTP_ATTEMPTS) {
    throw new ApiError(429, 'Nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới.');
  }
  const ok = await bcrypt.compare(otp, record.otp_hash);
  if (!ok) {
    await query(`UPDATE email_otps SET attempts = attempts + 1 WHERE id = $1`, [record.id]);
    throw new ApiError(400, 'Mã đặt lại không đúng');
  }

  const passwordHash = await bcrypt.hash(newPassword, 10);
  await query(`UPDATE users SET password_hash = $1 WHERE id = $2`, [passwordHash, user.id]);
  await query(`UPDATE email_otps SET consumed = TRUE WHERE id = $1`, [record.id]);
  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1`, [user.id]);
  return { message: 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập lại.' };
}

module.exports = {
  register,
  verifyEmail,
  resendOtp,
  login,
  loginWithGoogle,
  setup2fa,
  verifySetup2fa,
  verify2fa,
  disable2fa,
  refresh,
  getMe,
  logout,
  forgotPassword,
  resetPassword,
};
