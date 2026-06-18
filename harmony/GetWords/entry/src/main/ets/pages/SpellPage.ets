import { router } from '@kit.ArkUI';
import { WordItem, MOCK_WORDS } from '../model/Word';
import { SrsState, initialState, applyGrade, GRADE_KNOWN, GRADE_FORGOT } from '../services/Srs';

@Entry
@Component
struct SpellPage {
  // 拼写只针对「单词」类型的到期词，每轮最多 12 个（避免一次太多）
  @State queue: WordItem[] = MOCK_WORDS.filter((w: WordItem) => w.due && w.type === 'word').slice(0, 12);
  @State idx: number = 0;          // 当前第几个
  @State input: string = '';       // 用户输入/手写识别结果
  @State checked: boolean = false; // 是否已检查
  @State correct: boolean = false; // 本题是否正确
  @State revealed: number = 0;     // 已提示的字母数
  @State correctCount: number = 0; // 答对计数
  @State done: boolean = false;    // 是否完成
  private states: SrsState[] = []; // 每张卡的 SM-2 状态

  aboutToAppear(): void {
    this.states = this.queue.map((w: WordItem) => initialState(w.status));
  }

  /** 当前目标拼写 */
  answer(): string {
    return this.queue[this.idx].text;
  }

  /** 字母格下标数组 */
  slotIndexes(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < this.answer().length; i++) {
      arr.push(i);
    }
    return arr;
  }

  /** 第 i 个字母是否拼对 */
  isLetterRight(i: number): boolean {
    return this.input.toLowerCase().charAt(i) === this.answer().toLowerCase().charAt(i);
  }

  /** 字母格显示的字符 */
  slotChar(i: number): string {
    if (this.checked) {
      return this.answer().charAt(i);
    }
    if (i < this.input.length) {
      return this.input.charAt(i);
    }
    return '';
  }

  /** 字母格文字色 */
  slotColor(i: number): string {
    if (!this.checked) {
      return '#222222';
    }
    return this.isLetterRight(i) ? '#1E9E5A' : '#C0392B';
  }

  /** 字母格底色 */
  slotBg(i: number): string {
    if (!this.checked) {
      return '#FFFFFF';
    }
    return this.isLetterRight(i) ? '#E7F8EC' : '#FFEBEA';
  }

  /** 检查拼写 → 客观判对错喂给 SM-2 */
  check(): void {
    if (this.checked) {
      return;
    }
    this.correct = this.input.trim().toLowerCase() === this.answer().toLowerCase();
    this.checked = true;
    this.states[this.idx] = applyGrade(this.states[this.idx], this.correct ? GRADE_KNOWN : GRADE_FORGOT);
    if (this.correct) {
      this.correctCount++;
    }
  }

  /** 提示：补出下一个字母 */
  hint(): void {
    if (this.checked) {
      return;
    }
    this.revealed = Math.min(this.answer().length, this.revealed + 1);
    this.input = this.answer().substring(0, this.revealed);
  }

  /** 下一题 */
  next(): void {
    if (this.idx + 1 >= this.queue.length) {
      this.done = true;
      return;
    }
    this.idx++;
    this.input = '';
    this.checked = false;
    this.correct = false;
    this.revealed = 0;
  }

  /** 单个字母格 */
  @Builder
  slot(i: number) {
    Text(this.slotChar(i))
      .fontSize(24).fontWeight(FontWeight.Medium).fontColor(this.slotColor(i))
      .width(40).height(48).textAlign(TextAlign.Center)
      .backgroundColor(this.slotBg(i)).borderRadius(8)
      .border({ width: 1, color: '#E5E5E5' })
      .margin({ left: 3, right: 3, bottom: 6 })
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text(this.done ? '拼写完成' : `${this.idx + 1} / ${this.queue.length}`)
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

        // 题面：释义 + 音标（英文藏起来让你拼）
        Column() {
          Text(this.queue[this.idx].defZh).fontSize(24).fontWeight(FontWeight.Bold)
            .width('100%').textAlign(TextAlign.Center)
          Text(this.queue[this.idx].phonetic).fontSize(16).fontColor('#888888').margin({ top: 8 })
          Text('拼出这个单词').fontSize(13).fontColor('#BBBBBB').margin({ top: 14 })
        }
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 20 }).padding(24)
        .backgroundColor('#FFFFFF').borderRadius(20)

        // 字母格
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.slotIndexes(), (i: number) => {
            this.slot(i)
          }, (i: number) => i.toString())
        }
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 22 })

        // 输入（键盘或系统手写笔）
        TextInput({ placeholder: '键盘输入，或用手写笔书写…', text: this.input })
          .enabled(!this.checked)
          .width('92%').constraintSize({ maxWidth: 720 }).height(50).margin({ top: 16 })
          .onChange((v: string) => {
            this.input = v;
          })

        // 结果提示
        if (this.checked) {
          Text(this.correct ? '✅ 拼写正确！' : `❌ 正确拼写：${this.answer()}`)
            .fontSize(15).fontColor(this.correct ? '#34C759' : '#FF3B30').margin({ top: 14 })
        }

        Blank()

        // 操作
        Row({ space: 10 }) {
          Button('💡 提示').layoutWeight(1).height(50)
            .backgroundColor('#EEEEEE').fontColor('#333333')
            .enabled(!this.checked)
            .onClick(() => {
              this.hint();
            })
          Button(this.checked ? (this.idx + 1 >= this.queue.length ? '完成' : '下一题 →') : '检查')
            .layoutWeight(2).height(50).backgroundColor('#1A73E8')
            .onClick(() => {
              if (this.checked) {
                this.next();
              } else {
                this.check();
              }
            })
        }
        .width('92%').constraintSize({ maxWidth: 720 }).margin({ bottom: 20 })
      } else {
        // 完成页
        Column() {
          Text('🎉').fontSize(64)
          Text('拼写练习完成！').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 12 })
          Text(`拼对 ${this.correctCount} / ${this.queue.length} · 打卡 +1 🔥`)
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
