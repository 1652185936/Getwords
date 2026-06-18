import {
  fetchTranscript,
  mergeSegments,
  buildText,
  buildSrt,
  tsFmt,
  Segment,
  FetchResult
} from '../services/Subtitles';
import { translateLines } from '../services/Translate';
import { buildHtml } from '../services/PdfExport';
import { promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

@Entry
@Component
struct Index {
  @State url: string = '';                 // 用户输入的链接
  @State status: string = '';              // 状态提示文本
  @State segments: Segment[] = [];         // 当前字幕片段
  @State lang: string = '';                // 字幕语言码
  @State showTs: boolean = false;          // 是否显示时间戳
  @State loading: boolean = false;         // 是否正在获取字幕
  @State showZh: boolean = false;          // 是否显示/导出中文译文
  @State showKey: boolean = false;         // 是否展开 API Key 设置
  @State translating: boolean = false;     // 是否正在翻译
  @State videoTitle: string = '';          // 视频标题（用作 PDF 标题）
  @State exporting: boolean = false;       // 是否正在导出 PDF（控制隐藏 Web 临时可见）
  @StorageLink('dsKey') dsKey: string = ''; // DeepSeek API Key（持久化）
  private pdfPending: boolean = false;      // 是否有待生成的 PDF（等网页加载完）
  private webController: webview.WebviewController = new webview.WebviewController(); // 隐藏 Web 控制器，用于渲染 PDF

  build() {
    Stack() {
      Column() {
      Text('🎬 GetWords 字幕提取')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 18, bottom: 10 })

      TextInput({ placeholder: '粘贴 YouTube 链接，例如 https://youtu.be/...', text: this.url })
        .width('92%')
        .height(46)
        .onChange((value: string) => {
          this.url = value;
        })

      Row() {
        Button(this.loading ? '获取中…' : '获取字幕')
          .enabled(!this.loading && !this.translating)
          .layoutWeight(1)
          .onClick(() => {
            this.onFetch();
          })
        Button(this.translating ? '翻译中…' : '翻译中文')
          .enabled(!this.loading && !this.translating)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.onTranslate();
          })
      }
      .width('92%')
      .margin({ top: 12 })

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.showTs })
          .onChange((isOn: boolean) => {
            this.showTs = isOn;
          })
        Text('时间戳').fontSize(14).margin({ left: 6 })
        Toggle({ type: ToggleType.Switch, isOn: this.showZh })
          .margin({ left: 18 })
          .onChange((isOn: boolean) => {
            this.showZh = isOn;
          })
        Text('中英').fontSize(14).margin({ left: 6 })
        Blank()
        Button(this.showKey ? '收起 Key' : '⚙ Key')
          .fontSize(13)
          .height(34)
          .backgroundColor('#EEEEEE')
          .fontColor('#333333')
          .onClick(() => {
            this.showKey = !this.showKey;
          })
      }
      .width('92%')
      .margin({ top: 10 })

      if (this.showKey) {
        Row() {
          TextInput({ placeholder: '输入 DeepSeek API Key（sk-...）', text: this.dsKey })
            .type(InputType.Password)
            .layoutWeight(1)
            .height(44)
            .onChange((value: string) => {
              this.dsKey = value;
            })
          Button('完成')
            .margin({ left: 8 })
            .onClick(() => {
              this.showKey = false;
              promptAction.showToast({ message: 'Key 已保存' });
            })
        }
        .width('92%')
        .margin({ top: 8 })
      }

      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(13)
          .fontColor('#888888')
          .width('92%')
          .margin({ top: 8 })
      }

      List() {
        ForEach(this.segments, (seg: Segment, index: number) => {
          ListItem() {
            Column() {
              if (this.showTs) {
                Text(tsFmt(seg.start))
                  .fontSize(12)
                  .fontColor('#1A73E8')
                  .margin({ bottom: 2 })
              }
              Text(seg.text)
                .fontSize(16)
                .lineHeight(24)
                .width('100%')
              if (this.showZh && seg.zh !== undefined && seg.zh.length > 0) {
                Text(seg.zh)
                  .fontSize(15)
                  .fontColor('#555555')
                  .lineHeight(22)
                  .width('100%')
                  .margin({ top: 3 })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: this.showTs ? 10 : 4, bottom: this.showTs ? 10 : 4 })
          }
        }, (seg: Segment, index: number) => index.toString() + '-' + seg.start.toString())
      }
      .layoutWeight(1)
      .width('92%')
      .margin({ top: 10 })
      .alignListItem(ListItemAlign.Start)
      .scrollBar(BarState.Auto)

      Row() {
        Button('导出 PDF')
          .layoutWeight(1)
          .onClick(() => {
            this.onExportPdf();
          })
        Button('导出 TXT')
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.onExport('txt');
          })
        Button('导出 SRT')
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.onExport('srt');
          })
        Button('复制')
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.onCopy();
          })
      }
      .width('92%')
      .margin({ top: 10, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      // 用于渲染 PDF 的 Web：导出时置顶可见以确保真正渲染，平时隐藏
      Web({ src: 'about:blank', controller: this.webController })
        .width('100%')
        .height('100%')
        .visibility(this.exporting ? Visibility.Visible : Visibility.Hidden)
        .onPageEnd(() => {
          if (this.pdfPending) {
            this.pdfPending = false;
            this.savePdf();
          }
        })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 获取并合并字幕。
   * @returns Promise<void>
   */
  async onFetch(): Promise<void> {
    if (this.url.trim().length === 0) {
      this.status = '请输入 YouTube 链接';
      return;
    }
    this.loading = true;
    this.status = '正在获取字幕…';
    this.segments = [];
    this.showZh = false;
    try {
      const result: FetchResult = await fetchTranscript(this.url, this.lang.length > 0 ? this.lang : undefined);
      this.segments = mergeSegments(result.segments);
      this.lang = result.lang;
      this.videoTitle = result.title;
      this.status = `完成：${this.segments.length} 行字幕（${result.lang}）`;
    } catch (err) {
      const e = err as BusinessError;
      this.status = '失败：' + (e.message ?? '未知错误');
    } finally {
      this.loading = false;
    }
  }

  /**
   * 调用 DeepSeek 把当前字幕翻译成中文。
   * @returns Promise<void>
   */
  async onTranslate(): Promise<void> {
    if (this.dsKey.trim().length === 0) {
      this.status = '请先点「⚙ Key」设置 DeepSeek API Key';
      this.showKey = true;
      return;
    }
    if (this.segments.length === 0) {
      this.status = '请先获取字幕';
      return;
    }
    this.translating = true;
    this.status = '正在翻译…';
    try {
      const lines: string[] = this.segments.map((s: Segment) => s.text); // 待译英文行
      const zh: string[] = await translateLines(this.dsKey, lines, (done: number) => {
        this.status = `翻译中… ${done}/${lines.length}`;
      });
      const merged: Segment[] = []; // 带译文的新片段
      for (let i = 0; i < this.segments.length; i++) {
        const s: Segment = this.segments[i];
        merged.push({ start: s.start, dur: s.dur, text: s.text, zh: i < zh.length ? zh[i] : '' });
      }
      this.segments = merged;
      this.showZh = true;
      this.status = `翻译完成：${this.segments.length} 行（中英）`;
    } catch (err) {
      const e = err as BusinessError;
      this.status = '翻译失败：' + (e.message ?? '未知错误');
    } finally {
      this.translating = false;
    }
  }

  /**
   * 复制全文到剪贴板（中英开关开启且已翻译时复制中英对照）。
   */
  onCopy(): void {
    if (this.segments.length === 0) {
      this.status = '还没有字幕，先获取';
      return;
    }
    const text: string = buildText(this.segments, this.showTs, false, this.showZh); // 全文文本
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      promptAction.showToast({ message: '已复制到剪贴板' });
    }).catch(() => {
      this.status = '复制失败';
    });
  }

  /**
   * 导出字幕到文件。
   * @param fmt 导出格式：txt 或 srt
   * @returns Promise<void>
   */
  async onExport(fmt: string): Promise<void> {
    if (this.segments.length === 0) {
      this.status = '还没有字幕，先获取';
      return;
    }
    // 中英开关开启时导出中英对照，否则纯英文
    const content: string = fmt === 'srt'
      ? buildSrt(this.segments, this.showZh)
      : buildText(this.segments, true, true, this.showZh);
    const fileName: string = 'transcript_' + Date.now() + '.' + fmt; // 文件名
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await documentPicker.save(options);
      if (uris === undefined || uris.length === 0) {
        return;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);
      promptAction.showToast({ message: '已保存：' + fileName });
    } catch (err) {
      const e = err as BusinessError;
      this.status = '导出失败：' + (e.message ?? '未知错误');
    }
  }

  /**
   * 触发 PDF 导出：把字幕渲染成 HTML 加载进隐藏 Web，待加载完成后生成 PDF。
   */
  onExportPdf(): void {
    if (this.segments.length === 0) {
      this.status = '还没有字幕，先获取';
      return;
    }
    this.status = '正在生成 PDF…';
    const html: string = buildHtml(this.videoTitle, this.segments, this.showTs, this.showZh); // 排版后的 HTML
    this.pdfPending = true;
    this.exporting = true; // 让隐藏 Web 置顶可见，确保内容真正渲染
    try {
      // base64 编码后加载，避免 HTML 里的 # 等字符被 loadData 当作 URL 截断
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(html); // UTF-8 字节
      const b64: string = new util.Base64Helper().encodeToStringSync(bytes); // base64 字符串
      this.webController.loadData(b64, 'text/html', 'base64');
    } catch (err) {
      this.pdfPending = false;
      this.exporting = false;
      const e = err as BusinessError;
      this.status = 'PDF 生成失败：' + (e.message ?? '未知错误');
    }
  }

  /**
   * 把已加载的网页渲染成 PDF 并保存到用户选择的位置。
   * @returns Promise<void>
   */
  async savePdf(): Promise<void> {
    try {
      // 等待网页完成渲染再截取
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 600);
      });
      // A4 纸张（英寸）与页边距
      const config: webview.PdfConfiguration = {
        width: 8.27,
        height: 11.69,
        marginTop: 0.6,
        marginBottom: 0.6,
        marginLeft: 0.6,
        marginRight: 0.6,
        shouldPrintBackground: true
      };
      const pdfData: webview.PdfData = await this.webController.createPdf(config); // PDF 数据
      const bytes: Uint8Array = pdfData.pdfArrayBuffer();                          // PDF 字节
      const buf: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength); // 精确字节
      const context = getContext(this) as common.UIAbilityContext;                // 应用上下文
      const options = new picker.DocumentSaveOptions();                           // 保存选项
      options.newFileNames = [`transcript_${Date.now()}.pdf`];
      const documentPicker = new picker.DocumentViewPicker(context);              // 文件保存选择器
      const uris: string[] = await documentPicker.save(options);                  // 用户选择的保存地址
      if (uris === undefined || uris.length === 0) {
        this.exporting = false;
        this.status = '已取消导出';
        return;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE); // 目标文件
      fs.writeSync(file.fd, buf);
      fs.closeSync(file);
      this.exporting = false;
      promptAction.showToast({ message: 'PDF 已保存' });
      this.status = 'PDF 已导出';
    } catch (err) {
      this.exporting = false;
      const e = err as BusinessError;
      this.status = 'PDF 导出失败：' + (e.message ?? '未知错误');
    }
  }
}
