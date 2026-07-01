// scripts/upload-youtube.js
// Uploads output.mp4 to YouTube using OAuth refresh token

const https = require('https');
const fs    = require('fs');
const path  = require('path');

const rawTitle = process.argv[2] || '';
const verse    = process.argv[3] || '';
const date     = process.argv[4] || new Date().toISOString().slice(0, 10);

// YouTube title = "Daily Prayer — [Verse Ref]", fallback to prayer title
const verseRef = verse.match(/[—–\-]\s*(.+)$/)?.[1]?.trim() || '';
const title = verseRef ? `Daily Prayer — ${verseRef}` : (rawTitle || 'Daily Prayer');

const {
  YOUTUBE_CLIENT_ID,
  YOUTUBE_CLIENT_SECRET,
  YOUTUBE_REFRESH_TOKEN,
} = process.env;

function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data), headers: res.headers }); }
        catch { resolve({ status: res.statusCode, body: data, headers: res.headers }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

async function getAccessToken() {
  const res = await request(
    {
      hostname: 'oauth2.googleapis.com',
      path:     '/token',
      method:   'POST',
      headers:  { 'Content-Type': 'application/x-www-form-urlencoded' },
    },
    `client_id=${YOUTUBE_CLIENT_ID}&client_secret=${YOUTUBE_CLIENT_SECRET}&refresh_token=${YOUTUBE_REFRESH_TOKEN}&grant_type=refresh_token`
  );
  if (!res.body.access_token) throw new Error('Failed to get access token: ' + JSON.stringify(res.body));
  return res.body.access_token;
}

async function uploadVideo(accessToken) {
  const videoPath = path.join(process.cwd(), 'output.mp4');
  const videoSize = fs.statSync(videoPath).size;

  const videoTitle       = title;
  const videoDescription = `${verse}\n\n✝ A heartfelt Christian prayer for today.\n\n#ChristianPrayer #DailyPrayer #Faith #Bible`;
  const metadata = {
    snippet: {
      title:       videoTitle,
      description: videoDescription,
      tags:        ['prayer', 'christian', 'daily prayer', 'bible', 'faith', 'god', verse.split('—')[1]?.trim() || ''],
      categoryId:  '22', // People & Blogs
    },
    status: {
      privacyStatus:           'public',
      selfDeclaredMadeForKids: false,
    },
  };

  // Step 1 — initiate resumable upload
  const initRes = await request(
    {
      hostname: 'www.googleapis.com',
      path:     '/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status',
      method:   'POST',
      headers:  {
        'Authorization':  `Bearer ${accessToken}`,
        'Content-Type':   'application/json',
        'X-Upload-Content-Type': 'video/mp4',
        'X-Upload-Content-Length': videoSize,
      },
    },
    metadata
  );

  const uploadUrl = initRes.headers.location;
  if (!uploadUrl) throw new Error('No upload URL returned: ' + JSON.stringify(initRes.body));
  console.log('Upload session created');

  // Step 2 — upload the video file
  const uploadUri = new URL(uploadUrl);
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: uploadUri.hostname,
        path:     uploadUri.pathname + uploadUri.search,
        method:   'PUT',
        headers:  {
          'Authorization':  `Bearer ${accessToken}`,
          'Content-Type':   'video/mp4',
          'Content-Length': videoSize,
        },
      },
      (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          const body = JSON.parse(data);
          if (res.statusCode === 200 || res.statusCode === 201) {
            console.log(`✅ Uploaded! Video ID: ${body.id}`);
            console.log(`🔗 https://www.youtube.com/watch?v=${body.id}`);
            resolve(body);
          } else {
            reject(new Error(`Upload failed ${res.statusCode}: ${data}`));
          }
        });
      }
    );
    req.on('error', reject);
    fs.createReadStream(videoPath).pipe(req);
  });
}

(async () => {
  try {
    console.log(`📹 Uploading video: "${title}"`);
    const token = await getAccessToken();
    await uploadVideo(token);
    console.log('🙏 Done!');
  } catch (err) {
    console.error('❌ YouTube upload error:', err.message);
    process.exit(1);
  }
})();
