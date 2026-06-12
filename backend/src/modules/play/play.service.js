// Logic lượt chơi: bắt đầu chơi, sinh chương, chọn hướng đi
const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const scenarioService = require('../scenario/scenario.service');
const aiService = require('../ai/ai.service');

// Bắt đầu một lượt chơi mới: tạo session + nhân vật, AI sinh chương 1
async function startPlay(userId, storyId, mcNameInput, chosenPersonality) {
  const scenario = await scenarioService.getScenarioFull(storyId);

  // Tên nhân vật: ưu tiên người chơi nhập, nếu trống lấy mặc định của scenario
  const mcName =
    (mcNameInput && mcNameInput.trim()) ||
    scenario.world?.default_mc_name ||
    'Vô Danh';

  // Khởi tạo chỉ số ban đầu theo thể loại
  let initStats = {};
  if (scenario.xh) initStats = { realm_tier: 1, qi: 0 };
  else if (scenario.fnt) initStats = { mana: 0, hp: 100 };

  const session = await withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO play_sessions (user_id, story_id, chosen_personality)
       VALUES ($1, $2, $3) RETURNING *`,
      [userId, storyId, (chosenPersonality && chosenPersonality.trim()) || null]
    );
    const s = rows[0];
    await client.query(
      `INSERT INTO session_character (session_id, mc_name, stats)
       VALUES ($1, $2, $3)`,
      [s.id, mcName, JSON.stringify(initStats)]
    );
    await client.query(
      `UPDATE stories SET play_count = play_count + 1 WHERE id = $1`,
      [storyId]
    );
    return s;
  });

  // AI sinh chương 1
  const gen = await aiService.generateChapter({
    scenario,
    mcName,
    previousChapters: [],
    direction: null,
    personality: (chosenPersonality && chosenPersonality.trim()) || null,
  });

  const chapter = await saveChapter({
    sessionId: session.id,
    chapterNumber: 1,
    content: gen.content,
    options: gen.options,
    chosenDirection: null,
    directionSource: null,
    tokenUsed: gen.tokenUsed,
  });

  // Lưu tóm tắt tích lũy ban đầu (sau chương 1)
  if (gen.summary && gen.summary.trim()) {
    await query(
      `UPDATE play_sessions SET running_summary = $1 WHERE id = $2`,
      [gen.summary.trim(), session.id]
    );
  }

  return { session_id: session.id, mc_name: mcName, chapter };
}

// Lưu một chương + các lựa chọn của nó (transaction) + log AI
async function saveChapter({
  sessionId,
  chapterNumber,
  content,
  options,
  chosenDirection,
  directionSource,
  tokenUsed,
}) {
  return withTransaction(async (client) => {
    const wordCount = content.trim().split(/\s+/).length;
    const { rows } = await client.query(
      `INSERT INTO story_chapters
       (session_id, chapter_number, content, word_count, chosen_direction, direction_source)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [sessionId, chapterNumber, content, wordCount, chosenDirection, directionSource]
    );
    const chapter = rows[0];

    const savedOptions = [];
    let idx = 0;
    for (const label of options) {
      const r = await client.query(
        `INSERT INTO chapter_options (chapter_id, label, order_index)
         VALUES ($1, $2, $3) RETURNING *`,
        [chapter.id, label, idx++]
      );
      savedOptions.push(r.rows[0]);
    }

    await client.query(
      `INSERT INTO ai_generations (session_id, chapter_id, gen_type, model, token_used)
       VALUES ($1, $2, 'chapter', $3, $4)`,
      [sessionId, chapter.id, process.env.ANTHROPIC_MODEL || 'claude-haiku-4-5', tokenUsed]
    );

    return { ...chapter, options: savedOptions };
  });
}

