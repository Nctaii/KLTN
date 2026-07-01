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
    if (scenario.xh.mc_spirit_root)
      lines.push(`Linh căn/thể chất NV chính: ${scenario.xh.mc_spirit_root}`);
    if (scenario.xh.sects?.length) {
      const chinh = scenario.xh.sects.filter((s) => s.faction !== 'ta');
      const ta = scenario.xh.sects.filter((s) => s.faction === 'ta');
      if (chinh.length)
        lines.push(
          'Tông môn chính phái: ' +
            chinh.map((s) => (s.standing ? `${s.name} (${s.standing})` : s.name)).join('; ')
        );
      if (ta.length)
        lines.push(
          'Thế lực tà phái: ' +
            ta.map((s) => (s.standing ? `${s.name} (${s.standing})` : s.name)).join('; ')
        );
    }
    if (scenario.xh.techniques?.length)
      lines.push(
        'Công pháp đặc trưng: ' +
          scenario.xh.techniques
            .map((t) => (t.specialty ? `${t.name} [${t.specialty}]` : t.name))
            .join('; ')
      );
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
- ĐẠI TỪ NGƯỜI KỂ CHUYỆN gọi nhân vật (phải NHẤT QUÁN suốt truyện, không đổi qua lại):
  + Nhân vật chính là NAM: người kể gọi là "hắn" (mặc định cho tiên hiệp/kiếm hiệp). KHÔNG dùng "chàng" cho nhân vật chính nam trừ khi đang trong cảnh tình cảm/lãng mạn rõ rệt và truyện đã phát triển tuyến tình cảm. KHÔNG dùng "cậu", "anh ấy".
  + Nhân vật chính là NỮ: người kể gọi là "nàng" hoặc "cô". KHÔNG dùng "cô ấy" theo lối hiện đại.
  + Nhân vật phụ lớn tuổi/bậc trên: "ông", "lão", "vị", "bà".
  + Nhân vật phụ trẻ: "hắn"/"y" (nam), "nàng"/"cô" (nữ), hoặc gọi thẳng tên.
  + QUY TẮC NHẤT QUÁN: một khi đã chọn đại từ cho một nhân vật, phải giữ nguyên đại từ đó xuyên suốt, KHÔNG đổi "hắn" thành "chàng" rồi lại "hắn" trong cùng mạch truyện. "Chàng"/"nàng" chỉ dùng thay thế khi giọng văn cố ý trữ tình ở cảnh tình cảm.
- QUY TẮC XƯNG HÔ (CỰC KỲ QUAN TRỌNG — sai xưng hô là lỗi nghiêm trọng nhất). KHÔNG BAO GIỜ dùng "tôi", "cậu", "bạn", "anh ấy", "cô ấy" trong lời thoại. Tuân thủ chính xác theo từng quan hệ:
  • Nói với SƯ PHỤ / TRƯỞNG BỐI / bậc cha chú: tự xưng "đệ tử" hoặc "con"; gọi đối phương "sư phụ", "sư tôn", "tiền bối".
  • Nói với SƯ HUYNH / SƯ TỶ (đồng môn vai trên, cùng thế hệ): tự xưng "đệ" hoặc "muội"; gọi đối phương "sư huynh", "sư tỷ". ⚠ TUYỆT ĐỐI KHÔNG xưng "con" và KHÔNG gọi "cậu" với sư huynh/sư tỷ.
  • SƯ HUYNH / SƯ TỶ nói với sư đệ/sư muội: tự xưng "sư huynh"/"sư tỷ" hoặc "ta"; gọi đối phương "sư đệ", "sư muội", "đệ", "muội". ⚠ KHÔNG gọi sư đệ là "con" hay "cậu".
  • Nói với người NGANG HÀNG / người lạ: tự xưng "ta"; gọi "ngươi", "các hạ", "đạo hữu".
  • Nói với KẺ ĐỊCH: tự xưng "ta"; gọi "ngươi".
  • Người kể chuyện gọi nhân vật: bậc trên/lớn tuổi là "ông", "lão", "vị"; người trẻ là "chàng", "nàng", hoặc gọi thẳng tên. KHÔNG dùng "cậu", "anh ấy", "cô ấy".
  • Tự kiểm tra: "con" CHỈ xuất hiện khi nhân vật nói với cha/mẹ/sư phụ/trưởng bối thật sự. Nếu thấy "con" trong câu nói với sư huynh, sư tỷ, hay người ngang hàng → SAI, phải sửa ngay.
