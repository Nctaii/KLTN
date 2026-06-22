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
    personalities = [],
    plot_points = [],        // [{ title, description, min_chapters, choices: [{label, branch_hint}] }]
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
        `INSERT INTO xh_world_config (story_id, cultivation_note, mc_spirit_root)
         VALUES ($1, $2, $3)`,
        [story.id, xh.cultivation_note || null, xh.mc_spirit_root || null]
      );
      for (const r of xh.realms || []) {
        await client.query(
          `INSERT INTO xh_realms (story_id, name, tier, description)
           VALUES ($1, $2, $3, $4)`,
          [story.id, r.name, r.tier, r.description || null]
        );
      }
      // Tông môn (chính phái + tà phái)
      let si = 0;
      for (const s of xh.sects || []) {
        if (!s.name) continue;
        await client.query(
          `INSERT INTO xh_sects (story_id, name, faction, description, standing, order_index)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [story.id, s.name, s.faction || 'chinh', s.description || null, s.standing || null, si++]
        );
      }
      // Công pháp đặc trưng
      let ti = 0;
      for (const t of xh.techniques || []) {
        if (!t.name) continue;
        await client.query(
          `INSERT INTO xh_techniques (story_id, name, description, specialty, order_index)
           VALUES ($1, $2, $3, $4, $5)`,
          [story.id, t.name, t.description || null, t.specialty || null, ti++]
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

    // Tính cách nhân vật (cho người chơi chọn) - áp dụng cho mọi thể loại
    let pi = 0;
    for (const p of personalities) {
      if (!p.name) continue;
      await client.query(
        `INSERT INTO scenario_personalities (story_id, name, description, order_index)
         VALUES ($1, $2, $3, $4)`,
        [story.id, p.name, p.description || null, pi++]
      );
    }

    // Nút thắt cốt truyện + các lựa chọn tại mỗi nút (áp dụng cho mọi thể loại)
    let ppi = 0;
    for (const pp of plot_points) {
      if (!pp.title) continue;
      const { rows: ppRows } = await client.query(
        `INSERT INTO story_plot_points (story_id, order_index, title, description, min_chapters)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [
          story.id,
          ppi++,
          pp.title,
          pp.description || null,
          Number.isInteger(pp.min_chapters) ? pp.min_chapters : 2,
        ]
      );
      const plotId = ppRows[0].id;
      let ci = 0;
      for (const ch of pp.choices || []) {
        if (!ch.label) continue;
        await client.query(
          `INSERT INTO plot_point_choices (plot_point_id, label, branch_hint, order_index)
           VALUES ($1, $2, $3, $4)`,
          [plotId, ch.label, ch.branch_hint || null, ci++]
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

  const [world, chars, genres, xhConf, realms, fntConf, classes, races, personalities, sects, techniques, plotPointsRes] =
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
      query(
        `SELECT id, name, description FROM scenario_personalities
         WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
      query(
        `SELECT * FROM xh_sects WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
      query(
        `SELECT * FROM xh_techniques WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
      query(
        `SELECT * FROM story_plot_points WHERE story_id = $1 ORDER BY order_index`,
        [storyId]
      ),
    ]);

  // Gắn các lựa chọn vào từng nút thắt
  const plotPoints = plotPointsRes.rows;
  for (const pp of plotPoints) {
    const { rows: choices } = await query(
      `SELECT id, label, branch_hint FROM plot_point_choices
       WHERE plot_point_id = $1 ORDER BY order_index`,
      [pp.id]
    );
    pp.choices = choices;
  }

  return {
    ...story,
    genres: genres.rows,
    world: world.rows[0] || null,
    key_characters: chars.rows,
    personalities: personalities.rows,
    plot_points: plotPoints,
    xh: xhConf.rows[0]
      ? { ...xhConf.rows[0], realms: realms.rows, sects: sects.rows, techniques: techniques.rows }
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

// Sửa thông tin cơ bản scenario (tên, mô tả) — chỉ tác giả
async function updateScenarioInfo(authorId, storyId, { title, description }) {
  const { rows } = await query(
    `UPDATE stories SET
       title = COALESCE($1, title),
       description = COALESCE($2, description),
       updated_at = now()
     WHERE id = $3 AND author_id = $4 RETURNING id, title, description`,
    [title ?? null, description ?? null, storyId, authorId]
  );
  if (!rows[0]) throw new ApiError(403, 'Không có quyền sửa scenario này');
  return rows[0];
}

// Cập nhật TOÀN BỘ cấu hình scenario theo kiểu đồng bộ (an toàn với scenario đã có người chơi):
// - mục có id -> UPDATE; mục mới (không id) -> INSERT; mục cũ không còn trong danh sách -> DELETE
// - order_index ghi theo vị trí trong mảng (hỗ trợ sắp xếp thứ tự)
async function updateScenarioFull(authorId, storyId, body) {
  return withTransaction(async (client) => {
    // Kiểm tra quyền sở hữu
    const { rows: own } = await client.query(
      `SELECT id FROM stories WHERE id = $1 AND author_id = $2`,
      [storyId, authorId]
    );
    if (!own[0]) throw new ApiError(403, 'Không có quyền sửa scenario này');

    const {
      title,
      description,
      world,
      key_characters = [],
      personalities = [],
      plot_points = [],
      xh,
      fnt,
    } = body;

    // 1. Thông tin chung
    await client.query(
      `UPDATE stories SET title = COALESCE($1, title),
         description = COALESCE($2, description), updated_at = now()
       WHERE id = $3`,
      [title ?? null, description ?? null, storyId]
    );

    // 2. Bối cảnh thế giới (1-1: update hoặc upsert)
    if (world) {
      await client.query(
        `INSERT INTO scenario_world (story_id, world_setting, protagonist_role, default_mc_name, enemy_description, final_goal)
         VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (story_id) DO UPDATE SET
           world_setting=$2, protagonist_role=$3, default_mc_name=$4, enemy_description=$5, final_goal=$6`,
        [storyId, world.world_setting||null, world.protagonist_role||null, world.default_mc_name||null, world.enemy_description||null, world.final_goal||null]
      );
    }

    // Helper đồng bộ một bảng con đơn giản (story_id + các cột) theo danh sách items
    async function syncTable(table, items, columns, buildValues) {
      // Lấy id hiện có
      const { rows: existing } = await client.query(
        `SELECT id FROM ${table} WHERE story_id = $1`, [storyId]
      );
      const existingIds = existing.map((r) => String(r.id));
      const keptIds = items.filter((it) => it.id).map((it) => String(it.id));
      // Xóa những cái không còn
      const toDelete = existingIds.filter((id) => !keptIds.includes(id));
      for (const id of toDelete) {
        await client.query(`DELETE FROM ${table} WHERE id = $1 AND story_id = $2`, [id, storyId]);
      }
      // Update / Insert
      let idx = 0;
      for (const it of items) {
        const vals = buildValues(it, idx);
        if (it.id) {
          const setClause = columns.map((c, i) => `${c} = $${i + 1}`).join(', ');
          await client.query(
            `UPDATE ${table} SET ${setClause} WHERE id = $${columns.length + 1} AND story_id = $${columns.length + 2}`,
            [...vals, it.id, storyId]
          );
        } else {
          const colList = ['story_id', ...columns].join(', ');
          const ph = ['$1', ...columns.map((_, i) => `$${i + 2}`)].join(', ');
          await client.query(
            `INSERT INTO ${table} (${colList}) VALUES (${ph})`,
            [storyId, ...vals]
          );
        }
        idx++;
      }
    }

    // 3. Nhân vật quan trọng
    await syncTable(
      'scenario_key_characters',
      key_characters.filter((c) => c.name),
      ['name', 'role', 'description', 'order_index'],
      (c, i) => [c.name, c.role || null, c.description || null, i]
    );

    // 4. Tính cách
    await syncTable(
      'scenario_personalities',
      personalities.filter((p) => p.name),
      ['name', 'description', 'order_index'],
      (p, i) => [p.name, p.description || null, i]
    );

    // 5. Tiên hiệp: cảnh giới, tông môn, công pháp + cấu hình
    if (xh) {
      await client.query(
        `INSERT INTO xh_world_config (story_id, cultivation_note, mc_spirit_root)
         VALUES ($1,$2,$3)
         ON CONFLICT (story_id) DO UPDATE SET cultivation_note=$2, mc_spirit_root=$3`,
        [storyId, xh.cultivation_note||null, xh.mc_spirit_root||null]
      );
      await syncTable(
        'xh_realms',
        (xh.realms||[]).filter((r) => r.name),
        ['name', 'tier', 'description'],
        (r, i) => [r.name, r.tier ?? (i + 1), r.description || null]
      );
      await syncTable(
        'xh_sects',
        (xh.sects||[]).filter((s) => s.name),
        ['name', 'faction', 'description', 'standing', 'order_index'],
        (s, i) => [s.name, s.faction || 'chinh', s.description || null, s.standing || null, i]
      );
      await syncTable(
        'xh_techniques',
        (xh.techniques||[]).filter((t) => t.name),
        ['name', 'description', 'specialty', 'order_index'],
        (t, i) => [t.name, t.description || null, t.specialty || null, i]
      );
    }

    // 6. Fantasy
    if (fnt) {
      await client.query(
        `INSERT INTO fnt_world_config (story_id, magic_system, has_mana)
         VALUES ($1,$2,$3)
         ON CONFLICT (story_id) DO UPDATE SET magic_system=$2, has_mana=$3`,
        [storyId, fnt.magic_system||null, fnt.has_mana !== false]
      );
      await syncTable(
        'fnt_classes',
        (fnt.classes||[]).filter((c) => c.name),
        ['name', 'description', 'order_index'],
        (c, i) => [c.name, c.description || null, i]
      );
      await syncTable(
        'fnt_races',
        (fnt.races||[]).filter((r) => r.name),
        ['name', 'description', 'order_index'],
        (r, i) => [r.name, r.description || null, i]
      );
    }

    // 7. Nút thắt + lựa chọn (order_index theo vị trí mảng -> hỗ trợ sắp xếp)
    {
      const { rows: existing } = await client.query(
        `SELECT id FROM story_plot_points WHERE story_id = $1`, [storyId]
      );
      const existingIds = existing.map((r) => String(r.id));
      const keptIds = plot_points.filter((p) => p.id).map((p) => String(p.id));
      for (const id of existingIds.filter((id) => !keptIds.includes(id))) {
        await client.query(`DELETE FROM story_plot_points WHERE id = $1 AND story_id = $2`, [id, storyId]);
      }
      let ppi = 0;
      for (const pp of plot_points.filter((p) => p.title)) {
        let plotId = pp.id;
        if (plotId) {
          await client.query(
            `UPDATE story_plot_points SET order_index=$1, title=$2, description=$3, min_chapters=$4
             WHERE id=$5 AND story_id=$6`,
            [ppi, pp.title, pp.description||null, Number.isInteger(pp.min_chapters)?pp.min_chapters:2, plotId, storyId]
          );
        } else {
          const { rows } = await client.query(
            `INSERT INTO story_plot_points (story_id, order_index, title, description, min_chapters)
             VALUES ($1,$2,$3,$4,$5) RETURNING id`,
            [storyId, ppi, pp.title, pp.description||null, Number.isInteger(pp.min_chapters)?pp.min_chapters:2]
          );
          plotId = rows[0].id;
        }
        ppi++;
        // Đồng bộ lựa chọn của nút thắt này
        const choices = (pp.choices||[]).filter((c) => c.label);
        const { rows: exC } = await client.query(
          `SELECT id FROM plot_point_choices WHERE plot_point_id = $1`, [plotId]
        );
        const exCIds = exC.map((r) => String(r.id));
        const keptCIds = choices.filter((c) => c.id).map((c) => String(c.id));
        for (const id of exCIds.filter((id) => !keptCIds.includes(id))) {
          await client.query(`DELETE FROM plot_point_choices WHERE id = $1`, [id]);
        }
        let ci = 0;
        for (const c of choices) {
          if (c.id) {
            await client.query(
              `UPDATE plot_point_choices SET label=$1, branch_hint=$2, order_index=$3 WHERE id=$4`,
              [c.label, c.branch_hint||null, ci, c.id]
            );
          } else {
            await client.query(
              `INSERT INTO plot_point_choices (plot_point_id, label, branch_hint, order_index)
               VALUES ($1,$2,$3,$4)`,
              [plotId, c.label, c.branch_hint||null, ci]
            );
          }
          ci++;
        }
      }
    }

    return { id: storyId };
  });
}

module.exports = {
  createScenario,
  getScenarioFull,
  listPublished,
  publishScenario,
  listMyScenarios,
  updateCover,
  deleteScenario,
  updateScenarioInfo,
  updateScenarioFull,
};