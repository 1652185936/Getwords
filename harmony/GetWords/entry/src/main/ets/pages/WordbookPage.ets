import { router } from '@kit.ArkUI';
import {
  WordItem, MOCK_WORDS, Chip, FilterOption,
  statusStyle, typeStyle, cefrStyle, TYPE_FILTERS, CEFR_FILTERS
} from '../model/Word';
import { WordDataSource } from '../model/WordDataSource';

@Entry
@Component
struct WordbookPage {
  @State filterType: string = '';            // 类型筛选
  @State filterCefr: string = '';            // 难度筛选
  @State keyword: string = '';               // 搜索词
  @State resultCount: number = 0;            // 筛选结果数
  private ds: WordDataSource = new WordDataSource(); // 懒加载数据源

  aboutToAppear(): void {
    this.applyFilters();
  }

  /** 按类型/难度/关键字过滤，刷新数据源 */
  applyFilters(): void {
    const kw: string = this.keyword.trim().toLowerCase(); // 规整后的搜索词
    const list: WordItem[] = [];                          // 过滤结果
    for (const w of MOCK_WORDS) {
      if (this.filterType.length > 0 && w.type !== this.filterType) {
        continue;
      }
      if (this.filterCefr.length > 0 && w.cefr !== this.filterCefr) {
        continue;
      }
      if (kw.length > 0 && w.text.toLowerCase().indexOf(kw) < 0 && w.defZh.indexOf(kw) < 0) {
        continue;
      }
      list.push(w);
    }
    this.resultCount = list.length;
    this.ds.setItems(list);
  }

  /** 按状态统计 */
  countByStatus(status: number): number {
    let n: number = 0;
    for (const w of MOCK_WORDS) {
      if (w.status === status) {
        n++;
      }
    }
    return n;
  }

  /** 小色标徽章 */
  @Builder
  badge(c: Chip) {
    Text(c.label).fontSize(11).fontColor(c.color)
      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
      .backgroundColor(c.bg).borderRadius(6)
  }

  /** 顶部统计单元 */
  @Builder
  statCell(label: string, value: number, color: string) {
    Column() {
      Text(value.toString()).fontSize(22).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(12).fontColor('#888888').margin({ top: 2 })
    }
    .layoutWeight(1)
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(15).fontColor('#1A73E8')
          .onClick(() => {
            router.back();
          })
        Blank()
      }
      .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 12 })

      Text('📒 生词本').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 4, bottom: 12 })

      // 统计条
      Row() {
        this.statCell('新词', this.countByStatus(0), '#1A73E8')
        Divider().vertical(true).height(28).color('#EEEEEE')
        this.statCell('学习中', this.countByStatus(1), '#FF9500')
        Divider().vertical(true).height(28).color('#EEEEEE')
        this.statCell('已掌握', this.countByStatus(2), '#34C759')
      }
      .width('92%').constraintSize({ maxWidth: 720 }).padding({ top: 14, bottom: 14 })
      .backgroundColor('#FFFFFF').borderRadius(16)

      // 搜索
      Search({ placeholder: '搜索单词 / 释义…', value: this.keyword })
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 12 })
        .onChange((v: string) => {
          this.keyword = v;
          this.applyFilters();
        })

      // 类型筛选
      Scroll() {
        Row({ space: 8 }) {
          ForEach(TYPE_FILTERS, (f: FilterOption) => {
            Text(f.label).fontSize(13)
              .fontColor(this.filterType === f.value ? Color.White : '#555555')
              .backgroundColor(this.filterType === f.value ? '#1A73E8' : '#FFFFFF')
              .padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(16)
              .onClick(() => {
                this.filterType = f.value;
                this.applyFilters();
              })
          }, (f: FilterOption) => f.value)
        }
        .padding({ left: 1, right: 1 })
      }
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 10 })

      // 难度筛选
      Scroll() {
        Row({ space: 8 }) {
          ForEach(CEFR_FILTERS, (f: FilterOption) => {
            Text(f.label).fontSize(13)
              .fontColor(this.filterCefr === f.value ? Color.White : '#555555')
              .backgroundColor(this.filterCefr === f.value ? '#1A73E8' : '#FFFFFF')
              .padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(16)
              .onClick(() => {
                this.filterCefr = f.value;
                this.applyFilters();
              })
          }, (f: FilterOption) => f.value)
        }
        .padding({ left: 1, right: 1 })
      }
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 10 })

      // 复习入口：两种模式，不展示「待复习数量」（避免一上来就有压迫感）
      Row({ space: 10 }) {
        Button('📝 选择题')
          .layoutWeight(1).height(50).fontSize(15).fontWeight(FontWeight.Bold)
          .backgroundColor('#1A73E8')
          .onClick(() => {
            router.pushUrl({ url: 'pages/ReviewPage' });
          })
        Button('✍️ 拼写')
          .layoutWeight(1).height(50).fontSize(15).fontWeight(FontWeight.Bold)
          .backgroundColor('#34C759')
          .onClick(() => {
            router.pushUrl({ url: 'pages/SpellPage' });
          })
      }
      .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 12 })

      Text(`共 ${this.resultCount} 条`).fontSize(12).fontColor('#999999')
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 10, bottom: 2 })

      // 列表（懒加载）
      List({ space: 10 }) {
        LazyForEach(this.ds, (w: WordItem) => {
          ListItem() {
            Row() {
              Column() {
                Row() {
                  Text(w.text).fontSize(17).fontWeight(FontWeight.Medium)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  if (w.phonetic.length > 0) {
                    Text(w.phonetic).fontSize(12).fontColor('#999999').margin({ left: 8 })
                  }
                  if (w.starred) {
                    Text('⭐').fontSize(12).margin({ left: 6 })
                  }
                }
                .width('100%')

                if (w.defZh.length > 0) {
                  Text(w.defZh).fontSize(14).fontColor('#888888').margin({ top: 4 })
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                }

                // 元信息：类型 + 难度 + 日期
                Row({ space: 6 }) {
                  this.badge(typeStyle(w.type))
                  this.badge(cefrStyle(w.cefr))
                  Text(`📅 ${w.dateAdded}`).fontSize(11).fontColor('#BBBBBB')
                  if (w.tags.length > 0) {
                    Text(`#${w.tags[0]}`).fontSize(11).fontColor('#BBBBBB')
                  }
                }
                .margin({ top: 8 })
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Start)

              this.badge(statusStyle(w.status))
            }
            .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(14)
            .alignItems(VerticalAlign.Top)
          }
          .onClick(() => {
            router.pushUrl({ url: 'pages/WordDetailPage', params: { lemma: w.lemma } });
          })
        }, (w: WordItem) => w.lemma)
      }
      .layoutWeight(1).width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 6 }).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
