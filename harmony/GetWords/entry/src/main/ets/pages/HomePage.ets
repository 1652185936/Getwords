import { router, promptAction } from '@kit.ArkUI';

@Entry
@Component
struct HomePage {
  /**
   * 工具卡片。
   * @param icon 图标 emoji
   * @param name 工具名
   * @param desc 一句话说明
   * @param url 目标页面路由（空串表示未上线）
   */
  @Builder
  toolCard(icon: string, name: string, desc: string, url: string) {
    Column() {
      Text(icon).fontSize(40)
      Text(name).fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 10 })
      Text(desc).fontSize(12).fontColor('#999999').margin({ top: 4 })
    }
    .width('48%').height(160).justifyContent(FlexAlign.Center)
    .backgroundColor(url.length > 0 ? '#FFFFFF' : '#F7F7F8')
    .opacity(url.length > 0 ? 1 : 0.55)
    .borderRadius(18).margin({ bottom: 14 })
    .onClick(() => {
      if (url.length > 0) {
        router.pushUrl({ url: url });
      } else {
        promptAction.showToast({ message: '敬请期待 🚧' });
      }
    })
  }

  build() {
    Column() {
      Text('🎬 GetWords').fontSize(26).fontWeight(FontWeight.Bold).margin({ top: 26 })
      Text('学习工具集').fontSize(14).fontColor('#888888').margin({ top: 4, bottom: 18 })

      // 打卡条（meGrow 那味，先用假数据）
      Row() {
        Text('🔥 已连续学习 7 天').fontSize(15).fontWeight(FontWeight.Medium)
        Blank()
        Text('今日 4 个待复习').fontSize(13).fontColor('#1A73E8')
      }
      .width('92%').constraintSize({ maxWidth: 720 }).padding(16).backgroundColor('#FFFFFF').borderRadius(16)

      // 工具宫格
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        this.toolCard('📺', '字幕提取', 'YouTube 取字幕 · 翻译 · 导出', 'pages/Index')
        this.toolCard('📒', '生词本', '点词收集 · 间隔复习', 'pages/WordbookPage')
        this.toolCard('🃏', '闪卡复习', '即将上线', '')
        this.toolCard('📅', '学习日历', '即将上线', '')
      }
      .width('92%').constraintSize({ maxWidth: 720 }).margin({ top: 18 })

      Blank()
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
