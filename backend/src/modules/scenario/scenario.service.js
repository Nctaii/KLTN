// Logic nghiệp vụ cho scenario: tạo, đọc, cập nhật cấu hình thế giới
const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

// Tạo scenario mới kèm cấu hình thế giới + nhân vật + cảnh giới (nếu tiên hiệp)
async function createScenario(authorId, body) {
  const {
    title,
    description,
    genre_ids = [],          // mảng id thể loại (1-2)
    world,                   // { world_setting, protagonist_role, default_mc_name, enemy_description, final_goal }
    key_characters = [],     // [{ name, role, description }]
    xh,                      // { cultivation_note, realms: [{name, tier, description}] }  (nếu tiên hiệp)
    fnt,                     // { magic_system, has_mana, classes: [{name, description, base_mana, base_hp}] }
  } = body;

  if (!title) throw new ApiError(400, 'Thiếu tiêu đề scenario');

  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO stories (author_id, title, description, status)
       VALUES ($1, $2, $3, 'published') RETURNING *`,
      [authorId, title, description || null]
    );
    const story = rows[0];

    // Gắn thể loại
    for (const gid of genre_ids) {
      await client.query(
        `INSERT INTO story_genres (story_id, genre_id) VALUES ($1, $2)`,
        [story.id, gid]
      );
    }

    // Cấu hình thế giới chung
    if (world) {
      await client.query(
        `INSERT INTO scenario_world
         (story_id, world_setting, protagonist_role, default_mc_name, enemy_description, final_goal)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          story.id,
          world.world_setting || null,
          world.protagonist_role || null,
          world.default_mc_name || null,
          world.enemy_description || null,
          world.final_goal || null,
        ]
      );
    }

    // Nhân vật quan trọng (nút "+")
    let idx = 0;
    for (const kc of key_characters) {
      await client.query(
        `INSERT INTO scenario_key_characters (story_id, name, role, description, order_index)
         VALUES ($1, $2, $3, $4, $5)`,
        [story.id, kc.name, kc.role, kc.description || null, idx++]
      );
    }

    // Cấu hình tiên hiệp
    if (xh) {
      await client.query(
        `INSERT INTO xh_world_config (story_id, cultivation_note) VALUES ($1, $2)`,
        [story.id, xh.cultivation_note || null]
      );
      for (const r of xh.realms || []) {
        await client.query(
          `INSERT INTO xh_realms (story_id, name, tier, description)
           VALUES ($1, $2, $3, $4)`,
          [story.id, r.name, r.tier, r.description || null]
        );
      }
    }

    // Cấu hình fantasy
    if (fnt) {
      await client.query(
        `INSERT INTO fnt_world_config (story_id, magic_system, has_mana)
         VALUES ($1, $2, $3)`,
        [story.id, fnt.magic_system || null, fnt.has_mana ?? true]
      );
      let ci = 0;
      for (const c of fnt.classes || []) {
        await client.query(
          `INSERT INTO fnt_classes (story_id, name, description, base_mana, base_hp, order_index)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [story.id, c.name, c.description || null, c.base_mana || 0, c.base_hp || 100, ci++]
        );
      }
      // Chủng tộc Fantasy
      let ri = 0;
      for (const r of fnt.races || []) {
        await client.query(
          `INSERT INTO fnt_races (story_id, name, description, order_index)
           VALUES ($1, $2, $3, $4)`,
          [story.id, r.name, r.description || null, ri++]
        );
      }
    }

    return story;
  });
}

// Lấy toàn bộ cấu hình một scenario (dùng cho cả việc hiển thị & nạp vào AI)
async function getScenarioFull(storyId) {
  const { rows: storyRows } = await query(
    `SELECT * FROM stories WHERE id = $1`,
    [storyId]
  );
  if (!storyRows[0]) throw new ApiError(404, 'Không tìm thấy scenario');
  const story = storyRows[0];

  const [world, chars, genres, xhConf, realms, fntConf, classes, races] =
    await Promise.all([
      query(`SELECT * FROM scenario_world WHERE story_id = $1`, [storyId]),
      query(
        `SELECT * FROM scenario_key_characters WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
      query(
        `SELECT g.* FROM genres g
         JOIN story_genres sg ON sg.genre_id = g.id WHERE sg.story_id = $1`,
        [storyId]
      ),
      query(`SELECT * FROM xh_world_config WHERE story_id = $1`, [storyId]),
      query(
        `SELECT * FROM xh_realms WHERE story_id = $1 ORDER BY tier`,
        [storyId]
      ),
      query(`SELECT * FROM fnt_world_config WHERE story_id = $1`, [storyId]),
      query(
        `SELECT * FROM fnt_classes WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
      query(
        `SELECT * FROM fnt_races WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
    ]);

  return {
    ...story,
    genres: genres.rows,
    world: world.rows[0] || null,
    key_characters: chars.rows,
    xh: xhConf.rows[0]
      ? { ...xhConf.rows[0], realms: realms.rows }
      : null,
    fnt: fntConf.rows[0]
      ? { ...fntConf.rows[0], classes: classes.rows, races: races.rows }
      : null,
  };
}

// Danh sách scenario đã publish (để người chơi duyệt)
async function listPublished() {
  const { rows } = await query(
    `SELECT s.id, s.title, s.description, s.play_count, s.cover_url,
            array_agg(DISTINCT g.name) AS genres,
            (SELECT COUNT(*)::int FROM story_likes l WHERE l.story_id = s.id) AS like_count,
            (SELECT COUNT(*)::int FROM comments c WHERE c.story_id = s.id) AS comment_count
     FROM stories s
     LEFT JOIN story_genres sg ON sg.story_id = s.id
     LEFT JOIN genres g ON g.id = sg.genre_id
     WHERE s.status = 'published'
     GROUP BY s.id ORDER BY s.created_at DESC`
  );
  return rows;
}

async function publishScenario(storyId, authorId) {
  const { rows } = await query(
    `UPDATE stories SET status = 'published', updated_at = now()
     WHERE id = $1 AND author_id = $2 RETURNING *`,
    [storyId, authorId]
  );
  if (!rows[0]) throw new ApiError(403, 'Không có quyền hoặc scenario không tồn tại');
  return rows[0];
}

// Danh sách scenario do chính user tạo (mọi trạng thái)
async function listMyScenarios(authorId) {
  const { rows } = await query(
    `SELECT s.id, s.title, s.description, s.play_count, s.status,
            array_agg(g.name) AS genres
     FROM stories s
     LEFT JOIN story_genres sg ON sg.story_id = s.id
     LEFT JOIN genres g ON g.id = sg.genre_id
     WHERE s.author_id = $1
     GROUP BY s.id ORDER BY s.created_at DESC`,
    [authorId]
  );
  return rows;
}

// Cập nhật ảnh bìa scenario (chỉ tác giả mới được sửa)
async function updateCover(authorId, storyId, coverUrl) {
  const { rows } = await query(
    `UPDATE stories SET cover_url = $1
     WHERE id = $2 AND author_id = $3 RETURNING id`,
    [coverUrl, storyId, authorId]
  );
  if (!rows[0]) throw new ApiError(403, 'Không có quyền sửa scenario này');
  return { cover_url: coverUrl };
}

// Xóa scenario (chỉ tác giả mới được xóa). CASCADE tự xóa dữ liệu liên quan.
async function deleteScenario(authorId, storyId) {
  const { rows } = await query(
    `DELETE FROM stories WHERE id = $1 AND author_id = $2 RETURNING id`,
    [storyId, authorId]
  );
  if (!rows[0]) throw new ApiError(403, 'Không có quyền xóa scenario này');
  return { deleted: true };
}

module.exports = {
  updateCover,
  deleteScenario,
  getScenarioFull,
  listPublished,
  publishScenario,
  listMyScenarios,
};
