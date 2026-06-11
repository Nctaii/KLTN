// Logic nghiệp vụ cho xác thực: đăng ký + xác minh OTP, đăng nhập, refresh, me
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { query, withTransaction } = require('../../config/db');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} = require('../../utils/jwt');
// Công tắc xác minh email. Đặt REQUIRE_EMAIL_VERIFICATION=false trên Render
// để đăng ký tự verify ngay (không gửi OTP), tránh phụ thuộc SMTP.
const REQUIRE_EMAIL_VERIFICATION =
  process.env.REQUIRE_EMAIL_VERIFICATION !== 'false';
const ApiError = require('../../utils/ApiError');
const mailService = require('../mail/mail.service');

const MAX_OTP_ATTEMPTS = 5;

function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    username: row.username,
    role: row.role,
    is_verified: row.is_verified,
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

// Sinh OTP 6 số, lưu hash vào DB, gửi mail
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

// Đăng ký: tạo user CHƯA xác minh, gửi OTP, KHÔNG cấp token.
// Nếu email đã tồn tại nhưng CHƯA xác minh -> cho đăng ký lại (đè lên + gửi OTP mới).
// Nếu email đã tồn tại và ĐÃ xác minh -> báo lỗi.
async function register({ email, username, password }) {
  if (!email || !username || !password) {
    throw new ApiError(400, 'Thiếu email, username hoặc password');
  }
  if (password.length < 6) {
    throw new ApiError(400, 'Mật khẩu phải từ 6 ký tự trở lên');
  }
  const passwordHash = await bcrypt.hash(password, 10);

  // Kiểm tra username đã có người khác dùng chưa (báo rõ trường 'username')
  const { rows: dupName } = await query(
    `SELECT id FROM users WHERE username = $1 AND email <> $2`,
    [username, email]
  );
  if (dupName[0]) {
    throw new ApiError(409, 'Tên đăng nhập đã được sử dụng', 'username');
  }

  // Kiểm tra email đã tồn tại chưa
  const { rows: existing } = await query(
    `SELECT id, is_verified FROM users WHERE email = $1`,
    [email]
  );

  let user;
  if (existing[0]) {
    // Email đã tồn tại
    if (existing[0].is_verified) {
      throw new ApiError(409, 'Email này đã được đăng ký và xác minh', 'email');
    }
    // Chưa xác minh -> cập nhật lại thông tin (đăng ký đè)
    const { rows } = await query(
      `UPDATE users SET username = $1, password_hash = $2, updated_at = now()
       WHERE id = $3 RETURNING id, email, username, role, is_verified`,
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
         VALUES ($1, $2, $3, FALSE) RETURNING id, email, username, role, is_verified`,
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

  // Nếu yêu cầu xác minh -> gửi OTP và báo chờ xác minh.
  // Nếu tắt -> bỏ qua gửi mail, báo đăng ký thành công luôn.
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
// Xác minh OTP: đúng thì đánh dấu verified và cấp token
async function verifyEmail({ email, otp }) {
  if (!email || !otp) throw new ApiError(400, 'Thiếu email hoặc mã OTP');

  const { rows: urows } = await query(
    `SELECT id, email, username, role, is_verified FROM users WHERE email = $1`,
    [email]
  );
  const user = urows[0];
  if (!user) throw new ApiError(404, 'Không tìm thấy tài khoản');
  if (user.is_verified) {
    throw new ApiError(400, 'Tài khoản đã được xác minh trước đó');
  }

  // Lấy OTP mới nhất còn hiệu lực
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
    await query(`UPDATE email_otps SET attempts = attempts + 1 WHERE id = $1`, [
      record.id,
    ]);
    throw new ApiError(400, 'Mã xác minh không đúng');
  }

  // Đúng: đánh dấu OTP đã dùng + user đã xác minh
  await query(`UPDATE email_otps SET consumed = TRUE WHERE id = $1`, [record.id]);
  await query(`UPDATE users SET is_verified = TRUE WHERE id = $1`, [user.id]);

  user.is_verified = true;
  const tokens = await issueTokens(user);
  return { user: publicUser(user), ...tokens };
}

// Gửi lại OTP
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

// Đăng nhập: CHẶN nếu chưa xác minh email
async function login({ email, password }) {
  const { rows } = await query(
    `SELECT id, email, username, password_hash, role, is_active, is_verified
     FROM users WHERE email = $1`,
    [email]
  );
  const user = rows[0];
  if (!user || !user.is_active) {
    throw new ApiError(401, 'Email hoặc mật khẩu không đúng');
  }
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    throw new ApiError(401, 'Email hoặc mật khẩu không đúng');
  }
  if (!user.is_verified) {
    // 403: đăng nhập đúng nhưng chưa xác minh -> client điều hướng sang màn nhập OTP
    throw new ApiError(403, 'Tài khoản chưa xác minh email. Vui lòng kiểm tra hộp thư.');
  }
  const tokens = await issueTokens(user);
  return { user: publicUser(user), ...tokens };
}

async function refresh(refreshToken) {
  if (!refreshToken) throw new ApiError(400, 'Thiếu refresh token');
  let payload;
  try {
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

  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE id = $1`, [
    matched.id,
  ]);
  const { rows: urows } = await query(
    `SELECT id, email, username, role, is_verified FROM users WHERE id = $1`,
    [payload.sub]
  );
  const tokens = await issueTokens(urows[0]);
  return { user: publicUser(urows[0]), ...tokens };
}

async function getMe(userId) {
  const { rows } = await query(
    `SELECT u.id, u.email, u.username, u.role, u.is_verified, p.display_name, p.avatar_url
     FROM users u LEFT JOIN user_profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );
  if (!rows[0]) throw new ApiError(404, 'Không tìm thấy người dùng');
  return rows[0];
}

async function logout(userId) {
  await query(`UPDATE refresh_tokens SET revoked = TRUE WHERE user_id = $1`, [
    userId,
  ]);
}

// Quên mật khẩu: gửi OTP reset tới email (nếu tài khoản tồn tại & đã xác minh)
async function forgotPassword({ email }) {
  if (!email) throw new ApiError(400, 'Thiếu email');
  const { rows } = await query(
    `SELECT id, is_verified FROM users WHERE email = $1`,
    [email]
  );
  const user = rows[0];
  // Vì bảo mật, không tiết lộ email có tồn tại hay không
  if (user && user.is_verified) {
    await createAndSendOtp(user.id, email, 'reset_password');
  }
  return { message: 'Nếu email tồn tại, mã đặt lại mật khẩu đã được gửi.' };
}

// Đặt lại mật khẩu: kiểm tra OTP reset đúng -> đổi mật khẩu
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
  refresh,
  getMe,
  logout,
  forgotPassword,
  resetPassword,
};
