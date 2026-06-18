import { http } from '@kit.NetworkKit';

export interface Segment {
  start: number; // seconds
  dur: number;   // seconds
  text: string;
}

export interface FetchResult {
  segments: Segment[];
  lang: string;
  videoId: string;
}

interface CaptionTrack {
  baseUrl: string;
  languageCode: string;
  kind?: string;
}

interface Json3Seg {
  utf8?: string;
}

interface Json3Event {
  tStartMs?: number;
  dDurationMs?: number;
  segs?: Json3Seg[];
}

interface Json3 {
  events?: Json3Event[];
}

const UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

export function extractVideoId(input: string): string {
  const s: string = (input ?? '').trim();
  if (/^[A-Za-z0-9_-]{11}$/.test(s)) {
    return s;
  }
  const patterns: RegExp[] = [
    /[?&]v=([A-Za-z0-9_-]{11})/,
    /youtu\.be\/([A-Za-z0-9_-]{11})/,
    /\/shorts\/([A-Za-z0-9_-]{11})/,
    /\/embed\/([A-Za-z0-9_-]{11})/,
    /\/live\/([A-Za-z0-9_-]{11})/
  ];
  for (const p of patterns) {
    const m: RegExpMatchArray | null = s.match(p);
    if (m !== null) {
      return m[1];
    }
  }
  throw new Error('链接里找不到有效的 YouTube 视频 ID');
}

async function httpGetText(url: string): Promise<string> {
  const request = http.createHttp();
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'User-Agent': UA,
        'Accept-Language': 'en-US,en;q=0.9,zh-CN,zh;q=0.8'
      } as Record<string, string>,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 20000,
      readTimeout: 20000
    };
    const resp: http.HttpResponse = await request.request(url, options);
    if (resp.responseCode !== 200) {
      throw new Error('网络请求失败 HTTP ' + resp.responseCode);
    }
    return resp.result as string;
  } finally {
    request.destroy();
  }
}

// Extract the JSON array that follows the "captionTracks": key in the watch page.
function extractCaptionArray(html: string): string {
  const key: string = '"captionTracks":';
  const idx: number = html.indexOf(key);
  if (idx < 0) {
    throw new Error('这个视频没有可用的字幕');
  }
  const arrStart: number = html.indexOf('[', idx);
  if (arrStart < 0) {
    throw new Error('字幕信息解析失败');
  }
  let depth: number = 0;
  let end: number = -1;
  let inStr: boolean = false;
  let esc: boolean = false;
  for (let i = arrStart; i < html.length; i++) {
    const c: string = html.charAt(i);
    if (esc) {
      esc = false;
      continue;
    }
    if (c === '\\') {
      esc = true;
      continue;
    }
    if (c === '"') {
      inStr = !inStr;
      continue;
    }
    if (inStr) {
      continue;
    }
    if (c === '[') {
      depth++;
    } else if (c === ']') {
      depth--;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }
  if (end < 0) {
    throw new Error('字幕信息解析失败');
  }
  return html.substring(arrStart, end + 1);
}

export async function fetchTranscript(input: string, preferLang?: string): Promise<FetchResult> {
  const videoId: string = extractVideoId(input);
  const watchUrl: string = 'https://www.youtube.com/watch?v=' + videoId + '&hl=en';
  const html: string = await httpGetText(watchUrl);

  const arrJson: string = extractCaptionArray(html);
  const tracks: CaptionTrack[] = JSON.parse(arrJson) as CaptionTrack[];
  if (tracks.length === 0) {
    throw new Error('这个视频没有可用的字幕');
  }

  let track: CaptionTrack = tracks[0];
  if (preferLang !== undefined && preferLang.length > 0) {
    for (const t of tracks) {
      if (t.languageCode === preferLang) {
        track = t;
        break;
      }
    }
  }

  // baseUrl in the page JSON is escaped; unescape the common sequences.
  let baseUrl: string = track.baseUrl;
  baseUrl = baseUrl.replace(/\\u0026/g, '&').replace(/\\\//g, '/');
  const sep: string = baseUrl.indexOf('?') >= 0 ? '&' : '?';
  const trackUrl: string = baseUrl + sep + 'fmt=json3';

  const data: string = await httpGetText(trackUrl);
  const parsed: Json3 = JSON.parse(data) as Json3;
  const events: Json3Event[] = parsed.events ?? [];

  const segments: Segment[] = [];
  for (const ev of events) {
    if (ev.segs === undefined) {
      continue;
    }
    let text: string = '';
    for (const sg of ev.segs) {
      text += sg.utf8 ?? '';
    }
    text = text.trim();
    if (text.length === 0) {
      continue;
    }
    segments.push({
      start: (ev.tStartMs ?? 0) / 1000,
      dur: (ev.dDurationMs ?? 0) / 1000,
      text: text
    });
  }

  if (segments.length === 0) {
    throw new Error('字幕内容为空');
  }
  return { segments: segments, lang: track.languageCode, videoId: videoId };
}

function pad2(n: number): string {
  return n < 10 ? '0' + n : '' + n;
}

function pad3(n: number): string {
  if (n < 10) {
    return '00' + n;
  }
  if (n < 100) {
    return '0' + n;
  }
  return '' + n;
}

export function tsFmt(sec: number, srt: boolean = false): string {
  let s: number = sec < 0 ? 0 : Math.floor(sec);
  const ms: number = Math.floor(((sec < 0 ? 0 : sec) - s) * 1000);
  const h: number = Math.floor(s / 3600);
  s = s % 3600;
  const m: number = Math.floor(s / 60);
  s = s % 60;
  if (srt) {
    return pad2(h) + ':' + pad2(m) + ':' + pad2(s) + ',' + pad3(ms);
  }
  return h > 0 ? (h + ':' + pad2(m) + ':' + pad2(s)) : (pad2(m) + ':' + pad2(s));
}

export function buildText(segs: Segment[], timestamps: boolean): string {
  const lines: string[] = [];
  for (const seg of segs) {
    const t: string = seg.text.replace(/\n/g, ' ').trim();
    if (t.length === 0) {
      continue;
    }
    lines.push(timestamps ? ('[' + tsFmt(seg.start) + '] ' + t) : t);
  }
  return lines.join('\n') + '\n';
}

export function buildSrt(segs: Segment[]): string {
  const blocks: string[] = [];
  let i: number = 1;
  for (const seg of segs) {
    const t: string = seg.text.trim();
    if (t.length === 0) {
      continue;
    }
    const end: number = seg.start + (seg.dur > 0 ? seg.dur : 0);
    blocks.push(i + '\n' + tsFmt(seg.start, true) + ' --> ' + tsFmt(end, true) + '\n' + t + '\n');
    i++;
  }
  return blocks.join('\n');
}