- QUY TẮC DÙNG TỪ (bắt buộc): 
  + chỉ dùng từ tiếng Việt và Hán Việt CÓ THẬT, đúng nghĩa, đúng chính tả. TUYỆT ĐỐI KHÔNG bịa từ lạ, không ghép từ vô nghĩa, không dùng từ ngọng/sai chính tả.
  + CẤM tuyệt đối các từ hiện đại, thương mại, đời thường không hợp bối cảnh cổ trang, ví dụ: "chính hãng", "chất lượng", "combo", "ok", "deal", "dép", "trọ" (theo nghĩa nhà trọ hiện đại). Thay bằng từ cổ phong tương đương.
  + Đồ ăn, vật phẩm phải đúng bối cảnh tiên hiệp cổ trang: dùng "lương khô", "bánh bao", "điểm tâm", "đan dược", "linh thảo"... KHÔNG dùng tên món ăn hiện đại hay từ vô nghĩa.
  + Nếu không chắc một từ có đúng và hợp cổ phong hay không, hãy chọn một từ đơn giản, phổ thông, chắc chắn đúng thay vì một từ hoa mỹ nhưng có thể sai.
  + Trước khi kết thúc, hãy đọc lại nội dung một lượt: bảo đảm không có từ sai chính tả, không có từ vô nghĩa, không có đại từ hiện đại trong lời thoại.

VÍ DỤ VĂN PHONG MẪU (hãy viết theo đúng giọng văn, nhịp câu, cách dùng từ và lối xưng hô như các đoạn dưới đây. Văn phải TRONG SÁNG, DỄ HIỂU, câu không rườm rà tối nghĩa):

[Tả cảnh thiên nhiên]: "Bình minh vừa ló, sương sớm còn giăng kín đỉnh Thanh Vân. Lăng Vân đứng trên vách đá, phóng tầm mắt nhìn biển mây cuộn dưới chân. Gió sớm mang theo hơi lạnh, thổi tung tà áo xanh bạc màu của hắn. Xa xa, tiếng chuông sớm từ đại điện vọng lại, ngân nga giữa núi rừng tĩnh mịch. Hắn hít một hơi sâu, linh khí trong trẻo tràn vào lồng ngực, tâm cũng theo đó mà lắng xuống."

[Tu luyện]: "Lăng Vân ngồi xếp bằng, hai tay kết ấn, chậm rãi dẫn linh khí đi theo chu thiên. Chân khí như dòng suối nhỏ, men theo kinh mạch chảy về đan điền, từng vòng từng vòng ngưng tụ. Hắn cảm nhận rõ một luồng ấm áp lan tỏa khắp tứ chi. Tu luyện không thể nóng vội — hắn hiểu rõ điều đó. Mỗi ngày tích lũy một chút, như nước chảy đá mòn, rồi sẽ có ngày bứt phá."

[Hội thoại với sư phụ/trưởng bối]: "Lăng Thiên Tuyệt vuốt chòm râu bạc, ánh mắt thâm trầm nhìn hắn. 'Con đường tu tiên gian nan hiểm trở, một bước sai có thể vạn kiếp bất phục,' lão chậm rãi nói. 'Con có hối hận khi chọn con đường này không?' Lăng Vân chắp tay, cúi đầu cung kính: 'Đệ tử không hối hận. Dù trước mặt là núi đao biển lửa, đệ tử cũng quyết đi tới cùng.' Lão nhân khẽ gật đầu, trong mắt thoáng vẻ hài lòng."

