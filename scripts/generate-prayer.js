// scripts/generate-prayer.js
// Runs via GitHub Actions every day
// Generates 50 random prayers in ONE API call and saves them to your Gist

const https = require('https');

// ── Prayer types pool (50 will be randomly picked from this list) ─────────────
const PRAYER_TYPES = [
  'Morning Prayer',
  'Prayer of Gratitude',
  'Prayer for Strength',
  'Prayer for Peace',
  'Prayer for Guidance',
  'Prayer of Hope',
  'Prayer for Family',
  'Prayer for Healing',
  'Prayer of Praise',
  'Prayer for Wisdom',
  'Prayer of Surrender',
  'Prayer for Protection',
  'Prayer for Courage',
  'Prayer of Thanksgiving',
  'Prayer for Joy',
  'Prayer for Patience',
  'Prayer for Forgiveness',
  'Prayer for Humility',
  'Prayer for Faith',
  'Prayer for Love',
  'Prayer for New Beginnings',
  'Prayer for Perseverance',
  'Prayer of Adoration',
  'Prayer for the Broken-Hearted',
  'Prayer for Clarity',
];

// Shuffle and pick 50 (with repeats allowed if pool < 50)
function pickTypes(count) {
  const result = [];
  const pool = [...PRAYER_TYPES];
  for (let i = 0; i < count; i++) {
    result.push(pool[Math.floor(Math.random() * pool.length)]);
  }
  return result;
}

// ── Helper: HTTPS request ─────────────────────────────────────────────────────
function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ── Step 1: Call OpenAI — generate all 50 prayers in one shot ────────────────
async function generate50Prayers() {
  const types = pickTypes(50);
  console.log('✝  Generating 50 prayers in one API call...');

  const res = await request(
    {
      hostname: 'api.openai.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      },
    },
    {
      model: 'gpt-4o-mini',
      max_tokens: 16000,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content: 'You are a Christian prayer writer. Always respond with valid JSON only — no markdown, no backticks, no extra explanation.',
        },
        {
          role: 'user',
          content: `Generate exactly 50 unique Christian prayers. Each prayer should be 90–100 words long.

Use these prayer types in this exact order:
${types.map((t, i) => `${i + 1}. ${t}`).join('\n')}

Rules for each prayer:
- 90–100 words (count carefully)
- Warm, personal, heartfelt tone
- Written in first person addressing God / Lord / Heavenly Father
- Uplifting and grounded in Christian faith
- Each one must feel unique — no repetitive phrasing across prayers
- End every prayer with "Amen." on its own as the final word — never "amen." or "Amen," just "Amen."

Respond ONLY with this JSON structure:
{
  "prayers": [
    {
      "id": 1,
      "type": "the prayer type",
      "title": "short evocative title (3–6 words)",
      "prayer": "the full prayer text (90–100 words)",
      "verse": "one Bible verse with reference e.g. \\"Be still and know that I am God.\\" — Psalm 46:10"
    }
  ]
}`,
        },
      ],
    }
  );

  if (res.status !== 200) {
    throw new Error(`OpenAI API error ${res.status}: ${JSON.stringify(res.body)}`);
  }

  const text = res.body.choices?.[0]?.message?.content || '';
  const clean = text.replace(/```json|```/g, '').trim();
  const parsed = JSON.parse(clean);

  if (!parsed.prayers || parsed.prayers.length === 0) {
    throw new Error('No prayers returned from OpenAI');
  }

  console.log(`✅ Received ${parsed.prayers.length} prayers from OpenAI`);
  return parsed.prayers;
}

// ── Step 2: Save all 50 prayers to GitHub Gist ───────────────────────────────
async function updateGist(prayers) {
  const today = new Date().toISOString().slice(0, 10);

  const payload = {
    date: today,
    generated_at: new Date().toISOString(),
    total: prayers.length,
    prayers: prayers,
  };

  console.log('📄 Saving to Gist...');

  const res = await request(
    {
      hostname: 'api.github.com',
      path: `/gists/${process.env.GIST_ID}`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.GIST_TOKEN}`,
        'User-Agent': 'daily-prayer-bot',
      },
    },
    {
      files: {
        'prayer.json': {
          content: JSON.stringify(payload, null, 2),
        },
      },
    }
  );

  if (res.status !== 200) {
    throw new Error(`GitHub Gist error ${res.status}: ${JSON.stringify(res.body)}`);
  }

  const rawUrl = res.body.files?.['prayer.json']?.raw_url;
  console.log(`✅ Gist updated! ${prayers.length} prayers saved.`);
  console.log(`📎 Raw URL: ${rawUrl}`);
  return rawUrl;
}

// ── Main ──────────────────────────────────────────────────────────────────────
(async () => {
  try {
    const prayers = await generate50Prayers();
    await updateGist(prayers);
    console.log("🙏 Done! 50 prayers are ready for today.");
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
