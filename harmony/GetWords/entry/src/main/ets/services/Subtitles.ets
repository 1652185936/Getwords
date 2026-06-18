import { http } from '@kit.NetworkKit';

/** 单条字幕片段 */
export interface Segment {
  start: number; // 起始时间（秒）
  dur: number;   // 持续时长（秒）
  text: string;  // 字幕文本（英文原文）
  zh?: string;   // 中文译文（调用翻译后填充）
}

/** 抓取结果 */
export interface FetchResult {
  segments: Segment[]; // 字幕片段列表
  lang: string;        // 实际使用的字幕语言码
  videoId: string;     // YouTube 视频 ID
  title: string;       // 视频标题
}

/** InnerTube 请求中的客户端标识信息 */
interface InnertubeClient {
  clientName: string;        // 客户端名，如 IOS / ANDROID
  clientVersion: string;     // 客户端版本号
  hl: string;                // 界面语言
  deviceMake?: string;       // 设备厂商（部分客户端需要）
  deviceModel?: string;      // 设备型号（部分客户端需要）
  osName?: string;           // 操作系统名
  osVersion?: string;        // 操作系统版本
  androidSdkVersion?: number; // Android SDK 版本（仅 ANDROID 客户端）
}

/** InnerTube 请求上下文 */
interface InnertubeContext {
  client: InnertubeClient; // 客户端标识
}

/** InnerTube player 接口请求体 */
interface InnertubePlayerRequest {
  context: InnertubeContext; // 请求上下文
  videoId: string;           // 目标视频 ID
  contentCheckOk: boolean;   // 跳过内容确认
  racyCheckOk: boolean;      // 跳过敏感内容确认
}

/** 本地维护的客户端伪装档案（用于绕过 PoToken 风控） */
interface ClientProfile {
  clientNameHeader: string; // 对应 HTTP 头 X-YouTube-Client-Name 的数字
  userAgent: string;        // 伪装用的 User-Agent
  client: InnertubeClient;  // 请求体里的客户端信息
}

/** player 返回的单条字幕轨道 */
interface PlayerCaptionTrack {
  baseUrl: string;       // 字幕内容地址（不带 pot，可直接取用）
  languageCode: string;  // 语言码
  kind?: string;         // 轨道类型，asr 表示自动生成
}

/** 字幕轨道列表渲染器 */
interface CaptionsTracklistRenderer {
  captionTracks?: PlayerCaptionTrack[]; // 字幕轨道数组
}

/** player 返回里的字幕容器 */
interface PlayerCaptions {
  playerCaptionsTracklistRenderer?: CaptionsTracklistRenderer; // 字幕列表渲染器
}

/** 视频可播放状态 */
interface PlayabilityStatus {
  status?: string; // OK / LOGIN_REQUIRED / UNPLAYABLE 等
  reason?: string; // 不可播放的原因
}

/** 视频详情 */
interface VideoDetails {
  title?: string; // 视频标题
}

/** InnerTube player 接口返回体（仅声明用到的字段） */
interface PlayerResponse {
  captions?: PlayerCaptions;               // 字幕信息
  playabilityStatus?: PlayabilityStatus;   // 可播放状态
  videoDetails?: VideoDetails;             // 视频详情
}

/** 字幕轨道查询结果 */
interface CaptionLookup {
  tracks: PlayerCaptionTrack[]; // 字幕轨道
  title: string;                // 视频标题
}

/** json3 字幕里的单个文本分片 */
interface Json3Seg {
  utf8?: string; // 文本内容
}

/** json3 字幕里的单个事件（通常对应一行字幕） */
interface Json3Event {
  tStartMs?: number;     // 起始毫秒
  dDurationMs?: number;  // 持续毫秒
  segs?: Json3Seg[];     // 文本分片
}

/** json3 字幕顶层结构 */
interface Json3 {
  events?: Json3Event[]; // 事件列表
}

/** InnerTube player 接口地址 */
const PLAYER_URL: string =
  'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

/**
 * 客户端伪装档案列表，按优先级排序。
 * iOS 客户端返回干净的 json3 且 baseUrl 不需要 PoToken；ANDROID 作为兜底。
 */
