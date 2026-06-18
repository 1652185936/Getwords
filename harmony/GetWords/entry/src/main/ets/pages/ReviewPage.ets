import { router } from '@kit.ArkUI';
import { WordItem, MOCK_WORDS } from '../model/Word';
import { SrsState, initialState, applyGrade, GRADE_KNOWN, GRADE_FORGOT } from '../services/Srs';

@Entry
@Component
struct ReviewPage {
  @State queue: WordItem[] = MOCK_WORDS.filter((w: WordItem) => w.due).slice(0, 12); // 今日到期队列（每轮最多 12 个）
  @State idx: number = 0;             // 当前第几张
  @State options: string[] = [];      // 当前题的 4 个释义选项
  @State correctIdx: number = 0;      // 正确选项下标
  @State selectedIdx: number = -1;    // 已选下标，-1 表示未作答
  @State correctCount: number = 0;    // 答对计数
  @State done: boolean = false;       // 是否完成
  private states: SrsState[] = [];    // 每张卡的 SM-2 状态

  aboutToAppear(): void {
    this.states = this.queue.map((w: WordItem) => initialState(w.status));
    this.buildOptions();
  }

  /** 为当前词生成 4 个释义选项（1 正确 + 3 随机干扰），并打乱顺序 */
  buildOptions(): void {
    const correct: string = this.queue[this.idx].defZh; // 正确释义
    const pool: string[] = [];                          // 干扰项候选池
    for (const w of MOCK_WORDS) {
      if (w.defZh.length > 0 && w.defZh !== correct && pool.indexOf(w.defZh) < 0) {
        pool.push(w.defZh);
      }
    }
    const opts: string[] = [correct]; // 选项集合
    while (opts.length < 4 && pool.length > 0) {
      const r: number = Math.floor(Math.random() * pool.length); // 随机取一个干扰项
      opts.push(pool[r]);
      pool.splice(r, 1);
    }
    // Fisher-Yates 打乱
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    this.options = opts;
    this.correctIdx = opts.indexOf(correct);
  }

  /**
   * 选中一个选项：客观判对错 → 喂给 SM-2。
   * @param i 选项下标
   */
  select(i: number): void {
    if (this.selectedIdx !== -1) {
      return; // 已作答，忽略
    }
    this.selectedIdx = i;
    const right: boolean = i === this.correctIdx; // 是否答对
    this.states[this.idx] = applyGrade(this.states[this.idx], right ? GRADE_KNOWN : GRADE_FORGOT);
    if (right) {
      this.correctCount++;
    }
  }

  /** 进入下一题或完成 */
  next(): void {
    if (this.idx + 1 >= this.queue.length) {
      this.done = true;
      return;
    }
    this.idx++;
    this.selectedIdx = -1;
    this.buildOptions();
  }

  /** 选项底色 */
  optBg(i: number): string {
    if (this.selectedIdx === -1) {
      return '#FFFFFF';
    }
    if (i === this.correctIdx) {
      return '#E7F8EC';
    }
    if (i === this.selectedIdx) {
      return '#FFEBEA';
    }
    return '#FFFFFF';
  }

  /** 选项文字色 */
  optColor(i: number): string {
    if (this.selectedIdx === -1) {
      return '#222222';
    }
    if (i === this.correctIdx) {
      return '#1E9E5A';
    }
    if (i === this.selectedIdx) {
      return '#C0392B';
    }
    return '#AAAAAA';
  }

  /** 单个选项 */
  @Builder
  optionButton(i: number) {
    Row() {
      Text(this.options[i]).fontSize(16).fontColor(this.optColor(i))
        .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.selectedIdx !== -1 && i === this.correctIdx) {
        Text('✓').fontSize(18).fontColor('#34C759')
      } else if (this.selectedIdx === i && i !== this.correctIdx) {
        Text('✗').fontSize(18).fontColor('#FF3B30')
      }
    }
    .width('100%').padding(16).borderRadius(14)
    .backgroundColor(this.optBg(i))
    .border({ width: this.selectedIdx === -1 ? 1 : 0, color: '#EEEEEE' })
    .onClick(() => {
      this.select(i);
    })
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text(this.done ? '复习完成' : `${this.idx + 1} / ${this.queue.length}`)
          .fontSize(15).fontColor('#666666')
        Blank()
        Text('✕').fontSize(20).fontColor('#999999')
          .onClick(() => {
            router.back();
          })
      }
      .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 16 })

      if (!this.done) {
        Progress({ value: this.idx, total: this.queue.length })
          .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 10 }).color('#1A73E8')

        // 题面：英文词
        Column() {
          Text(this.queue[this.idx].text).fontSize(32).fontWeight(FontWeight.Bold)
            .width('100%').textAlign(TextAlign.Center)
          if (this.queue[this.idx].phonetic.length > 0) {
            Text(this.queue[this.idx].phonetic).fontSize(17).fontColor('#888888').margin({ top: 8 })
          }
          Text('选择正确的中文释义').fontSize(13).fontColor('#BBBBBB').margin({ top: 16 })
        }
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 20 }).padding(24)
        .backgroundColor('#FFFFFF').borderRadius(20)

        // 4 个选项
        Column({ space: 12 }) {
          this.optionButton(0)
          this.optionButton(1)
          this.optionButton(2)
          this.optionButton(3)
        }
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 18 })

        Blank()

        // 作答后出现「下一题」
        if (this.selectedIdx !== -1) {
          Button(this.idx + 1 >= this.queue.length ? '完成' : '下一题 →')
            .width('92%').constraintSize({ maxWidth: 720 }).height(50).margin({ bottom: 20 }).backgroundColor('#1A73E8')
            .onClick(() => {
              this.next();
            })
        }
      } else {
        // 完成页
        Column() {
          Text('🎉').fontSize(64)
          Text('今日复习完成！').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 12 })
          Text(`答对 ${this.correctCount} / ${this.queue.length} · 打卡 +1 🔥`)
            .fontSize(15).fontColor('#888888').margin({ top: 8 })
          Button('返回生词本')
            .width('70%').height(50).margin({ top: 30 }).backgroundColor('#1A73E8')
            .onClick(() => {
              router.back();
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
