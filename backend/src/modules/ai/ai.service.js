// Gọi Claude (Anthropic) để sinh chương truyện + lựa chọn cuối chương
const Anthropic = require('@anthropic-ai/sdk');
require('dotenv').config();

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const MODEL = process.env.ANTHROPIC_MODEL || 'claude-haiku-4-5';

// --- Công tắc tiết kiệm chi phí (đặt trong .env) ---
const MOCK_MODE = process.env.AI_MOCK_MODE === 'true';
const CHAPTER_WORDS = parseInt(process.env.AI_CHAPTER_WORDS || '1500', 10);
console.log('>>> AI_MOCK_MODE =', process.env.AI_MOCK_MODE, '| MOCK bật:', MOCK_MODE);

const RECENT_CHAPTERS_WINDOW = 2;
const SUMMARY_MAX_CHARS = 500;

function buildWorldContext(scenario) {
  const w = scenario.world || {};
  const lines = [`Tiêu đề: ${scenario.title}`];
  if (w.world_setting) lines.push(`Bối cảnh: ${w.world_setting}`);
  if (w.protagonist_role) lines.push(`Thân phận NV chính: ${w.protagonist_role}`);
  if (w.enemy_description) lines.push(`Kẻ thù: ${w.enemy_description}`);
  if (w.final_goal) lines.push(`Mục tiêu cuối: ${w.final_goal}`);
  if (scenario.key_characters?.length) {
    const chars = scenario.key_characters
      .map((kc) => `${kc.name} (${kc.role})`)
      .join('; ');
    lines.push(`Nhân vật quan trọng: ${chars}`);
  }
  if (scenario.xh) {
    if (scenario.xh.cultivation_note)
      lines.push(`Tu luyện: ${scenario.xh.cultivation_note}`);
    if (scenario.xh.realms?.length)
      lines.push('Cảnh giới: ' + scenario.xh.realms.map((r) => r.name).join(' < '));
  }
  if (scenario.fnt) {
    if (scenario.fnt.magic_system)
      lines.push(`Ma pháp: ${scenario.fnt.magic_system}`);
    if (scenario.fnt.classes?.length)
      lines.push('Lớp nhân vật: ' + scenario.fnt.classes.map((c) => c.name).join(', '));
    if (scenario.fnt.races?.length)
      lines.push('Chủng tộc: ' + scenario.fnt.races.map((r) => r.name).join(', '));
  }
  return lines.join('\n');
}

// Tạo chương GIẢ để test UI mà không tốn token
function mockChapter({ mcName, previousChapters, direction }) {
  const n = (previousChapters?.length || 0) + 1;
  const lead = direction
    ? `Sau khi quyết định "${direction}", ${mcName} tiếp tục cuộc hành trình.`
    : `${mcName} mở đầu câu chuyện của mình.`;
  const body =
    `[CHƯƠNG GIẢ ${n} — chế độ test, không gọi AI] ${lead} ` +
    'Đây là nội dung mẫu dùng để kiểm tra giao diện. '.repeat(8);
  return {
    content: body.trim(),
    options: [
      'Tiến về phía trước khám phá',
      'Dừng lại quan sát xung quanh',
      'Quay lại tìm manh mối',
    ],
    tokenUsed: 0,
  };
}

