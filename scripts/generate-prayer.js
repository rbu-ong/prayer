// scripts/generate-prayer.js
// Runs via GitHub Actions every day — generates a random prayer and updates your Gist

const https = require('https');

// ── Prayer types — one is picked randomly each day ────────────────────────────
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
];

// ── Helper: HTTPS POST/PATCH ──────────────────────────────────────────────────
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

// ── Step 1: Call Anthropic API ────────────────────────────────────────────────
async function generatePrayer(type) {
  console.log(`✝  Generating "${type}"...`);

  const res = await request(
    {
      hostname: 'api.anthropic.com',
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
    },
    {
      model: 'claude-sonnet-4-6',
      max_tokens: 1000,
      messages: [
        {
          role: 'user',
          content: `Generate a beautiful, heartfelt Christian "${type}" for someone starting their day.

The prayer should be:
- 4–6 sentences long
- Personal and warm in tone
- Grounded in Christian faith
- Uplifting and encouraging
- Written in first person (addressing God / Lord / Heavenly Father)

Respond ONLY with a valid JSON object — no markdown, no backticks, no explanation:
{
  "type": "${type}",
  "title": "a short evocative prayer title (3–6 words)",
  "prayer": "the full prayer text",
  "verse": "one relevant Bible verse with reference, e.g. \\"The Lord is my shepherd.\\" — Psalm 23:1"
}`,
        },
      ],
    }
  );

  if (res.status !== 200) {
    throw new Error(`Anthropic API error ${res.status}: ${JSON.stringify(res.body)}`);
  }

  const text = res.body.content.find(b => b.type === 'text')?.text || '';
  const clean = text.replace(/```json|```/g, '').trim();
  return JSON.parse(clean);
}

// ── Step 2: Update GitHub Gist ────────────────────────────────────────────────
async function updateGist(prayer) {
  const today = new Date().toISOString().slice(0, 10);
  const payload = {
    ...prayer,
    date: today,
    generated_at: new Date().toISOString(),
  };

  console.log('📄 Updating Gist...');
  console.log(JSON.stringify(payload, null, 2));

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
  console.log(`✅ Gist updated! Raw URL: ${rawUrl}`);
  return rawUrl;
}

// ── Main ──────────────────────────────────────────────────────────────────────
(async () => {
  try {
    // Pick a random prayer type
    const type = PRAYER_TYPES[Math.floor(Math.random() * PRAYER_TYPES.length)];

    const prayer = await generatePrayer(type);
    await updateGist(prayer);

    console.log('🙏 Done! Today\'s prayer has been published.');
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