[Hội thoại với sư huynh/sư tỷ - xưng "đệ"/"sư tỷ", KHÔNG xưng "con"]: "Tô Tịnh Nhi bước tới, khẽ phủi lớp bụi trên vai hắn. 'Sư đệ lại luyện công thâu đêm rồi,' nàng dịu giọng, ánh mắt lo lắng. 'Thân thể là gốc rễ của đạo, đệ đừng ép mình quá.' Lăng Vân mỉm cười: 'Đa tạ sư tỷ quan tâm. Đệ chỉ sợ tư chất kém cỏi, theo không kịp mọi người.' Tô Tịnh Nhi lắc đầu: 'Sư tỷ tin đệ. Cứ kiên trì, ắt có ngày thành tựu.'"

[Chiến đấu]: "Kiếm quang lóe lên, xé toạc màn đêm như một đạo bạch hồng. Lăng Vân vung kiếm, chân khí dồn vào lưỡi thép, đâm thẳng tới trước. Đối thủ áo đen cười lạnh, vung tay phách ra một đạo hắc khí chống đỡ. Hai luồng lực va chạm, tiếng nổ vang dội, đá vụn bắn tung tóe. Lăng Vân lùi lại ba bước, khóe miệng rỉ máu, nhưng ánh mắt vẫn kiên định. 'Chỉ bấy nhiêu thôi sao?' hắn quát khẽ, nâng kiếm xông lên lần nữa."

[Nội tâm, cảm xúc]: "Đứng trước mộ phần sư phụ, Lăng Vân lặng người hồi lâu. Năm xưa lão nhân nhặt hắn về từ khe núi, dạy hắn từng đường kiếm, từng câu khẩu quyết. Giờ đây chỉ còn lại nấm đất lạnh lẽo phủ rêu xanh. Lòng hắn quặn thắt, nhưng hắn không cho phép mình gục ngã. Người tu tiên phải giữ vững đạo tâm. Hắn quỳ xuống, dập đầu ba cái, thầm khắc ghi: mối thù này, kiếp này nhất định phải báo."`;
  }
  if (isFantasy) {
    return `VĂN PHONG FANTASY:
- Viết bằng tiếng Việt tự nhiên. CHỈ giữ nguyên tiếng Anh cho TÊN RIÊNG (tên người, địa danh, vương quốc), ví dụ "Eldoria", "Arthur". Mọi từ khác phải dịch sang tiếng Việt: viết "áo choàng" (KHÔNG viết "cloak"), "pháp sư" (KHÔNG viết "mage").
- Giọng văn sử thi phương Tây, phiêu lưu, kỳ ảo.
- Xưng hô nhất quán theo vai vế: bậc trên/lớn tuổi tự xưng "ta" gọi người dưới "ngươi" hoặc "con"; người kể gọi nhân vật lớn tuổi là "ông", "bà", "lão". Tránh dùng lẫn lộn "tôi"/"cậu" theo lối hiện đại trong lời thoại trang trọng.

VÍ DỤ VĂN PHONG MẪU (hãy viết theo đúng giọng văn, nhịp câu và cách dùng từ như các đoạn dưới đây):

[Tả cảnh, mở đầu]: "Sương mù phủ kín thung lũng Aldermere khi bình minh vừa ló rạng. Elena siết chặt cây trượng gỗ sồi, lần bước theo con đường mòn dẫn lên tu viện cổ. Những tàn tích rêu phong hiện ra trong màn sương, từng phiến đá khắc đầy ký tự cổ đã mờ theo năm tháng. Trong không khí thoảng mùi ẩm mục của lá rừng, và một thứ gì đó khác — hơi lạnh của phép thuật xa xưa còn vương vất, khiến gáy nàng dựng lên."

[Hội thoại với bậc thầy]: "Vị pháp sư già chống trượng bước ra từ bóng tối, đôi mắt ánh lên màu lam kỳ lạ. 'Con đã đi một quãng đường dài, Elena ạ,' ông nói, giọng trầm như tiếng chuông xa. 'Nhưng con đường phía trước còn hiểm trở hơn nhiều. Sức mạnh trong con đang thức tỉnh — và bóng tối cũng đã ngửi thấy nó. Con phải học cách làm chủ nó, trước khi nó làm chủ con.' Elena nuốt khan, nắm tay siết chặt: 'Vậy xin thầy dạy con. Con không sợ.'"