const CLIENTS: ClientProfile[] = [
  {
    clientNameHeader: '5',
    userAgent: 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
    client: {
      clientName: 'IOS',
      clientVersion: '20.10.4',
      deviceMake: 'Apple',
      deviceModel: 'iPhone16,2',
      osName: 'iPhone',
      osVersion: '18.3.2.22D82',
      hl: 'en'
    }
  },
  {
    clientNameHeader: '3',
    userAgent: 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
    client: {
      clientName: 'ANDROID',
      clientVersion: '20.10.38',
      androidSdkVersion: 30,
      osName: 'Android',
      osVersion: '11',
      hl: 'en'
    }
  }
];

/**
 * 从用户输入中提取 11 位 YouTube 视频 ID。
 * @param input 用户粘贴的链接或直接的视频 ID
 * @returns 提取到的视频 ID
 */
export function extractVideoId(input: string): string {
  const s: string = (input ?? '').trim(); // 去除首尾空白后的输入
  if (/^[A-Za-z0-9_-]{11}$/.test(s)) {
    return s;
  }
  // 支持的各种 YouTube 链接形态
  const patterns: RegExp[] = [
    /[?&]v=([A-Za-z0-9_-]{11})/,
    /youtu\.be\/([A-Za-z0-9_-]{11})/,
    /\/shorts\/([A-Za-z0-9_-]{11})/,
    /\/embed\/([A-Za-z0-9_-]{11})/,
    /\/live\/([A-Za-z0-9_-]{11})/
  ];
  for (const p of patterns) {
    const m: RegExpMatchArray | null = s.match(p); // 当前规则的匹配结果
    if (m !== null) {
      return m[1];
    }
  }
  throw new Error('链接里找不到有效的 YouTube 视频 ID');
}

/**
 * 发送 GET 请求并以文本形式返回响应体。
 * @param url 目标地址
 * @returns 响应文本
 */
async function httpGetText(url: string): Promise<string> {
  const request: http.HttpRequest = http.createHttp(); // 本次请求对象
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: {
        'User-Agent': CLIENTS[0].userAgent,
        'Accept-Language': 'en-US,en;q=0.9,zh-CN,zh;q=0.8'
      } as Record<string, string>,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 20000,
      readTimeout: 20000
    };
    const resp: http.HttpResponse = await request.request(url, options); // 服务器响应
    if (resp.responseCode !== 200) {
      throw new Error(`网络请求失败 HTTP ${resp.responseCode}`);
    }
    return resp.result as string;
  } finally {
    request.destroy();
  }
}

/**
 * 向 InnerTube 接口发送 POST（JSON 请求体），以文本形式返回响应体。
 * @param url 目标地址
 * @param payload 已序列化的 JSON 字符串
 * @param headers 请求头
 * @returns 响应文本
 */
async function httpPostJson(url: string, payload: string, headers: Record<string, string>): Promise<string> {
  const request: http.HttpRequest = http.createHttp(); // 本次请求对象
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: payload,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 20000,
      readTimeout: 20000
    };
    const resp: http.HttpResponse = await request.request(url, options); // 服务器响应
    if (resp.responseCode !== 200) {
      throw new Error(`网络请求失败 HTTP ${resp.responseCode}`);
    }
    return resp.result as string;
  } finally {
    request.destroy();
  }
}

/**
 * 依次尝试各客户端档案，通过 InnerTube player 接口获取字幕轨道列表与视频标题。
 * @param videoId 视频 ID
 * @returns 字幕轨道与标题
 */
