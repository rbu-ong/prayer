# ✝ Daily Prayer — Automated Setup Guide

This guide sets up a **fully automated** daily prayer pipeline:
- GitHub Actions generates a new random prayer every morning at 6 AM (Philippine Time)
- It calls the Anthropic API and saves the result to your GitHub Gist
- Your Chrome extension fetches the Gist — **no API key in the browser**

---

## Prerequisites
- A **GitHub account** (free)
- An **Anthropic API key** — get one at https://console.anthropic.com

---

## Step 1 — Create the GitHub Gist

1. Go to https://gist.github.com
2. Create a **new Gist**:
   - Filename: `prayer.json`
   - Content (paste this as a placeholder):
     ```json
     {
       "type": "Morning Prayer",
       "title": "Lord, Guide My Steps",
       "prayer": "Heavenly Father, thank You for this new day...",
       "verse": "\"Trust in the Lord with all your heart.\" — Proverbs 3:5",
       "date": "2025-01-01"
     }
     ```
3. Click **"Create public gist"**
4. Copy your **Gist ID** from the URL:
   `https://gist.github.com/YOUR_USERNAME/` **`abc123def456`** ← this is your Gist ID

---

## Step 2 — Create a GitHub Repository

1. Go to https://github.com/new
2. Name it: `daily-prayer-bot` (or anything you like)
3. Set it to **Private** (recommended — your API key will be stored here as a secret)
4. Click **Create repository**

---

## Step 3 — Upload the Bot Files

Upload these two files to your new repo:
- `.github/workflows/daily-prayer.yml`
- `scripts/generate-prayer.js`

**Easiest way:**
```bash
# In your terminal (you have OpenClaw/Claude Code)
cd prayer-automation
git init
git remote add origin https://github.com/YOUR_USERNAME/daily-prayer-bot.git
git add .
git commit -m "Add daily prayer bot"
git push -u origin main
```

---

## Step 4 — Create a GitHub Personal Access Token (for Gist updates)

1. Go to https://github.com/settings/tokens/new
2. Name it: `Daily Prayer Gist Token`
3. Expiration: **No expiration** (or 1 year)
4. Scopes: tick only ✅ **`gist`**
5. Click **Generate token**
6. **Copy the token** — you'll only see it once!

---

## Step 5 — Add Secrets to Your GitHub Repo

1. Go to your repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"** and add these 3 secrets:

| Secret Name         | Value                          |
|---------------------|--------------------------------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key         |
| `GIST_ID`           | Your Gist ID from Step 1       |
| `GIST_TOKEN`        | The token you created in Step 4 |

---

## Step 6 — Test It Manually

1. In your repo, go to **Actions** tab
2. Click **"Generate Daily Prayer"**
3. Click **"Run workflow"** → **"Run workflow"**
4. Watch it run — should take ~10 seconds
5. Check your Gist — it should now have today's prayer! 🙏

---

## Step 7 — Update the Chrome Extension

1. Open `newtab.html` in the `daily-prayer-extension` folder
2. Find this line:
   ```js
   const GIST_RAW_URL = 'https://gist.githubusercontent.com/YOUR_USERNAME/YOUR_GIST_ID/raw/prayer.json';
   ```
3. Replace with your actual Gist raw URL:
   - Go to your Gist → click **"Raw"** → copy the URL
   - Remove the hash part at the end so it always points to latest, e.g.:
   `https://gist.githubusercontent.com/johndoe/abc123/raw/prayer.json`
4. Save and reload the extension in `chrome://extensions/`

---

## Schedule

The workflow runs every day at **10:00 PM UTC = 6:00 AM Philippine Time (PHT)**.

To change the time, edit `.github/workflows/daily-prayer.yml`:
```yaml
- cron: '0 22 * * *'   # 10 PM UTC = 6 AM PHT
```
Use https://crontab.guru to find your preferred UTC time.

---

## How the Random Prayer Works

Every day, the script randomly picks one of **15 prayer types**:
- Morning Prayer, Gratitude, Strength, Peace, Guidance, Hope
- Family, Healing, Praise, Wisdom, Surrender, Protection
- Courage, Thanksgiving, Joy

Then Claude AI writes a unique, heartfelt prayer for that type — so you'll never see the same prayer twice.

---

## Folder Structure

```
prayer-automation/          ← push this to GitHub
├── .github/
│   └── workflows/
│       └── daily-prayer.yml
└── scripts/
    └── generate-prayer.js

daily-prayer-extension/     ← load this in Chrome
├── manifest.json
├── newtab.html             ← update GIST_RAW_URL here
├── README.md
└── icons/
```