[Hành động, chiến đấu]: "Tiếng gầm của con quái thú vang dội khắp khu rừng Thornwood. Elena lăn người tránh cú vồ, cây trượng trong tay bừng sáng một quầng lửa. 'Lui lại!' nàng hét lớn, đẩy luồng phép thuật về phía trước. Ngọn lửa cuộn xoáy lao đi, nhưng con thú chỉ gầm gừ, lớp da đen sạm của nó nuốt chửng ánh sáng. Tim Elena đập thình thịch. Phép thuật thông thường vô dụng — nàng cần thứ gì đó mạnh hơn, thứ mà thầy nàng từng cảnh báo chớ bao giờ động tới."

[Nội tâm, cảm xúc]: "Đêm ấy, Elena ngồi một mình bên đống lửa tàn, ngắm những tia lửa bay lên hòa vào màn đêm. Nàng nghĩ về ngôi làng đã mất, về gương mặt những người thân giờ chỉ còn trong ký ức. Con đường nàng chọn không có lối quay đầu. Nhưng kỳ lạ thay, giữa nỗi cô đơn ấy, nàng cảm thấy một điều gì đó cứng cỏi đang lớn dần trong lồng ngực — không phải lòng thù hận, mà là quyết tâm. Nàng sẽ mạnh mẽ. Nàng phải mạnh mẽ."`;
  }
}

// Sinh một chương. Trả về { content, options, summary, tokenUsed }
async function generateChapter({ scenario, mcName, previousChapters, direction, runningSummary, personality, skills, chosenSkill, mode, plotContext }) {
  // Chế độ giả lập: trả ngay, KHÔNG gọi Claude
  if (MOCK_MODE) {
    return mockChapter({ mcName, previousChapters, direction });
  }

  const worldContext = buildWorldContext(scenario);
  const styleGuide = buildStyleGuide(scenario);
  const personalityGuide = personality
    ? `\nTÍNH CÁCH NHÂN VẬT CHÍNH: ${personality}. Hãy thể hiện rõ tính cách này qua hành động, quyết định và lời thoại của nhân vật chính "${mcName}" xuyên suốt câu chuyện.`
    : '';

  // Danh sách chiêu thức hiện có của nhân vật (nếu có)
  const skillList = (skills || [])
    .map((s) => (s.description ? `${s.name} (${s.description})` : s.name))
    .join('; ');
  const skillGuide = skillList
    ? `\nCHIÊU THỨC NHÂN VẬT ĐÃ HỌC: ${skillList}.`
    : '';

  const combatGuide = `
CƠ CHẾ CHIẾN ĐẤU (rất quan trọng):
- Khi câu chuyện dẫn tới một trận giao tranh quan trọng (cao trào), hãy chuyển sang chế độ chiến đấu bằng cách đặt "mode":"combat".
- Trong chế độ chiến đấu: MỖI CHƯƠNG mô tả MỘT đòn giao tranh. Nếu người chơi vừa chọn một chiêu thức, hãy mô tả sinh động nhân vật "${mcName}" thi triển chiêu đó, đòn ấy tác động lên kẻ địch ra sao, gây thương tích gì.
- Kết quả của đòn đánh PHẢI phụ thuộc vào chiêu người chơi chọn so với tình huống: chiêu phù hợp và mạnh thì áp đảo; chiêu không phù hợp hoặc yếu thì có thể bị kẻ địch phản đòn, nhân vật bị thương hoặc lâm nguy. KHÔNG phải lúc nào người chơi cũng thắng.
- Cuối mỗi chương chiến đấu (khi vẫn "mode":"combat"), điền "combat_info" mô tả NGẮN GỌN đòn phản công mà kẻ địch sắp tung ra (dùng làm gợi ý cho chương kế).
- Khi trận đấu ngã ngũ (một bên thắng/thua/bỏ chạy/bị trọng thương), đặt lại "mode":"normal" và viết kết cục trận đấu. Kết cục phải phản ánh các lựa chọn chiêu thức trước đó của người chơi (thắng vẻ vang, thắng nhưng trọng thương, thua phải bỏ chạy...).
- KHI nhân vật học được một chiêu thức MỚI một cách hợp tình tiết (được truyền thụ, đột phá, lĩnh ngộ...), điền "learned_skill" gồm name và description (mô tả ngắn 10-20 từ). Chỉ cho học chiêu khi thật hợp lý, KHÔNG cho học liên tục.`;

  // Hướng dẫn nút thắt: chỉ kích hoạt khi đã đủ số chương tối thiểu (plotContext được truyền vào)
  const plotGuide = plotContext
    ? `