async function fetchCaptionTracks(videoId: string): Promise<CaptionLookup> {
  let lastReason: string = '未知原因'; // 记录最后一次失败原因，便于报错提示
  for (const profile of CLIENTS) {
    // 组装当前客户端的请求体
    const body: InnertubePlayerRequest = {
      context: { client: profile.client },
      videoId: videoId,
      contentCheckOk: true,
      racyCheckOk: true
    };
    // 组装伪装请求头
    const headers: Record<string, string> = {
      'User-Agent': profile.userAgent,
      'Content-Type': 'application/json',
      'X-YouTube-Client-Name': profile.clientNameHeader,
      'X-YouTube-Client-Version': profile.client.clientVersion,
      'Origin': 'https://www.youtube.com'
    };
    try {
      const raw: string = await httpPostJson(PLAYER_URL, JSON.stringify(body), headers); // 原始响应文本
      const resp: PlayerResponse = JSON.parse(raw) as PlayerResponse;                    // 解析后的响应
      const tracks: PlayerCaptionTrack[] | undefined =
        resp.captions?.playerCaptionsTracklistRenderer?.captionTracks;                   // 字幕轨道
      if (tracks !== undefined && tracks.length > 0) {
        return { tracks: tracks, title: resp.videoDetails?.title ?? '' };
      }
      lastReason = `${profile.client.clientName}：${resp.playabilityStatus?.status ?? 'NO_CAPTIONS'}`;
    } catch (err) {
      lastReason = (err as Error).message;
    }
  }
  throw new Error(`这个视频没有可用的字幕（${lastReason}）`);
}

/**
 * 将 XML/HTML 实体还原为普通字符。
 * @param input 含实体的字符串
 * @returns 还原后的字符串
 */