// Hướng dẫn văn phong riêng theo thể loại
function buildStyleGuide(scenario) {
  const genreNames = (scenario.genres || []).map((g) => g.name || g).join(', ');
  const isXianxia = genreNames.includes('Tiên hiệp');
  const isFantasy = genreNames.includes('Fantasy');

  if (isXianxia) {
    return `VĂN PHONG TIÊN HIỆP:
- Dùng từ thuần Việt hoặc Hán Việt, TUYỆT ĐỐI KHÔNG chêm tiếng Anh hay phiên âm pinyin. Ví dụ: viết "đan điền" (KHÔNG viết "dantian"), "linh khí" (KHÔNG viết "qi"), "áo vải" (KHÔNG viết "linen").
- Giọng văn cổ phong, trang trọng, giàu hình ảnh tu tiên: cảnh giới, linh khí, kiếm ý, đạo tâm.
- QUY TẮC XƯNG HÔ (rất quan trọng, phải đúng vai vế, KHÔNG dùng đại từ hiện đại như "tôi", "cậu", "bạn"):
  + Bậc trên (sư phụ, trưởng bối, người lớn tuổi) khi tự xưng dùng "ta"; gọi người dưới là "ngươi" hoặc "con".
  + Bậc dưới (đệ tử, vãn bối) khi tự xưng dùng "con", "đệ tử" hoặc "tại hạ"; gọi bậc trên là "sư phụ", "tiền bối".
  + Người kể chuyện gọi nhân vật lớn tuổi/bậc trên là "ông", "lão", "vị" (KHÔNG gọi là "cậu", "anh ấy"). Nhân vật trẻ tuổi mới gọi là "chàng", "nàng", "cậu".
  + Người ngang hàng xưng "ta" gọi "ngươi" hoặc "đạo hữu".
- Ví dụ đúng: Sư phụ nói với đệ tử: "Ngươi đã sẵn sàng chưa? Ta sẽ truyền cho ngươi tâm pháp." Người kể: "Lão chậm rãi nâng tay."`;
  }
  if (isFantasy) {
    return `VĂN PHONG FANTASY:
- Viết bằng tiếng Việt tự nhiên. CHỈ giữ nguyên tiếng Anh cho TÊN RIÊNG (tên người, địa danh, vương quốc), ví dụ "Eldoria", "Arthur". Mọi từ khác phải dịch sang tiếng Việt: viết "áo choàng" (KHÔNG viết "cloak"), "pháp sư" (KHÔNG viết "mage").
- Giọng văn sử thi phương Tây, phiêu lưu, kỳ ảo.
- Xưng hô nhất quán theo vai vế: bậc trên/lớn tuổi tự xưng "ta" gọi người dưới "ngươi" hoặc "con"; người kể gọi nhân vật lớn tuổi là "ông", "bà", "lão". Tránh dùng lẫn lộn "tôi"/"cậu" theo lối hiện đại trong lời thoại trang trọng.`;
  }
  return '';
}

// Sinh một chương. Trả về { content, options, summary, tokenUsed }
async function generateChapter({ scenario, mcName, previousChapters, direction, runningSummary }) {
  // Chế độ giả lập: trả ngay, KHÔNG gọi Claude
  if (MOCK_MODE) {
    return mockChapter({ mcName, previousChapters, direction });
  }

  const worldContext = buildWorldContext(scenario);
  const styleGuide = buildStyleGuide(scenario);
  // TỐI ƯU TOKEN #2: system prompt ngắn gọn, không lặp lại mỗi field dài dòng.
  const systemPrompt = `Bạn là người kể chuyện cho tiểu thuyết tương tác nhập vai, viết bằng tiếng Việt, văn phong cuốn hút.
Mỗi chương khoảng ${CHAPTER_WORDS} từ. Nhân vật chính tên "${mcName}", người đọc nhập vai vào nhân vật này.

${styleGuide}

QUY TẮC VẬT PHẨM: Khi một vật phẩm quan trọng xuất hiện lần đầu, giải thích tác dụng ngay sau dấu gạch ngang. Ví dụ: "Tụ Linh Đan - đan dược giúp hồi phục linh lực nhanh chóng" hoặc "Kiếm Hàn Băng - thanh kiếm tỏa hàn khí, chém đứt mọi giáp trụ".

Bám sát bối cảnh sau:
${worldContext}

Chỉ trả về JSON đúng cấu trúc, không thêm lời dẫn:
{"content":"<nội dung chương>","options":["<hướng đi 1>","<hướng đi 2>","<hướng đi 3>"],"summary":"<tóm tắt tích lũy cập nhật>"}
- options: BẮT BUỘC có ĐÚNG 2 đến 4 hướng đi, mỗi hướng đi là một câu ngắn gọn (KHÔNG dùng dấu phẩy bên trong mỗi hướng đi). Đây là các lựa chọn cho chương kế tiếp.
- summary: bản tóm tắt NGẮN GỌN (tối đa 200 từ) toàn bộ diễn biến truyện TÍNH ĐẾN HẾT chương vừa viết, gồm các tình tiết, nhân vật, vật phẩm, mâu thuẫn quan trọng để giữ mạch truyện nhất quán. Cập nhật từ tóm tắt cũ (nếu có) bằng cách bổ sung diễn biến mới, không bỏ sót điều cũ quan trọng.`;

  const messages = [];

  // Bản tóm tắt tích lũy (toàn bộ quá khứ, cô đọng) — giúp AI nhớ truyện dài
  if (runningSummary && runningSummary.trim()) {
    messages.push({
      role: 'user',
      content: `Tóm tắt toàn bộ diễn biến truyện từ đầu đến nay:\n${runningSummary}`,
    });
    messages.push({ role: 'assistant', content: 'Tôi đã nắm toàn bộ mạch truyện.' });
  }

  // TỐI ƯU TOKEN #3: chỉ đưa N chương GẦN NHẤT nguyên văn (giữ giọng văn liền mạch).
  if (previousChapters?.length) {
    const recent = previousChapters.slice(-RECENT_CHAPTERS_WINDOW);
    const recentText = recent
      .map(
        (c) =>
          `Chương ${c.chapter_number}: ${c.content.slice(0, SUMMARY_MAX_CHARS)}`
      )
      .join('\n\n');
    messages.push({
      role: 'user',
      content: `Nội dung ${recent.length} chương gần nhất:\n${recentText}`,
    });
    messages.push({ role: 'assistant', content: 'Đã nắm được diễn biến gần đây.' });
  }
  messages.push({
    role: 'user',
    content: direction
      ? `Người chơi chọn: "${direction}". Viết chương tiếp theo.`
      : 'Viết Chương 1 mở đầu.',
  });

  // Mồi assistant bắt đầu bằng '{' để Claude trả thẳng JSON, không bọc ```json
  messages.push({ role: 'assistant', content: '{' });

  // TỐI ƯU TOKEN #4: max_tokens đủ dư để JSON không bị cắt.
  const maxTokens = Math.round(CHAPTER_WORDS * 2.5) + 800;
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: maxTokens,
    temperature: 0.9,
    system: systemPrompt,
    messages,
  });

  const raw = response.content.find((b) => b.type === 'text')?.text || '';
  // Đã mồi assistant bằng '{' nên response thiếu dấu mở đầu -> ghép lại
  const fullJson = raw.trim().startsWith('{') ? raw : '{' + raw;
  const parsed = safeParseJson(fullJson);
  const tokenUsed =
    (response.usage?.input_tokens || 0) + (response.usage?.output_tokens || 0);

  // Đảm bảo 2-4 hướng đi: bỏ rỗng/trùng, cắt còn tối đa 4
  let cleanOptions = (parsed.options || [])
    .map((o) => (o || '').toString().trim())
    .filter((o) => o.length > 0);
  // Bỏ trùng lặp
  cleanOptions = [...new Set(cleanOptions)];
  // Tối đa 4
  cleanOptions = cleanOptions.slice(0, 4);

  return {
    content: parsed.content || '',
    options: cleanOptions,
    summary: parsed.summary || '',
    tokenUsed,
  };
}

