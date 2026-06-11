const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function getProfile(userId) {
  const { rows } = await query(
    `SELECT u.id, u.email, u.username, u.role, u.is_verified,
            p.display_name, p.avatar_url
     FROM users u
     LEFT JOIN user_profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );
  if (!rows[0]) throw new ApiError(404, 'Không tìm thấy người dùng');
  return rows[0];
}

async function updateProfile(userId, { displayName }) {
  if (displayName !== undefined) {
    await query(
      `UPDATE user_profiles SET display_name = $1 WHERE user_id = $2`,
      [displayName, userId]
    );
  }
  return getProfile(userId);
}

async function updateAvatar(userId, avatarUrl) {
  await query(
    `UPDATE user_profiles SET avatar_url = $1 WHERE user_id = $2`,
    [avatarUrl, userId]
  );
  return getProfile(userId);
}

module.exports = { getProfile, updateProfile, updateAvatar };