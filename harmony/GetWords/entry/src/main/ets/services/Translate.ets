import { http } from '@kit.NetworkKit';

/** DeepSeek chat/completions 接口地址（OpenAI 兼容） */
const DEEPSEEK_URL: string = 'https://api.deepseek.com/chat/completions';

/** 每批送去翻译的最大行数，控制单次请求体量 */
const BATCH_SIZE: number = 20;

/** 一条对话消息 */
interface DSMessage {
  role: string;    // 角色：system / user / assistant
  content: string; // 文本内容
}

/** 请求体 */
interface DSRequest {
  model: string;        // 模型名
  messages: DSMessage[]; // 对话消息
  temperature: number;  // 采样温度
  stream: boolean;      // 是否流式
}

/** 单个候选回复 */
interface DSChoice {
  message?: DSMessage; // 回复消息
}

/** 接口返回体（仅声明用到的字段） */
interface DSResponse {
  choices?: DSChoice[]; // 候选回复列表
}

/**
 * 调用 DeepSeek 完成一次对话，返回回复文本。
 * @param key DeepSeek API Key
 * @param prompt 用户提示词
 * @returns 模型回复文本
 */
async function dsChat(key: string, prompt: string): Promise<string> {
  const request: http.HttpRequest = http.createHttp(); // 本次请求对象
  try {
    const body: DSRequest = {
      model: 'deepseek-chat',
      messages: [
        { role: 'system', content: '你是专业的字幕翻译，把英文准确、自然地翻译成简体中文。' },
        { role: 'user', content: prompt }
      ],
      temperature: 0,
      stream: false
    };
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Authorization': `Bearer ${key}`,
        'Content-Type': 'application/json'
      } as Record<string, string>,
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 30000,
      readTimeout: 60000
    };
    const resp: http.HttpResponse = await request.request(DEEPSEEK_URL, options); // 服务器响应
    if (resp.responseCode !== 200) {
      throw new Error(`DeepSeek HTTP ${resp.responseCode}`);
    }
    const parsed: DSResponse = JSON.parse(resp.result as string) as DSResponse; // 解析后的响应
    const choices: DSChoice[] | undefined = parsed.choices;                     // 候选列表
    if (choices === undefined || choices.length === 0) {
      throw new Error('DeepSeek 返回为空');
    }
    const msg: DSMessage | undefined = choices[0].message; // 首个候选的回复消息
    if (msg === undefined) {
      throw new Error('DeepSeek 返回为空');
    }
    return msg.content;
  } finally {
    request.destroy();
  }
}

/**
 * 解析带序号的译文，按序号对齐回原始顺序。
 * @param text 模型返回的带序号译文
 * @param count 本批行数
 * @returns 长度为 count 的译文数组（缺失项为空串）
 */
function parseNumbered(text: string, count: number): string[] {
  const arr: string[] = []; // 结果数组
  for (let k = 0; k < count; k++) {
    arr.push('');
  }
  const rows: string[] = text.split('\n'); // 按行拆分
  for (const row of rows) {
    const m: RegExpMatchArray | null = row.match(/^\s*(\d+)\s*[.、:：]\s*(.+)$/); // 匹配「序号. 译文」
    if (m !== null) {
      const idx: number = parseInt(m[1], 10) - 1; // 0 基序号
      if (idx >= 0 && idx < count) {
        arr[idx] = m[2].trim();
      }
    }
  }
  return arr;
}

/**
 * 批量把英文行翻译成简体中文，返回与输入等长、顺序一致的译文数组。
 * @param key DeepSeek API Key
 * @param lines 待翻译的英文行
 * @param onProgress 进度回调，参数为已完成行数
 * @returns 译文数组
 */
export async function translateLines(
  key: string,
  lines: string[],
  onProgress?: (done: number) => void
): Promise<string[]> {
  const result: string[] = []; // 全部译文
  for (let i = 0; i < lines.length; i += BATCH_SIZE) {
    const chunk: string[] = lines.slice(i, i + BATCH_SIZE); // 当前批次英文行
    const numbered: string[] = [];                          // 带序号的输入行
    for (let k = 0; k < chunk.length; k++) {
      numbered.push(`${k + 1}. ${chunk[k]}`);
    }
    const prompt: string =
      `把下面带序号的英文逐行翻译成简体中文。要求：只输出译文，保留原序号与行数，一行一句，不要添加任何解释。\n\n${numbered.join('\n')}`;
    const out: string = await dsChat(key, prompt);          // 模型回复
    const zh: string[] = parseNumbered(out, chunk.length);  // 对齐后的译文
    for (const z of zh) {
      result.push(z);
    }
    if (onProgress !== undefined) {
      onProgress(result.length);
    }
  }
  return result;
}