CƠ CHẾ NÚT THẮT CỐT TRUYỆN (quan trọng):
- Câu chuyện đang tiến tới một nút thắt quan trọng: "${plotContext.title}"${plotContext.description ? ` — ${plotContext.description}` : ''}.
- Hãy dẫn dắt câu chuyện một cách tự nhiên tiến dần về phía tình huống nút thắt này.
- KHI tình tiết đã chín muồi và câu chuyện vừa đến đúng thời điểm của nút thắt đó, hãy đặt "at_plot_point":true và kết chương ngay tại khoảnh khắc nhân vật phải đưa ra quyết định lớn (KHÔNG tự quyết thay người chơi). Khi đó để "options" là mảng rỗng [] vì người chơi sẽ chọn từ các hướng đi đã định sẵn.
- Nếu CHƯA tới thời điểm hợp lý, cứ tiếp tục dẫn truyện bình thường với "at_plot_point":false và đưa ra options như thường lệ.`
    : '';

  // PHẦN CỐ ĐỊNH cho cả phiên chơi (không đổi giữa các chương) -> được cache
  const systemStatic = `Bạn là người kể chuyện cho tiểu thuyết tương tác nhập vai, viết bằng tiếng Việt, văn phong cuốn hút, trôi chảy, hợp ngữ cảnh và không bị lủng củng.
Mỗi chương khoảng ${CHAPTER_WORDS} từ. Nhân vật chính tên "${mcName}", người đọc nhập vai vào nhân vật này.

${styleGuide}
${combatGuide}

QUY TẮC VẬT PHẨM: Khi một vật phẩm quan trọng xuất hiện lần đầu, giải thích tác dụng ngay sau dấu gạch ngang. Ví dụ: "Tụ Linh Đan - đan dược giúp hồi phục linh lực nhanh chóng" hoặc "Kiếm Hàn Băng - thanh kiếm tỏa hàn khí, chém đứt mọi giáp trụ".
LƯU Ý CUỐI: trước khi xuất kết quả, hãy tự rà soát nội dung chương để đảm bảo: (1) không sai chính tả, không có từ vô nghĩa; (2) xưng hô đúng vai vế trong mọi lời thoại; (3) không lẫn từ hiện đại. Sửa hết lỗi rồi mới xuất JSON.

Bám sát bối cảnh sau:
${worldContext}