// Người chơi chọn hướng đi (từ option AI hoặc tự viết) -> sinh chương kế tiếp
async function continuePlay(userId, sessionId, { option_id, custom_direction }) {
  // Xác thực session thuộc về người chơi
  const { rows: srows } = await query(
    `SELECT ps.*, sc.mc_name FROM play_sessions ps
     JOIN session_character sc ON sc.session_id = ps.id
     WHERE ps.id = $1 AND ps.user_id = $2`,
    [sessionId, userId]
  );
  if (!srows[0]) throw new ApiError(404, 'Không tìm thấy lượt chơi');
  const session = srows[0];

  // Xác định hướng đi
  let direction;
  let directionSource;
  if (custom_direction && custom_direction.trim()) {
    direction = custom_direction.trim();
    directionSource = 'user_written';
  } else if (option_id) {
    const { rows } = await query(
      `SELECT label FROM chapter_options WHERE id = $1`,
      [option_id]
    );
    if (!rows[0]) throw new ApiError(400, 'Lựa chọn không tồn tại');
    direction = rows[0].label;
    directionSource = 'ai_option';
    await query(`UPDATE chapter_options SET is_chosen = TRUE WHERE id = $1`, [
      option_id,
    ]);
  } else {
    throw new ApiError(400, 'Cần option_id hoặc custom_direction');
  }

  // Lấy các chương trước để làm context
  const { rows: prev } = await query(
    `SELECT chapter_number, content FROM story_chapters
     WHERE session_id = $1 ORDER BY chapter_number`,
    [sessionId]
  );
  const nextNumber = prev.length + 1;

  const scenario = await scenarioService.getScenarioFull(session.story_id);
  const gen = await aiService.generateChapter({
    scenario,
    mcName: session.mc_name,
    previousChapters: prev,
    direction,
    runningSummary: session.running_summary || '',
    personality: session.chosen_personality || null,
  });

  const chapter = await saveChapter({
    sessionId,
    chapterNumber: nextNumber,
    content: gen.content,
    options: gen.options,
    chosenDirection: direction,
    directionSource,
    tokenUsed: gen.tokenUsed,
  });

  // Lưu bản tóm tắt tích lũy mới (nếu AI trả về) để chương sau dùng
  if (gen.summary && gen.summary.trim()) {
    await query(
      `UPDATE play_sessions SET running_summary = $1 WHERE id = $2`,
      [gen.summary.trim(), sessionId]
    );
  }

  await query(
    `UPDATE play_sessions SET last_played_at = now() WHERE id = $1`,
    [sessionId]
  );

  return { session_id: sessionId, chapter };
}

// Lấy toàn bộ chương của một lượt chơi (để đọc lại)
async function getPlaythrough(userId, sessionId) {
  const { rows: srows } = await query(
    `SELECT * FROM play_sessions WHERE id = $1 AND user_id = $2`,
    [sessionId, userId]
  );
  if (!srows[0]) throw new ApiError(404, 'Không tìm thấy lượt chơi');

  const { rows: chapters } = await query(
    `SELECT * FROM story_chapters WHERE session_id = $1 ORDER BY chapter_number`,
    [sessionId]
  );
  for (const ch of chapters) {
    const { rows: opts } = await query(
      `SELECT * FROM chapter_options WHERE chapter_id = $1 ORDER BY order_index`,
      [ch.id]
    );
    ch.options = opts;
  }
  return { session: srows[0], chapters };
}

// Liệt kê các lượt chơi của user (kèm tên scenario + số chương)
async function listMySessions(userId) {
  const { rows } = await query(
    `SELECT ps.id AS session_id,
            ps.story_id,
            s.title AS story_title,
            sc.mc_name,
            ps.last_played_at,
            COUNT(ch.id) AS chapter_count
     FROM play_sessions ps
     JOIN stories s ON s.id = ps.story_id
     LEFT JOIN session_character sc ON sc.session_id = ps.id
     LEFT JOIN story_chapters ch ON ch.session_id = ps.id
     WHERE ps.user_id = $1
     GROUP BY ps.id, s.title, sc.mc_name
     ORDER BY ps.last_played_at DESC`,
    [userId]
  );
  return rows;
}

// Xóa các lượt chơi của user cho một scenario cụ thể
async function deleteSessionsByStory(userId, storyId) {
  await query(
    `DELETE FROM play_sessions WHERE user_id = $1 AND story_id = $2`,
    [userId, storyId]
  );
}

module.exports = { startPlay, continuePlay, getPlaythrough, listMySessions, deleteSessionsByStory };
