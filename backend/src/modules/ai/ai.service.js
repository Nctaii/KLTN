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

async function generateChapter({ scenario, mcName, previousChapters, direction }) {
  // Chế độ giả lập: trả ngay, KHÔNG gọi Claude
  if (MOCK_MODE) {
    return mockChapter({ mcName, previousChapters, direction });
  }

  const worldContext = buildWorldContext(scenario);
  const systemPrompt = `Bạn là người kể chuyện cho tiểu thuyết tương tác nhập vai, viết bằng tiếng Việt, văn phong cuốn hút.
Mỗi chương khoảng ${CHAPTER_WORDS} từ. Nhân vật chính tên "${mcName}", người đọc nhập vai vào nhân vật này.
Bám sát bối cảnh sau:
${worldContext}

Chỉ trả về JSON đúng cấu trúc, không thêm lời dẫn:
{"content":"<nội dung chương>","options":["<hướng đi 1>","<hướng đi 2>","<hướng đi 3>"]}
options là 2-4 hướng đi ngắn gọn cho chương kế tiếp.`;

  const messages = [];
  if (previousChapters?.length) {
    const recent = previousChapters.slice(-RECENT_CHAPTERS_WINDOW);
    const summary = recent
      .map((c) => `Chương ${c.chapter_number}: ${c.content.slice(0, SUMMARY_MAX_CHARS)}`)
      .join('\n\n');
    messages.push({ role: 'user', content: `Tóm tắt diễn biến gần đây:\n${summary}` });
    messages.push({ role: 'assistant', content: 'Đã nắm được mạch truyện.' });
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
  // Tiếng Việt ~2 token/từ; cộng đệm cho phần options + cấu trúc JSON.
  const maxTokens = Math.round(CHAPTER_WORDS * 2.5) + 600;
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

  return {
    content: parsed.content || '',
    options: parsed.options || [],
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
    return { content: obj.content || '', options: obj.options || [] };
  } catch {
    /* tiếp tục bóc thủ công */
  }

  const brace = t.match(/\{[\s\S]*\}/);
  if (brace) {
    try {
      const obj = JSON.parse(brace[0]);
      return { content: obj.content || '', options: obj.options || [] };
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
    options = oMatch[1]
      .split(',')
      .map((s) => s.trim().replace(/^"|"$/g, '').replace(/\\"/g, '"'))
      .filter((s) => s.length > 0);
  }

  return { content, options };
}

module.exports = { generateChapter, buildWorldContext };