Chỉ trả về JSON đúng cấu trúc, không thêm lời dẫn:
{"content":"<nội dung chương>","options":["<hướng đi 1>","<hướng đi 2>"],"summary":"<tóm tắt tích lũy cập nhật>","mode":"normal hoặc combat","combat_info":"<gợi ý đòn địch nếu đang combat, nếu không thì để rỗng>","learned_skill":{"name":"<tên chiêu mới hoặc bỏ trống>","description":"<mô tả ngắn 10-20 từ>"},"at_plot_point":false}
- options: khi "mode":"normal" và "at_plot_point":false, BẮT BUỘC PHẢI CÓ ĐÚNG 2 đến 4 hướng đi (KHÔNG ĐƯỢC để mảng rỗng), mỗi hướng đi là một câu ngắn gọn (KHÔNG dùng dấu phẩy bên trong mỗi hướng đi). Đây là yêu cầu BẮT BUỘC: mọi chương thường đều phải kết thúc bằng các hướng đi cho người chơi chọn. Chỉ khi "mode":"combat" hoặc "at_plot_point":true thì mới để options là mảng rỗng [].
- at_plot_point: chỉ đặt true khi câu chuyện vừa đến đúng nút thắt cốt truyện được nêu (nếu có); mặc định false.
- summary: bản tóm tắt NGẮN GỌN (tối đa 200 từ) toàn bộ diễn biến truyện TÍNH ĐẾN HẾT chương vừa viết, gồm các tình tiết, nhân vật, vật phẩm, chiêu thức, mâu thuẫn quan trọng để giữ mạch truyện nhất quán. Cập nhật từ tóm tắt cũ (nếu có) bằng cách bổ sung diễn biến mới, không bỏ sót điều cũ quan trọng.`;

  // PHẦN ĐỘNG đổi theo từng chương (tính cách, chiêu thức, nút thắt) -> KHÔNG cache
  const systemDynamic = `${personalityGuide}${skillGuide}${plotGuide}`;

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
    content: chosenSkill
      ? `Đang trong trận chiến. Người chơi cho nhân vật thi triển chiêu: "${chosenSkill}". Viết chương mô tả đòn đánh này và kết quả.`
      : direction
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
    // Prompt caching: phần cố định (style guide + few-shot + bối cảnh) được cache
    // để các chương sau trong cùng phiên xử lý nhanh hơn và rẻ hơn.
    system: [
      {
        type: 'text',
        text: systemStatic,
        cache_control: { type: 'ephemeral' },
      },
      {
        type: 'text',
        text: systemDynamic,
      },
    ],
    messages,
  });

  // Log để kiểm tra cache có hoạt động không (có thể bỏ sau khi xác nhận)
  if (response.usage) {
    console.log('[cache]', {
      create: response.usage.cache_creation_input_tokens || 0,
      read: response.usage.cache_read_input_tokens || 0,
      input: response.usage.input_tokens || 0,
    });
  }

  const raw = response.content.find((b) => b.type === 'text')?.text || '';

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

  // Chuẩn hóa chiêu mới học được (chỉ nhận khi có tên)
  let learnedSkill = null;
  if (parsed.learned_skill && (parsed.learned_skill.name || '').toString().trim()) {
    learnedSkill = {
      name: parsed.learned_skill.name.toString().trim(),
      description: (parsed.learned_skill.description || '').toString().trim(),
    };
  }

  const outMode = parsed.mode === 'combat' ? 'combat' : 'normal';
  const atPlotPoint = parsed.at_plot_point === true || parsed.at_plot_point === 'true';

  // Nếu chương thường mà AI quên sinh options, play.service sẽ gọi
  // suggestOptionsForChapter để sinh options hợp ngữ cảnh (xử lý ở tầng đó).

  return {
    content: parsed.content || '',
    options: cleanOptions,
    summary: parsed.summary || '',
    mode: outMode,
    combatInfo: (parsed.combat_info || '').toString().trim(),
    learnedSkill,
    atPlotPoint,
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
    return {
      content: obj.content || '',
      options: obj.options || [],
      summary: obj.summary || '',
      mode: obj.mode || 'normal',
      combat_info: obj.combat_info || '',
      learned_skill: obj.learned_skill || null,
      at_plot_point: obj.at_plot_point === true,
    };
  } catch {
    /* tiếp tục bóc thủ công */
  }

  const brace = t.match(/\{[\s\S]*\}/);
  if (brace) {
    try {
      const obj = JSON.parse(brace[0]);
      return {
        content: obj.content || '',
        options: obj.options || [],
        summary: obj.summary || '',
        mode: obj.mode || 'normal',
        combat_info: obj.combat_info || '',
        learned_skill: obj.learned_skill || null,
        at_plot_point: obj.at_plot_point === true,
      };
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

  // Bóc at_plot_point khi JSON hỏng
  let at_plot_point = /"at_plot_point"\s*:\s*true/.test(t);

  // Bóc mode và combat_info (nếu có) khi JSON hỏng
  let mode = 'normal';
  const mMatch = t.match(/"mode"\s*:\s*"(\w+)"/);
  if (mMatch && mMatch[1] === 'combat') mode = 'combat';

  let combat_info = '';
  const ciMatch = t.match(/"combat_info"\s*:\s*"([\s\S]*?)"\s*(?:,|\})/);
  if (ciMatch) combat_info = ciMatch[1].replace(/\\n/g, ' ').replace(/\\"/g, '"').trim();

  let learned_skill = null;
  const lsName = t.match(/"learned_skill"\s*:\s*\{[^}]*"name"\s*:\s*"([^"]*)"/);
  if (lsName && lsName[1].trim()) {
    const lsDesc = t.match(/"learned_skill"\s*:\s*\{[^}]*"description"\s*:\s*"([^"]*)"/);
    learned_skill = { name: lsName[1].trim(), description: lsDesc ? lsDesc[1].trim() : '' };
  }

  return { content, options, summary, mode, combat_info, learned_skill, at_plot_point };
}

// Gợi ý các lựa chọn cho một nút thắt (trợ lý sáng tác cho tác giả)
// Trả về mảng { label, branch_hint }
async function suggestPlotChoices({ scenario, plotTitle, plotDescription }) {
  if (MOCK_MODE) {
    return [
      { label: 'Đối mặt trực diện với thử thách', branch_hint: 'Nhân vật chọn cách mạnh mẽ, dẫn tới xung đột trực tiếp.' },
      { label: 'Tìm cách lẩn tránh, mưu tính đường dài', branch_hint: 'Nhân vật chọn cách thận trọng, câu chuyện đi theo hướng mưu lược.' },
      { label: 'Tìm đồng minh để cùng giải quyết', branch_hint: 'Nhân vật tìm sự trợ giúp, mở ra tuyến nhân vật mới.' },
    ];
  }

  const worldContext = buildWorldContext(scenario);
  const systemPrompt = `Bạn là trợ lý sáng tác cho một tiểu thuyết tương tác. Dựa trên bối cảnh truyện và mô tả một "nút thắt" cốt truyện, hãy đề xuất 3 lựa chọn (hướng đi) khác nhau mà người chơi có thể chọn tại nút thắt đó. Mỗi lựa chọn dẫn câu chuyện rẽ theo một hướng riêng biệt, thú vị.

