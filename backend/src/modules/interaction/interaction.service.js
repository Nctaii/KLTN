const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function toggleLike(userId, storyId) {
  const { rows: existing } = await query(
    `SELECT 1 FROM story_likes WHERE user_id = $1 AND story_id = $2`,
    [userId, storyId]
  );
  let liked;
  if (existing[0]) {
    await query(`DELETE FROM story_likes WHERE user_id = $1 AND story_id = $2`,
      [userId, storyId]);
    liked = false;
  } else {
    await query(
      `INSERT INTO story_likes (user_id, story_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [userId, storyId]
    );
    liked = true;
  }
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count FROM story_likes WHERE story_id = $1`,
    [storyId]
  );
  return { liked, likeCount: rows[0].count };
}

async function getLikeInfo(userId, storyId) {
  const { rows: cnt } = await query(
    `SELECT COUNT(*)::int AS count FROM story_likes WHERE story_id = $1`,
    [storyId]
  );
  const { rows: mine } = await query(
    `SELECT 1 FROM story_likes WHERE user_id = $1 AND story_id = $2`,
    [userId, storyId]
  );
  return { likeCount: cnt[0].count, likedByMe: mine.length > 0 };
}

async function addComment(userId, storyId, content) {
  if (!content || !content.trim()) {
    throw new ApiError(400, 'Nội dung bình luận không được trống');
  }
  const { rows } = await query(
    `INSERT INTO comments (user_id, story_id, content)
     VALUES ($1, $2, $3) RETURNING id, content, created_at`,
    [userId, storyId, content.trim()]
  );
  return rows[0];
}

async function listComments(storyId) {
  const { rows } = await query(
    `SELECT c.id, c.content, c.created_at,
            COALESCE(p.display_name, u.username) AS author_name,
            p.avatar_url AS author_avatar
     FROM comments c
     JOIN users u ON u.id = c.user_id
     LEFT JOIN user_profiles p ON p.user_id = u.id
     WHERE c.story_id = $1
     ORDER BY c.created_at DESC`,
    [storyId]
  );
  return rows;
}

module.exports = { toggleLike, getLikeInfo, addComment, listComments };