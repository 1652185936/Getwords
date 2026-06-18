import {
  fetchTranscript,
  buildText,
  buildSrt,
  tsFmt,
  Segment,
  FetchResult
} from '../services/Subtitles';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  @State url: string = '';
  @State status: string = '';
  @State segments: Segment[] = [];
  @State lang: string = '';
  @State showTs: boolean = false;
  @State loading: boolean = false;

  build() {
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
          .enabled(!this.loading)
          .layoutWeight(1)
          .onClick(() => {
            this.onFetch();
          })
        Toggle({ type: ToggleType.Switch, isOn: this.showTs })
          .margin({ left: 12, right: 6 })
          .onChange((isOn: boolean) => {
            this.showTs = isOn;
          })
        Text('时间戳').fontSize(14)
      }
      .width('92%')
      .margin({ top: 12 })

      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(13)
          .fontColor('#888888')
          .width('92%')
          .margin({ top: 8 })
      }

      Scroll() {
        Column() {
          ForEach(this.segments, (seg: Segment, index: number) => {
            Row() {
              if (this.showTs) {
                Text(tsFmt(seg.start))
                  .fontSize(12)
                  .fontColor('#1A73E8')
                  .width(60)
              }
              Text(seg.text)
                .fontSize(15)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ top: 5, bottom: 5 })
          }, (seg: Segment, index: number) => index.toString() + '-' + seg.start.toString())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('92%')
      .margin({ top: 10 })
      .align(Alignment.TopStart)

      Row() {
        Button('导出 TXT')
          .layoutWeight(1)
          .onClick(() => {
            this.onExport('txt');
          })
        Button('导出 SRT')
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })
          .onClick(() => {
            this.onExport('srt');
          })
        Button('复制')
          .layoutWeight(1)
          .onClick(() => {
            this.onCopy();
          })
      }
      .width('92%')
      .margin({ top: 10, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  async onFetch(): Promise<void> {
    if (this.url.trim().length === 0) {
      this.status = '请输入 YouTube 链接';
      return;
    }
    this.loading = true;
    this.status = '正在获取字幕…';
    this.segments = [];
    try {
      const result: FetchResult = await fetchTranscript(this.url, this.lang.length > 0 ? this.lang : undefined);
      this.segments = result.segments;
      this.lang = result.lang;
      this.status = '完成：' + result.segments.length + ' 行字幕（' + result.lang + '）';
    } catch (err) {
      const e = err as BusinessError;
      this.status = '失败：' + (e.message ?? '未知错误');
    } finally {
      this.loading = false;
    }
  }

  onCopy(): void {
    if (this.segments.length === 0) {
      this.status = '还没有字幕，先获取';
      return;
    }
    const text: string = buildText(this.segments, this.showTs);
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      promptAction.showToast({ message: '已复制到剪贴板' });
    }).catch(() => {
      this.status = '复制失败';
    });
  }

  async onExport(fmt: string): Promise<void> {
    if (this.segments.length === 0) {
      this.status = '还没有字幕，先获取';
      return;
    }
    const content: string = fmt === 'srt' ? buildSrt(this.segments) : buildText(this.segments, this.showTs);
    const fileName: string = 'transcript_' + Date.now() + '.' + fmt;
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
}