Bối cảnh truyện:
${worldContext}

Chỉ trả về JSON đúng cấu trúc, không thêm lời dẫn:
{"choices":[{"label":"<lựa chọn ngắn gọn người chơi thấy>","branch_hint":"<mô tả ngắn hướng truyện sẽ đi sau lựa chọn này>"}]}
- Đúng 3 lựa chọn, khác biệt rõ rệt nhau.
- label ngắn gọn (một câu), branch_hint mô tả ngắn định hướng nhánh truyện.`;

  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 800,
    system: systemPrompt,
    messages: [
      {
        role: 'user',
        content: `Nút thắt: "${plotTitle}".${plotDescription ? ' Mô tả: ' + plotDescription : ''}\nHãy đề xuất 3 lựa chọn.`,
      },
    ],
  });

  const text = response.content
    .map((b) => (b.type === 'text' ? b.text : ''))
    .join('');
  let choices = [];
  try {
    let t = text.trim();
    const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fence) t = fence[1].trim();
    const brace = t.match(/\{[\s\S]*\}/);
    if (brace) t = brace[0];
    const obj = JSON.parse(t);
    choices = (obj.choices || [])
      .filter((c) => c && c.label)
      .map((c) => ({
        label: c.label.toString().trim(),
        branch_hint: (c.branch_hint || '').toString().trim(),
      }));
  } catch {
    choices = [];
  }
  return choices;
}

// Gợi ý cả một bộ nút thắt cho kịch bản (trợ lý sáng tác)
// Trả về mảng { title, description, choices: [{label, branch_hint}] }
async function suggestPlotPoints({ scenario, count }) {
  const n = Math.min(Math.max(parseInt(count, 10) || 3, 1), 10); // 1..10
  if (MOCK_MODE) {
    return Array.from({ length: n }, (_, i) => ({
      title: `Nút thắt mẫu ${i + 1}`,
      description: 'Mô tả tình huống nút thắt (mock).',
      choices: [
        { label: 'Lựa chọn A', branch_hint: 'Hướng A' },
        { label: 'Lựa chọn B', branch_hint: 'Hướng B' },
      ],
    }));
  }

  const worldContext = buildWorldContext(scenario);
  const systemPrompt = `Bạn là trợ lý sáng tác cho một tiểu thuyết tương tác. Dựa trên bối cảnh truyện, hãy thiết kế một bộ ${n} "nút thắt" cốt truyện theo trình tự hợp lý, dẫn dắt câu chuyện từ mở đầu tới cao trào. Mỗi nút thắt là một cột mốc quan trọng nơi người chơi phải đưa ra quyết định lớn.