function decodeEntities(input: string): string {
  let s: string = input; // 逐步替换的中间结果
  s = s.replace(/&amp;/g, '&');
  s = s.replace(/&lt;/g, '<');
  s = s.replace(/&gt;/g, '>');
  s = s.replace(/&quot;/g, '"');
  s = s.replace(/&#39;/g, "'");
  s = s.replace(/&apos;/g, "'");
  // 处理形如 &#160; 的数字实体
  const re: RegExp = /&#(\d+);/g;        // 数字实体匹配规则
  const parts: string[] = [];            // 拼接结果片段
  let last: number = 0;                  // 上一次匹配结束位置
  let m: RegExpExecArray | null = re.exec(s); // 当前匹配
  while (m !== null) {
    parts.push(s.substring(last, m.index));
    parts.push(String.fromCharCode(parseInt(m[1], 10)));
    last = m.index + m[0].length;
    m = re.exec(s);
  }
  parts.push(s.substring(last));
  return parts.join('');
}

/**
 * 去掉字符串中的所有标签。
 * @param s 含标签的字符串
 * @returns 纯文本
 */
function stripTags(s: string): string {
  return s.replace(/<[^>]+>/g, '');
}

/**
 * 解析 json3 格式字幕。
 * @param data json3 文本
 * @returns 字幕片段列表
 */
function parseJson3(data: string): Segment[] {
  const parsed: Json3 = JSON.parse(data) as Json3;     // 解析后的 json3
  const events: Json3Event[] = parsed.events ?? [];    // 事件列表
  const segments: Segment[] = [];                      // 结果片段
  for (const ev of events) {
    if (ev.segs === undefined) {
      continue;
    }
    let text: string = ''; // 当前事件拼接出的文本
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
  return segments;
}

/**
 * 解析 XML 格式字幕（兼容经典 <text> 与 srv3 <p> 两种结构），作为 json3 的兜底。
 * @param xml XML 文本
 * @returns 字幕片段列表
 */
function parseXml(xml: string): Segment[] {
  const segments: Segment[] = []; // 结果片段
  if (xml.indexOf('<text') >= 0) {
    // 经典格式：<text start="1.5" dur="2.0">文本</text>
    const re: RegExp = /<text([^>]*)>([\s\S]*?)<\/text>/g; // 单条字幕匹配规则
    let m: RegExpExecArray | null = re.exec(xml);          // 当前匹配
    while (m !== null) {
      const attrs: string = m[1];                                  // 标签属性串
      const startMatch: RegExpMatchArray | null = attrs.match(/\bstart="([\d.]+)"/); // start 属性
      const durMatch: RegExpMatchArray | null = attrs.match(/\bdur="([\d.]+)"/);     // dur 属性
      const text: string = decodeEntities(stripTags(m[2])).trim();  // 还原后的文本
      if (startMatch !== null && text.length > 0) {
        segments.push({
          start: parseFloat(startMatch[1]),
          dur: durMatch !== null ? parseFloat(durMatch[1]) : 0,
          text: text
        });
      }
      m = re.exec(xml);
    }
    return segments;
  }
  // srv3 格式：<p t="120" d="4500"><s>word</s>...</p>，时间单位为毫秒
  const re2: RegExp = /<p\b([^>]*)>([\s\S]*?)<\/p>/g; // 单段字幕匹配规则
  let p: RegExpExecArray | null = re2.exec(xml);      // 当前匹配
  while (p !== null) {
    const attrs: string = p[1];                              // 标签属性串
    const tMatch: RegExpMatchArray | null = attrs.match(/\bt="(\d+)"/); // 起始毫秒
    const dMatch: RegExpMatchArray | null = attrs.match(/\bd="(\d+)"/); // 持续毫秒
    const text: string = decodeEntities(stripTags(p[2])).trim();        // 还原后的文本
    if (tMatch !== null && text.length > 0) {
      segments.push({
        start: parseInt(tMatch[1], 10) / 1000,
        dur: dMatch !== null ? parseInt(dMatch[1], 10) / 1000 : 0,
        text: text
      });
    }
    p = re2.exec(xml);
  }
  return segments;
}

/**
 * 解析字幕内容，自动识别 json3 与 XML，并检测空响应。
 * @param data 字幕接口返回的原始文本
 * @returns 字幕片段列表
 */
function parseTranscript(data: string): Segment[] {
  const trimmed: string = data.trim(); // 去除首尾空白后的内容
  if (trimmed.length === 0) {
    throw new Error('字幕接口返回空内容，可能被 YouTube 风控，请稍后重试');
  }
  if (trimmed.charAt(0) === '{') {
    return parseJson3(trimmed);
  }
  return parseXml(trimmed);
}

/**
 * 抓取指定视频的字幕。
 * @param input 用户输入的链接或视频 ID
 * @param preferLang 可选，优先选择的语言码
 * @returns 抓取结果
 */
export async function fetchTranscript(input: string, preferLang?: string): Promise<FetchResult> {
  const videoId: string = extractVideoId(input);                  // 视频 ID
  const lookup: CaptionLookup = await fetchCaptionTracks(videoId); // 字幕轨道与标题
  const tracks: PlayerCaptionTrack[] = lookup.tracks;             // 字幕轨道列表

  let track: PlayerCaptionTrack = tracks[0]; // 选中的字幕轨道，默认第一条
  if (preferLang !== undefined && preferLang.length > 0) {
    for (const t of tracks) {
      if (t.languageCode === preferLang) {
        track = t;
        break;
      }
    }
  }

  const baseUrl: string = track.baseUrl;                          // 字幕内容地址（JSON.parse 已还原转义）
  const sep: string = baseUrl.indexOf('?') >= 0 ? '&' : '?';      // 追加参数用的分隔符
  const trackUrl: string = `${baseUrl}${sep}fmt=json3`;           // 请求 json3 格式的完整地址

  const data: string = await httpGetText(trackUrl);  // 字幕原始文本
  const segments: Segment[] = parseTranscript(data); // 解析出的字幕片段
  if (segments.length === 0) {
    throw new Error('字幕内容为空');
  }
  return { segments: segments, lang: track.languageCode, videoId: videoId, title: lookup.title };
}

/**
 * 将 YouTube 自动字幕的零碎片段合并成完整句子，便于阅读和导出。
 * 合并规则：累加相邻片段，遇到句末标点或超过最大长度即断句，时间取首个片段的开始时间。
 * @param segs 原始字幕片段列表
 * @returns 合并后的句子级片段列表
 */
export function mergeSegments(segs: Segment[]): Segment[] {
  const out: Segment[] = []; // 合并结果
  let buf: string = '';      // 当前累加的句子文本
  let start: number = 0;     // 当前句子的开始时间
  let end: number = 0;       // 当前句子的结束时间
  for (const s of segs) {
    const t: string = s.text.replace(/\n/g, ' ').trim(); // 规整后的片段文本
    if (t.length === 0) {
      continue;
    }
    if (buf.length === 0) {
      start = s.start;
    }
    buf = buf.length === 0 ? t : `${buf} ${t}`;
    end = s.start + (s.dur > 0 ? s.dur : 0);
    if (/[.!?。！？]$/.test(buf) || buf.length >= 160) {
      out.push({ start: start, dur: end - start, text: buf });
      buf = '';
    }
  }
  if (buf.length > 0) {
    out.push({ start: start, dur: end - start, text: buf });
  }
  return out;
}

/**
 * 将个位数补成两位。
 * @param n 数字
 * @returns 两位字符串
 */
function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/**
 * 将毫秒数补成三位。
 * @param n 数字
 * @returns 三位字符串
 */
function pad3(n: number): string {
  if (n < 10) {
    return `00${n}`;
  }
  if (n < 100) {
    return `0${n}`;
  }
  return `${n}`;
}

/**
 * 把秒数格式化为时间戳。
 * @param sec 秒数
 * @param srt 是否输出 SRT 格式（逗号分隔毫秒）
 * @returns 时间戳字符串
 */
export function tsFmt(sec: number, srt: boolean = false): string {
  let s: number = sec < 0 ? 0 : Math.floor(sec);                       // 取整后的秒
  const ms: number = Math.floor(((sec < 0 ? 0 : sec) - s) * 1000);     // 毫秒部分
  const h: number = Math.floor(s / 3600);                             // 小时
  s = s % 3600;
  const m: number = Math.floor(s / 60);                               // 分钟
  s = s % 60;
  if (srt) {
    return `${pad2(h)}:${pad2(m)}:${pad2(s)},${pad3(ms)}`;
  }
  return h > 0 ? `${h}:${pad2(m)}:${pad2(s)}` : `${pad2(m)}:${pad2(s)}`;
}

/**
 * 将字幕片段拼成纯文本。
 * @param segs 字幕片段列表
 * @param timestamps 是否在每行前加时间戳
 * @param numbered 是否在每行前加序号
 * @param bilingual 是否在英文下附中文译文
 * @returns 纯文本
 */
export function buildText(segs: Segment[], timestamps: boolean, numbered: boolean = false, bilingual: boolean = false): string {
  const lines: string[] = []; // 输出行
  let i: number = 1;          // 行序号
  for (const seg of segs) {
    const t: string = seg.text.replace(/\n/g, ' ').trim(); // 规整后的单行文本
    if (t.length === 0) {
      continue;
    }
    const num: string = numbered ? `${i}. ` : '';                  // 序号前缀
    const ts: string = timestamps ? `[${tsFmt(seg.start)}] ` : ''; // 时间戳前缀
    let line: string = `${num}${ts}${t}`;                          // 当前行
    if (bilingual && seg.zh !== undefined && seg.zh.length > 0) {
      line = `${line}\n${seg.zh}`;
    }
    lines.push(line);
    i++;
  }
  return `${lines.join('\n')}\n`;
}

/**
 * 将字幕片段拼成 SRT 字幕。
 * @param segs 字幕片段列表
 * @param bilingual 是否在英文下附中文译文
 * @returns SRT 文本
 */
export function buildSrt(segs: Segment[], bilingual: boolean = false): string {
  const blocks: string[] = []; // SRT 块
  let i: number = 1;           // 序号
  for (const seg of segs) {
    const t: string = seg.text.trim(); // 去空白后的文本
    if (t.length === 0) {
      continue;
    }
    const end: number = seg.start + (seg.dur > 0 ? seg.dur : 0); // 结束时间
    let body: string = t;                                        // 字幕正文
    if (bilingual && seg.zh !== undefined && seg.zh.length > 0) {
      body = `${body}\n${seg.zh}`;
    }
    blocks.push(`${i}\n${tsFmt(seg.start, true)} --> ${tsFmt(end, true)}\n${body}\n`);
    i++;
  }
  return blocks.join('\n');
}
