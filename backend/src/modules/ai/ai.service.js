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
      lines.push('Class: ' + scenario.fnt.classes.map((c) => c.name).join(', '));
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

  const maxTokens = Math.round(CHAPTER_WORDS * 1.8) + 300;
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: maxTokens,
    temperature: 0.9,
    system: systemPrompt,
    messages,
  });

  const raw = response.content.find((b) => b.type === 'text')?.text || '';
  const parsed = safeParseJson(raw);
  const tokenUsed =
    (response.usage?.input_tokens || 0) + (response.usage?.output_tokens || 0);

  return {
    content: parsed.content || '',
    options: parsed.options || [],
    tokenUsed,
  };
}

function safeParseJson(text) {
  let t = text.trim();
  const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) t = fence[1].trim();
  try {
    return JSON.parse(t);
  } catch {
    const brace = t.match(/\{[\s\S]*\}/);
    if (brace) {
      try {
        return JSON.parse(brace[0]);
      } catch {
        /* rơi xuống */
      }
    }
    return { content: t, options: [] };
  }
}

module.exports = { generateChapter, buildWorldContext };