Bối cảnh truyện:
${worldContext}

Chỉ trả về JSON đúng cấu trúc, không thêm lời dẫn:
{"plot_points":[{"title":"<tiêu đề ngắn>","description":"<mô tả tình huống nút thắt>","choices":[{"label":"<lựa chọn>","branch_hint":"<định hướng nhánh truyện>"}]}]}
- Đúng ${n} nút thắt, sắp theo trình tự cốt truyện (mở đầu -> phát triển -> cao trào).
- Mỗi nút thắt có 2-3 lựa chọn khác biệt rõ rệt.
- title ngắn gọn, description mô tả tình huống, choices là các hướng đi người chơi có thể chọn.`;

  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 2500,
    system: systemPrompt,
    messages: [
      { role: 'user', content: `Hãy thiết kế ${n} nút thắt cho câu chuyện này.` },
    ],
  });

  const text = response.content
    .map((b) => (b.type === 'text' ? b.text : ''))
    .join('');
  let plotPoints = [];
  try {
    let t = text.trim();
    const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fence) t = fence[1].trim();
    const brace = t.match(/\{[\s\S]*\}/);
    if (brace) t = brace[0];
    const obj = JSON.parse(t);
    plotPoints = (obj.plot_points || [])
      .filter((pp) => pp && pp.title)
      .map((pp) => ({
        title: pp.title.toString().trim(),
        description: (pp.description || '').toString().trim(),
        choices: (pp.choices || [])
          .filter((c) => c && c.label)
          .map((c) => ({
            label: c.label.toString().trim(),
            branch_hint: (c.branch_hint || '').toString().trim(),
          })),
      }));
  } catch {
    plotPoints = [];
  }
  return plotPoints;
}

// Sinh các hướng đi tiếp theo dựa trên nội dung một chương (dùng khi chương
// chính bị thiếu options). Gọi nhẹ, trả về mảng chuỗi.
async function suggestOptionsForChapter({ chapterContent, mcName }) {
  if (MOCK_MODE) {
    return ['Tiếp tục tiến lên', 'Quan sát xung quanh', 'Hành động khác'];
  }
  try {
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 300,
      system: `Dựa trên đoạn truyện, hãy đề xuất 3 hướng đi tiếp theo mà nhân vật chính "${mcName}" có thể chọn. Mỗi hướng đi là một câu ngắn gọn, hợp với tình huống vừa diễn ra, KHÔNG dùng dấu phẩy bên trong mỗi hướng đi.
Chỉ trả về JSON: {"options":["...","...","..."]}`,
      messages: [
        {
          role: 'user',
          content: `Đoạn truyện vừa diễn ra:\n${(chapterContent || '').slice(-1500)}\n\nĐề xuất 3 hướng đi tiếp theo.`,
        },
      ],
    });
    const text = response.content.map((b) => (b.type === 'text' ? b.text : '')).join('');
    let t = text.trim();
    const fence = t.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fence) t = fence[1].trim();
    const brace = t.match(/\{[\s\S]*\}/);
    if (brace) t = brace[0];
    const obj = JSON.parse(t);
    const opts = (obj.options || [])
      .map((o) => (o || '').toString().trim())
      .filter((o) => o.length > 0)
      .slice(0, 4);
    return opts;
  } catch {
    return [];
  }
}

module.exports = { generateChapter, buildWorldContext, suggestPlotChoices, suggestPlotPoints, suggestOptionsForChapter };