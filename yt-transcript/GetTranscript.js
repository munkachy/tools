// Get Transcript — a Scriptable script for iPhone.
// Share a YouTube video to this script (or copy its link and run it), and the
// transcript is put on your clipboard in 5-minute blocks, ready for an AI.
//
// Setup: see https://munkachy.github.io/tools/yt-transcript/#iphone

const BLOCK = 300; // seconds per block
const AI_PROMPT =
  'Below is the transcript of a YouTube video, grouped in 5-minute blocks. ' +
  'For each block, keep its timestamp as a heading and write a detailed summary: ' +
  'the main points, the arguments and examples used, and any names, books or sources mentioned. ' +
  'The captions were generated automatically, so correct obvious errors in names and terms, ' +
  'and point out any you are unsure of.\n\n';

// The same YouTube app identities yt-dlp uses. YouTube sometimes refuses one
// and accepts another, so we try them in turn.
const CLIENTS = [
  { id: 5, ctx: { clientName: 'IOS', clientVersion: '21.26.4', deviceMake: 'Apple', deviceModel: 'iPhone16,2', osName: 'iPhone', osVersion: '18.3.2.22D82', hl: 'en' },
    ua: 'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)' },
  { id: 3, ctx: { clientName: 'ANDROID', clientVersion: '21.26.364', androidSdkVersion: 30, osName: 'Android', osVersion: '11', hl: 'en' },
    ua: 'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip' },
  { id: 28, ctx: { clientName: 'ANDROID_VR', clientVersion: '1.65.10', deviceMake: 'Oculus', deviceModel: 'Quest 3', androidSdkVersion: 32, osName: 'Android', osVersion: '12L', hl: 'en' },
    ua: 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip' },
];
const SAFARI_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1';

function videoId(text) {
  const m = (text || '').match(/(?:v=|youtu\.be\/|shorts\/|embed\/|live\/)([\w-]{11})/);
  return m ? m[1] : null;
}

function pickTrack(tracks) {
  return tracks.find(t => /^en/.test(t.languageCode) && t.kind !== 'asr') ||
         tracks.find(t => /^en/.test(t.languageCode)) || tracks[0];
}

// Way 1: ask YouTube's app API, as the YouTube app would.
async function fromApi(id, log) {
  for (const c of CLIENTS) {
    try {
      const req = new Request('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
      req.method = 'POST';
      req.headers = { 'Content-Type': 'application/json', 'User-Agent': c.ua,
        'X-YouTube-Client-Name': String(c.id), 'X-YouTube-Client-Version': c.ctx.clientVersion };
      req.body = JSON.stringify({ context: { client: c.ctx }, videoId: id, contentCheckOk: true, racyCheckOk: true });
      const j = await req.loadJSON();
      const tracks = j?.captions?.playerCaptionsTracklistRenderer?.captionTracks || [];
      log.push(c.ctx.clientName + ': ' + (j?.playabilityStatus?.status || '?') + ', ' + tracks.length + ' caption tracks');
      const t = pickTrack(tracks);
      if (!t) continue;
      const segs = await loadCaptions(t.baseUrl, c.ua);
      if (segs.length) return { title: j?.videoDetails?.title, segs };
      log.push('  caption file was empty');
    } catch (e) { log.push(c.ctx.clientName + ': ' + e); }
  }
  return null;
}

// Way 2: read the normal YouTube web page, as Safari would.
async function fromWebPage(id, log) {
  try {
    const req = new Request('https://www.youtube.com/watch?v=' + id + '&hl=en');
    req.headers = { 'User-Agent': SAFARI_UA, 'Accept-Language': 'en-US,en' };
    const html = await req.loadString();
    const m = html.match(/ytInitialPlayerResponse\s*=\s*(\{.+?\});\s*(?:var|<\/script)/s);
    if (!m) { log.push('Web page: no player data'); return null; }
    const j = JSON.parse(m[1]);
    const tracks = j?.captions?.playerCaptionsTracklistRenderer?.captionTracks || [];
    log.push('Web page: ' + (j?.playabilityStatus?.status || '?') + ', ' + tracks.length + ' caption tracks');
    const t = pickTrack(tracks);
    if (!t) return null;
    const segs = await loadCaptions(t.baseUrl, SAFARI_UA);
    if (segs.length) return { title: j?.videoDetails?.title, segs };
    log.push('  caption file was empty');
  } catch (e) { log.push('Web page: ' + e); }
  return null;
}

// Returns [[startSeconds, text], ...]
async function loadCaptions(baseUrl, ua) {
  const req = new Request(baseUrl.replace(/&fmt=[^&]*/, '') + '&fmt=json3');
  req.headers = { 'User-Agent': ua };
  const txt = await req.loadString();
  if (!txt || !txt.trim()) return [];
  const segs = [];
  let last = '';
  for (const e of JSON.parse(txt).events || []) {
    if (!e.segs) continue;
    const t = e.segs.map(s => s.utf8).join('').replace(/\s+/g, ' ')
      .replace(/&gt;/g, '>').replace(/&lt;/g, '<').replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, '&').trim();
    if (t && t !== last) { segs.push([e.tStartMs / 1000, t]); last = t; }
  }
  return segs;
}

function stamp(s) {
  s = Math.floor(s);
  return Math.floor(s / 3600) + ':' + String(Math.floor(s % 3600 / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
}

function format(segs, plain) {
  if (plain) return segs.map(x => x[1]).join(' ');
  const b = {};
  for (const [s, t] of segs) { const k = Math.floor(s / BLOCK); (b[k] = b[k] || []).push(t); }
  return Object.keys(b).map(Number).sort((x, y) => x - y)
    .map(k => '[' + stamp(k * BLOCK) + ']\n' + b[k].join(' ')).join('\n\n');
}

async function say(title, message, buttons) {
  const a = new Alert();
  a.title = title; a.message = message;
  buttons.forEach(b => a.addAction(b));
  return await a.presentAlert();
}

// ---------- main ----------
let input = (args.urls && args.urls[0]) || (args.plainTexts && args.plainTexts[0]) || '';
let id = videoId(input) || videoId(Pasteboard.paste() || '');
if (!id) {
  const a = new Alert();
  a.title = 'Get Transcript';
  a.message = 'Paste a YouTube link:';
  a.addTextField('https://youtu.be/…');
  a.addAction('Go'); a.addCancelAction('Cancel');
  if (await a.presentAlert() !== -1) id = videoId(a.textFieldValue(0));
  if (!id) input = 'cancelled';
}

if (!id && input === 'cancelled') {
  // user tapped Cancel
} else if (!id) {
  await say('No YouTube link found', 'Share a YouTube video to this script, or copy its link first.', ['OK']);
} else {
  const log = [];
  const result = (await fromApi(id, log)) || (await fromWebPage(id, log));
  if (!result) {
    await say('Could not get the transcript',
      'The video may have no captions, or YouTube refused this time. Try again in a minute.\n\nDetails:\n' + log.join('\n'), ['OK']);
  } else {
    const head = 'Video: ' + (result.title || '') + '\nhttps://www.youtube.com/watch?v=' + id + '\n\n';
    const words = result.segs.reduce((n, x) => n + x[1].split(' ').length, 0);
    const choice = await say(result.title || 'Transcript ready',
      'About ' + words.toLocaleString() + ' words. What should I copy?',
      ['Copy for AI (with summary request)', 'Copy with timestamps', 'Copy plain text', 'Preview']);
    const text = [AI_PROMPT + head + format(result.segs, false), head + format(result.segs, false),
                  head + format(result.segs, true), head + format(result.segs, false)][choice];
    if (choice === 3) await QuickLook.present(text, true);
    else if (choice >= 0) { Pasteboard.copy(text); await say('Copied ✓', 'Now paste it into your AI chat.', ['OK']); }
  }
}
Script.complete();
