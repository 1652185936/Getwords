import { router } from '@kit.ArkUI';
import {
  WordItem, MOCK_WORDS, RichDetail, RICH_DETAIL, Chip,
  typeStyle, cefrStyle, statusStyle
} from '../model/Word';

@Entry
@Component
struct WordDetailPage {
  @State word: WordItem = MOCK_WORDS[0];                                       // 当前词
  @State rich: RichDetail = { defEn: '', similar: [], root: '', forms: '' };   // 全解附加信息
  @State starred: boolean = false;                                            // 收藏状态

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string>; // 路由参数
    if (p !== undefined && p !== null && p['lemma'] !== undefined) {
      for (const w of MOCK_WORDS) {
        if (w.lemma === p['lemma']) {
          this.word = w;
          break;
        }
      }
    }
    this.starred = this.word.starred;
    const r: RichDetail | undefined = RICH_DETAIL[this.word.lemma]; // 全解数据
    if (r !== undefined) {
      this.rich = r;
    }
  }

  /** 区块标题 */
  @Builder
  sectionTitle(t: string) {
    Text(t).fontSize(13).fontColor('#1A73E8').fontWeight(FontWeight.Medium).margin({ top: 22, bottom: 8 })
  }

  /** 小色标 */
  @Builder
  badge(c: Chip) {
    Text(c.label).fontSize(12).fontColor(c.color)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 }).backgroundColor(c.bg).borderRadius(6)
  }

  /** 白底卡片里的文字段 */
  @Builder
  card(content: string) {
    Text(content).fontSize(15).fontColor('#444444')
      .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(12)
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('‹ 返回').fontSize(15).fontColor('#1A73E8')
          .onClick(() => {
            router.back();
          })
        Blank()
        Text(this.starred ? '★' : '☆').fontSize(22).fontColor(this.starred ? '#FFB300' : '#BBBBBB')
          .onClick(() => {
            this.starred = !this.starred;
          })
      }
      .width('100%').padding({ left: 20, right: 20, top: 14, bottom: 6 })

      Scroll() {
        // 自适应：内容列限制最大宽度并居中 —— 手机满屏，平板/电脑居中不拉伸
        Column() {
          Column() {
            // 词头
            Row() {
              Text(this.word.text).fontSize(30).fontWeight(FontWeight.Bold)
              if (this.word.phonetic.length > 0) {
                Text(this.word.phonetic).fontSize(16).fontColor('#888888').margin({ left: 12 })
              }
            }
            .width('100%')

            Row({ space: 6 }) {
              this.badge(typeStyle(this.word.type))
              this.badge(cefrStyle(this.word.cefr))
              this.badge(statusStyle(this.word.status))
            }
            .width('100%').margin({ top: 10 })

            // 释义
            Text(`${this.word.pos}  ${this.word.defZh}`)
              .fontSize(18).fontColor('#222222').width('100%').margin({ top: 16 })

            // 例句（含配图占位）
            this.sectionTitle('例句')
            Column() {
              if (this.word.example.length > 0) {
                Text(this.word.example).fontSize(15).fontColor('#333333').width('100%')
                Text(this.word.exampleZh).fontSize(14).fontColor('#888888').width('100%').margin({ top: 4 })
              } else {
                Text(this.word.context).fontSize(15).fontColor('#333333').width('100%')
              }
              Row() {
                Text('🖼 配图（待接入）').fontSize(13).fontColor('#BBBBBB')
              }
              .width('100%').height(90).justifyContent(FlexAlign.Center)
              .backgroundColor('#F0F0F2').borderRadius(10).margin({ top: 10 })
            }
            .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(12)
            .alignItems(HorizontalAlign.Start)

            // 形近词
            if (this.rich.similar.length > 0) {
              this.sectionTitle('形近词')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.rich.similar, (s: string) => {
                  Text(s).fontSize(14).fontColor('#1A73E8')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor('#EEF3FE').borderRadius(8).margin({ right: 8, bottom: 8 })
                }, (s: string) => s)
              }
              .width('100%')
            }

            // 词根词缀
            if (this.rich.root.length > 0) {
              this.sectionTitle('词根词缀')
              this.card(this.rich.root)
            }

            // 英文释义
            if (this.rich.defEn.length > 0) {
              this.sectionTitle('英文释义')
              this.card(this.rich.defEn)
            }

            // 单词变形
            if (this.rich.forms.length > 0) {
              this.sectionTitle('单词变形')
              this.card(this.rich.forms)
            }

            // 来源
            this.sectionTitle('来源')
            this.card(`📍 ${this.word.context}`)
            Text(`${this.word.sourceTitle} · ${this.word.sourceTime} · 收录 ${this.word.dateAdded}`)
              .fontSize(12).fontColor('#AAAAAA').width('100%').margin({ top: 8, bottom: 28 })
          }
          .constraintSize({ maxWidth: 720 }).width('100%')
          .padding({ left: 20, right: 20 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1).width('100%').align(Alignment.Top)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
