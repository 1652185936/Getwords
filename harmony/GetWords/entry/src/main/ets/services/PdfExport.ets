import { Segment, tsFmt } from './Subtitles';

/**
 * 转义 HTML 特殊字符，避免破坏页面结构。
 * @param s 原始字符串
 * @returns 转义后的字符串
 */
function escapeHtml(s: string): string {
  let r: string = s;            // 逐步替换的中间结果
  r = r.replace(/&/g, '&amp;');
  r = r.replace(/</g, '&lt;');
  r = r.replace(/>/g, '&gt;');
  r = r.replace(/"/g, '&quot;');
  return r;
}

/**
 * 生成与参考排版一致的 HTML（标题 + 左侧时间戳 + 右侧句子 + 留白），用于渲染成 PDF。
 * @param title 文档标题（视频标题）
 * @param segs 字幕片段列表
 * @param timestamps 是否显示时间戳列
 * @param bilingual 是否在英文下附中文译文
 * @returns 完整 HTML 字符串
 */
export function buildHtml(title: string, segs: Segment[], timestamps: boolean, bilingual: boolean): string {
  const rows: string[] = []; // 每条字幕的 HTML 行
  for (const seg of segs) {
    const en: string = escapeHtml(seg.text.replace(/\n/g, ' ').trim()); // 英文原文
    if (en.length === 0) {
      continue;
    }
    // 时间戳单元格（按需显示）
    const tsCell: string = timestamps
      ? `<div class="ts">${tsFmt(seg.start)}</div>`
      : '';
    // 中文译文行（按需显示）
    const zhLine: string = (bilingual && seg.zh !== undefined && seg.zh.length > 0)
      ? `<div class="zh">${escapeHtml(seg.zh)}</div>`
      : '';
    rows.push(`<div class="row">${tsCell}<div class="tx">${en}${zhLine}</div></div>`);
  }
  const safeTitle: string = escapeHtml(title.length > 0 ? title : '字幕导出'); // 安全标题
  // 内联 CSS，尽量还原参考 PDF 的版式
  return `<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">
<style>
  * { box-sizing: border-box; }
  body { margin: 0; color: #1f1f1f;
    font-family: -apple-system, "HarmonyOS Sans", "PingFang SC", "Microsoft YaHei", sans-serif; }
  h1 { font-size: 22px; font-weight: 700; line-height: 1.35; margin: 0 0 28px 0; }
  .row { display: flex; align-items: flex-start; margin-bottom: 28px; page-break-inside: avoid; }
  .ts { flex: 0 0 64px; width: 64px; color: #9aa0a6; font-size: 12px; line-height: 1.6;
    font-family: "SF Mono", Consolas, monospace; padding-top: 2px; }
  .tx { flex: 1; font-size: 15px; line-height: 1.65; }
  .zh { color: #555; font-size: 14px; line-height: 1.6; margin-top: 3px; }
</style></head><body>
<h1>${safeTitle}</h1>
${rows.join('\n')}
</body></html>`;
}