// Claude đôi khi bọc JSON trong ```json ... ``` hoặc trả JSON bị cắt.
// Hàm này cố parse; nếu hỏng thì bóc riêng content/options để không hiện JSON thô.
function safeParseJson(text) {
  let t = text.trim();

  const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) t = fence[1].trim();

  try {
    const obj = JSON.parse(t);
    return { content: obj.content || '', options: obj.options || [], summary: obj.summary || '' };
  } catch {
    /* tiếp tục bóc thủ công */
  }

  const brace = t.match(/\{[\s\S]*\}/);
  if (brace) {
    try {
      const obj = JSON.parse(brace[0]);
      return { content: obj.content || '', options: obj.options || [], summary: obj.summary || '' };
    } catch {
      /* rơi xuống bóc regex */
    }
  }

  // PHƯƠNG ÁN CUỐI: bóc riêng content/options bằng regex (kể cả khi JSON bị cắt)
  let content = '';
  const cMatch = t.match(/"content"\s*:\s*"([\s\S]*?)"\s*(?:,\s*"options"|\})/) ||
                 t.match(/"content"\s*:\s*"([\s\S]*)/);
  if (cMatch) {
    content = cMatch[1].replace(/"\s*$/, '');
  } else {
    content = t.replace(/```json|```|^\s*\{|\}\s*$/g, '').trim();
  }
  content = content
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/\\t/g, '  ')
    .trim();

  let options = [];
  const oMatch = t.match(/"options"\s*:\s*\[([\s\S]*?)\]/);
  if (oMatch) {
    // Bóc từng chuỗi nằm trong dấu ngoặc kép (tránh tách nhầm khi option có dấu phẩy)
    const items = oMatch[1].match(/"((?:[^"\\]|\\.)*)"/g) || [];
    options = items
      .map((s) => s.slice(1, -1).replace(/\\"/g, '"').replace(/\\n/g, ' ').trim())
      .filter((s) => s.length > 0);
  }

  // Bóc summary nếu có (regex, chịu được JSON cắt)
  let summary = '';
  const sMatch = t.match(/"summary"\s*:\s*"([\s\S]*?)"\s*\}?\s*$/) ||
                 t.match(/"summary"\s*:\s*"([\s\S]*)/);
  if (sMatch) {
    summary = sMatch[1]
      .replace(/"\s*\}?\s*$/, '')
      .replace(/\\n/g, '\n')
      .replace(/\\"/g, '"')
      .trim();
  }

  return { content, options, summary };
}

module.exports = { generateChapter, buildWorldContext };