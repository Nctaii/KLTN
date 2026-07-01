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
    // Nạp chiêu khởi đầu: lấy từ công pháp tác giả định sẵn (tiên hiệp)
    const initialSkills = (scenario.xh?.techniques || []);
    for (const t of initialSkills) {
      await client.query(
        `INSERT INTO session_skills (session_id, name, description, source)
         VALUES ($1, $2, $3, 'initial')
         ON CONFLICT (session_id, name) DO NOTHING`,
        [s.id, t.name, t.description || (t.specialty ? `Sở trường: ${t.specialty}` : null)]
      );
    }
    return s;
  });

  // Đọc kho chiêu vừa nạp để đưa vào AI
  const skills = await getSessionSkills(session.id);

  // AI sinh chương 1
  const gen = await aiService.generateChapter({
    scenario,
    mcName,
    previousChapters: [],
    direction: null,
    personality: (chosenPersonality && chosenPersonality.trim()) || null,
    skills,
    chosenSkill: null,
    mode: 'normal',
  });

  // Chương 1 thường: nếu AI quên options thì sinh lại hợp ngữ cảnh
  if (gen.mode !== 'combat' && (!gen.options || gen.options.length === 0)) {
    const extra = await aiService.suggestOptionsForChapter({
      chapterContent: gen.content,
      mcName,
    });
    gen.options = (extra && extra.length > 0)
      ? extra
      : ['Tiếp tục tiến về phía trước', 'Quan sát kỹ xung quanh', 'Hành động theo ý mình'];
  }

  const chapter = await saveChapter({
    sessionId: session.id,
    chapterNumber: 1,
    content: gen.content,
    options: gen.options,
    chosenDirection: null,
    directionSource: null,
    tokenUsed: gen.tokenUsed,
    mode: gen.mode,
  });

  // Nếu AI cho học chiêu mới ngay chương 1
  if (gen.learnedSkill) {
    await addSessionSkill(session.id, gen.learnedSkill);
  }

  // Lưu tóm tắt tích lũy ban đầu (sau chương 1)
  if (gen.summary && gen.summary.trim()) {
    await query(
      `UPDATE play_sessions SET running_summary = $1 WHERE id = $2`,
      [gen.summary.trim(), session.id]
    );
  }

  // Đọc lại kho chiêu (có thể vừa thêm chiêu mới) để trả về cho client
  const skillsAfter = await getSessionSkills(session.id);

  return {
    session_id: session.id,
    mc_name: mcName,
    chapter,
    mode: gen.mode,
    combat_info: gen.combatInfo,
    skills: skillsAfter,
  };
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
  mode,
  plotPointId,
  isCombatStart,
}) {
  return withTransaction(async (client) => {
    const wordCount = content.trim().split(/\s+/).length;
    const { rows } = await client.query(
      `INSERT INTO story_chapters
       (session_id, chapter_number, content, word_count, chosen_direction, direction_source, mode, plot_point_id, is_combat_start)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [sessionId, chapterNumber, content, wordCount, chosenDirection, directionSource, mode || 'normal', plotPointId || null, isCombatStart || false]
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

// Người chơi chọn hướng đi (từ option AI hoặc tự viết) hoặc chọn chiêu (khi chiến đấu) -> sinh chương kế tiếp
async function continuePlay(userId, sessionId, { option_id, custom_direction, skill_name, plot_choice_id }) {
  // Xác thực session thuộc về người chơi
  const { rows: srows } = await query(
    `SELECT ps.*, sc.mc_name FROM play_sessions ps
     JOIN session_character sc ON sc.session_id = ps.id
     WHERE ps.id = $1 AND ps.user_id = $2`,
    [sessionId, userId]
  );
  if (!srows[0]) throw new ApiError(404, 'Không tìm thấy lượt chơi');
  const session = srows[0];

  // Xác định đầu vào: chiêu thức / lựa chọn nút thắt / hướng đi thường
  let direction = null;
  let directionSource = null;
  let chosenSkill = null;
  let advancePlot = false; // có vừa vượt qua một nút thắt không

  if (skill_name && skill_name.trim()) {
    // Đang chiến đấu: người chơi chọn chiêu
    chosenSkill = skill_name.trim();
    directionSource = 'skill';
  } else if (plot_choice_id) {
    // Người chơi chọn một lựa chọn tại NÚT THẮT
    const { rows } = await query(
      `SELECT label, branch_hint FROM plot_point_choices WHERE id = $1`,
      [plot_choice_id]
    );
    if (!rows[0]) throw new ApiError(400, 'Lựa chọn nút thắt không tồn tại');
    // Dùng cả label + định hướng nhánh để AI dẫn truyện theo nhánh đã chọn
    direction = rows[0].branch_hint
      ? `${rows[0].label}. (Định hướng: ${rows[0].branch_hint})`
      : rows[0].label;
    directionSource = 'plot_choice';
    advancePlot = true;
  } else if (custom_direction && custom_direction.trim()) {
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
    throw new ApiError(400, 'Cần option_id, custom_direction, skill_name hoặc plot_choice_id');
  }

  // Nếu vừa chọn lựa chọn nút thắt -> đã vượt qua nút đó, tăng chỉ số
  if (advancePlot) {
    await query(
      `UPDATE play_sessions SET current_plot_index = current_plot_index + 1 WHERE id = $1`,
      [sessionId]
    );
    session.current_plot_index = (session.current_plot_index || 0) + 1;
  }

  // Lấy các chương trước để làm context
  const { rows: prev } = await query(
    `SELECT chapter_number, content FROM story_chapters
     WHERE session_id = $1 ORDER BY chapter_number`,
    [sessionId]
  );
  const nextNumber = prev.length + 1;

  // Mode hiện tại = mode của chương gần nhất
  const { rows: lastCh } = await query(
    `SELECT mode FROM story_chapters WHERE session_id = $1
     ORDER BY chapter_number DESC LIMIT 1`,
    [sessionId]
  );
  const currentMode = lastCh[0]?.mode || 'normal';

  const skills = await getSessionSkills(sessionId);
  const scenario = await scenarioService.getScenarioFull(session.story_id);

  // --- Cơ chế nút thắt ---
  // Lấy nút thắt tiếp theo (theo current_plot_index). Chỉ "mở khóa" khi đã đủ min_chapters.
  const plotPoints = scenario.plot_points || [];
  const plotIdx = session.current_plot_index || 0;
  const nextPlot = plotPoints[plotIdx] || null;
  let plotContext = null;
  let forcePlot = false; // ép kích hoạt nút thắt nếu AI mãi không tự báo
  if (nextPlot && currentMode !== 'combat') {
    // Đếm số chương kể từ NÚT THẮT gần nhất (chương có plot_point_id).
    // Nếu chưa qua nút thắt nào thì đếm từ đầu.
    const { rows: lastPlotRows } = await query(
      `SELECT MAX(chapter_number) AS n FROM story_chapters
       WHERE session_id = $1 AND plot_point_id IS NOT NULL`,
      [sessionId]
    );
    const lastPlotChapter = lastPlotRows[0]?.n || 0;
    const chaptersSincePlot = prev.length - lastPlotChapter;
    const minCh = nextPlot.min_chapters || 2;

    if (chaptersSincePlot >= minCh) {
      // Đã đủ số chương tối thiểu -> đưa nút thắt vào ngữ cảnh để AI dẫn tới
      plotContext = { title: nextPlot.title, description: nextPlot.description };
      // TRẦN ÉP: nếu đã vượt quá (minCh + 2) chương mà AI vẫn chưa kích hoạt,
      // backend tự ép chương này là nút thắt để đảm bảo nút thắt luôn xuất hiện.
      if (chaptersSincePlot >= minCh + 2) {
        forcePlot = true;
      }
    }
  }

  const gen = await aiService.generateChapter({
    scenario,
    mcName: session.mc_name,
    previousChapters: prev,
    direction,
    runningSummary: session.running_summary || '',
    personality: session.chosen_personality || null,
    skills,
    chosenSkill,
    mode: currentMode,
    plotContext,
    forcePlot, // báo cho AI biết PHẢI kết chương tại nút thắt lần này
  });

  // Nếu AI báo vừa tới nút thắt HOẶC bị ép -> đánh dấu chương là nút thắt
  const atPlot = (gen.atPlotPoint || forcePlot) && nextPlot;
  // Chương đầu trận combat: mode chuyển từ normal (chương trước) sang combat (chương này)
  const isCombatStart = gen.mode === 'combat' && currentMode !== 'combat';

  // Nếu là chương thường (không combat, không nút thắt) mà AI quên sinh options:
  // gọi AI sinh lại các hướng đi HỢP NGỮ CẢNH dựa trên nội dung chương vừa viết.
  if (gen.mode !== 'combat' && !atPlot && (!gen.options || gen.options.length === 0)) {
    const extraOptions = await aiService.suggestOptionsForChapter({
      chapterContent: gen.content,
      mcName: session.mc_name,
    });
    if (extraOptions && extraOptions.length > 0) {
      gen.options = extraOptions;
    } else {
      // Phương án cuối: bộ mặc định để không bao giờ kẹt màn hình trống
      gen.options = [
        'Tiếp tục tiến về phía trước',
        'Quan sát kỹ xung quanh',
        'Hành động theo ý mình',
      ];
    }
  }

  const chapter = await saveChapter({
    sessionId,
    chapterNumber: nextNumber,
    content: gen.content,
    options: gen.options,
    chosenDirection: chosenSkill || direction,
    directionSource,
    tokenUsed: gen.tokenUsed,
    mode: gen.mode,
    plotPointId: atPlot ? nextPlot.id : null,
    isCombatStart,
  });

  // Học chiêu mới nếu AI báo
  if (gen.learnedSkill) {
    await addSessionSkill(sessionId, gen.learnedSkill);
  }

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

  // Đọc lại kho chiêu (có thể vừa học chiêu mới)
  const skillsAfter = await getSessionSkills(sessionId);

  // Nếu đang ở nút thắt: lấy các lựa chọn của nút thắt để app hiển thị
  let plotPoint = null;
  if (atPlot) {
    const { rows: choices } = await query(
      `SELECT id, label FROM plot_point_choices WHERE plot_point_id = $1 ORDER BY order_index`,
      [nextPlot.id]
    );
    plotPoint = {
      id: nextPlot.id,
      title: nextPlot.title,
      description: nextPlot.description,
      choices,
    };
  }

  return {
    session_id: sessionId,
    chapter,
    mode: gen.mode,
    combat_info: gen.combatInfo,
    at_plot_point: !!atPlot,
    plot_point: plotPoint,
    skills: skillsAfter,
  };
}

// --- Helper: kho chiêu của phiên ---
async function getSessionSkills(sessionId) {
  const { rows } = await query(
    `SELECT id, name, description, source FROM session_skills
     WHERE session_id = $1 ORDER BY learned_at`,
    [sessionId]
  );
  return rows;
}

async function addSessionSkill(sessionId, skill) {
  if (!skill || !skill.name) return;
  await query(
    `INSERT INTO session_skills (session_id, name, description, source)
     VALUES ($1, $2, $3, 'learned')
     ON CONFLICT (session_id, name) DO NOTHING`,
    [sessionId, skill.name, skill.description || null]
  );
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
  const skills = await getSessionSkills(sessionId);
  return { session: srows[0], chapters, skills };
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

// Quay lại một nút thắt đã qua: xóa các chương sau chương-nút-thắt đó, cho chọn lại.
// chapterId: id của chương-nút-thắt muốn quay lại (chương có plot_point_id).
async function rewindToPlotPoint(userId, sessionId, chapterId) {
  // Xác thực session
  const { rows: srows } = await query(
    `SELECT * FROM play_sessions WHERE id = $1 AND user_id = $2`,
    [sessionId, userId]
  );
  if (!srows[0]) throw new ApiError(404, 'Không tìm thấy lượt chơi');
  const session = srows[0];

  // Lấy chương-nút-thắt
  const { rows: chRows } = await query(
    `SELECT * FROM story_chapters WHERE id = $1 AND session_id = $2`,
    [chapterId, sessionId]
  );
  if (!chRows[0]) throw new ApiError(404, 'Không tìm thấy chương');
  const chapter = chRows[0];
  if (!chapter.plot_point_id) {
    throw new ApiError(400, 'Chương này không phải nút thắt');
  }

  // Xóa tất cả chương SAU chương-nút-thắt này (giữ lại chính chương nút thắt)
  await query(
    `DELETE FROM story_chapters
     WHERE session_id = $1 AND chapter_number > $2`,
    [sessionId, chapter.chapter_number]
  );

  // Đặt lại current_plot_index về đúng nút thắt này
  const scenario = await scenarioService.getScenarioFull(session.story_id);
  const plotPoints = scenario.plot_points || [];
  const idx = plotPoints.findIndex(
    (p) => String(p.id) === String(chapter.plot_point_id)
  );
  const newIndex = idx >= 0 ? idx : 0;
  await query(
    `UPDATE play_sessions SET current_plot_index = $1 WHERE id = $2`,
    [newIndex, sessionId]
  );

  // Lấy các lựa chọn của nút thắt để app cho chọn lại
  const plot = plotPoints[newIndex] || null;
  let plotPoint = null;
  if (plot) {
    const { rows: choices } = await query(
      `SELECT id, label FROM plot_point_choices WHERE plot_point_id = $1 ORDER BY order_index`,
      [plot.id]
    );
    plotPoint = {
      id: plot.id,
      title: plot.title,
      description: plot.description,
      choices,
    };
  }

  return {
    session_id: sessionId,
    rewound_to_chapter: chapter.chapter_number,
    at_plot_point: true,
    plot_point: plotPoint,
  };
}

// --- Xuất bản / chia sẻ lượt chơi ---

// Bật/tắt hoặc cập nhật trạng thái xuất bản. publish=true -> công khai (hoặc cập nhật thời điểm);
// publish=false -> gỡ xuống. Trả về trạng thái mới.
async function setPublish(userId, sessionId, publish, shareTitle) {
  const { rows: own } = await query(
    `SELECT id FROM play_sessions WHERE id = $1 AND user_id = $2`,
    [sessionId, userId]
  );
  if (!own[0]) throw new ApiError(404, 'Không tìm thấy lượt chơi');

  if (publish) {
    const { rows } = await query(
      `UPDATE play_sessions
       SET is_published = TRUE, published_at = now(),
           share_title = COALESCE($1, share_title)
       WHERE id = $2
       RETURNING is_published, published_at, share_title`,
      [shareTitle || null, sessionId]
    );
    return rows[0];
  } else {
    const { rows } = await query(
      `UPDATE play_sessions SET is_published = FALSE WHERE id = $1
       RETURNING is_published, published_at, share_title`,
      [sessionId]
    );
    return rows[0];
  }
}

// Danh sách các lượt chơi đã xuất bản (công khai, mọi người xem được)
async function listPublished({ limit = 30, offset = 0 } = {}) {
  const { rows } = await query(
    `SELECT ps.id AS session_id,
            ps.story_id,
            COALESCE(ps.share_title, s.title) AS title,
            s.title AS story_title,
            s.cover_url,
            sc.mc_name,
            COALESCE(up.display_name, u.username) AS author_name,
            ps.published_at,
            COUNT(ch.id) AS chapter_count
     FROM play_sessions ps
     JOIN stories s ON s.id = ps.story_id
     LEFT JOIN session_character sc ON sc.session_id = ps.id
     LEFT JOIN users u ON u.id = ps.user_id
     LEFT JOIN user_profiles up ON up.user_id = ps.user_id
     LEFT JOIN story_chapters ch ON ch.session_id = ps.id
     WHERE ps.is_published = TRUE
     GROUP BY ps.id, s.title, s.cover_url, sc.mc_name, up.display_name, u.username
     ORDER BY ps.published_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset]
  );
  return rows;
}

// Xem chi tiết một lượt chơi công khai (chỉ đọc) — không cần là chủ
async function getPublishedPlaythrough(sessionId) {
  const { rows: srows } = await query(
    `SELECT ps.id, ps.story_id, ps.is_published,
            COALESCE(ps.share_title, s.title) AS title,
            s.title AS story_title,
            sc.mc_name,
            COALESCE(up.display_name, u.username) AS author_name,
            ps.published_at
     FROM play_sessions ps
     JOIN stories s ON s.id = ps.story_id
     LEFT JOIN session_character sc ON sc.session_id = ps.id
     LEFT JOIN users u ON u.id = ps.user_id
     LEFT JOIN user_profiles up ON up.user_id = ps.user_id
     WHERE ps.id = $1`,
    [sessionId]
  );
  if (!srows[0] || !srows[0].is_published) {
    throw new ApiError(404, 'Lượt chơi này chưa được chia sẻ');
  }

  const { rows: chapters } = await query(
    `SELECT id, chapter_number, content, chosen_direction, mode
     FROM story_chapters WHERE session_id = $1 ORDER BY chapter_number`,
    [sessionId]
  );
  return { info: srows[0], chapters };
}

// Quay lại một trận combat đã qua: xóa các chương sau chương-đầu-trận để đánh lại.
// chapterId: id của chương đầu trận (is_combat_start = true).
async function rewindToCombat(userId, sessionId, chapterId) {
  const { rows: srows } = await query(
    `SELECT * FROM play_sessions WHERE id = $1 AND user_id = $2`,
    [sessionId, userId]
  );
  if (!srows[0]) throw new ApiError(404, 'Không tìm thấy lượt chơi');

  const { rows: chRows } = await query(
    `SELECT * FROM story_chapters WHERE id = $1 AND session_id = $2`,
    [chapterId, sessionId]
  );
  if (!chRows[0]) throw new ApiError(404, 'Không tìm thấy chương');
  const chapter = chRows[0];
  if (!chapter.is_combat_start) {
    throw new ApiError(400, 'Chương này không phải đầu trận chiến đấu');
  }

  // Xóa tất cả chương SAU chương-đầu-trận (giữ lại chính chương đầu trận)
  await query(
    `DELETE FROM story_chapters
     WHERE session_id = $1 AND chapter_number > $2`,
    [sessionId, chapter.chapter_number]
  );

  return {
    session_id: sessionId,
    rewound_to_chapter: chapter.chapter_number,
    mode: 'combat',
  };
}

module.exports = { startPlay, continuePlay, getPlaythrough, listMySessions, deleteSessionsByStory, rewindToPlotPoint, rewindToCombat, setPublish, listPublished, getPublishedPlaythrough };