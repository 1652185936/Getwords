# GetWords —— 纯血鸿蒙 (HarmonyOS NEXT) 原生 App

ArkTS / ArkUI 原生应用:粘贴 YouTube 链接 → 联网获取字幕 → 屏幕查看 →
导出 **TXT / SRT** 或复制到剪贴板。工程位于 `GetWords/`。

> ⚠️ **为什么没有现成的 .hap 给你下载?**
> 纯血鸿蒙(HarmonyOS NEXT)的原生应用**必须用华为 DevEco Studio + 你自己的
> 华为账号签名**才能装进手机。鸿蒙 SDK 不公开下载,GitHub Actions 之类的免费
> 流水线**无法编译/签名 .hap**。所以这里给的是**完整工程源码**,你用 DevEco
> Studio 打开后一键 Run,它会自动编译+签名+安装到你的手机。

## 你需要准备
1. **DevEco Studio**(免费):https://developer.huawei.com/consumer/cn/deveco-studio/
   安装时会一起装好 HarmonyOS SDK。
2. 一个**华为开发者账号**(免费注册),用于 DevEco 的「自动签名」。
3. 一台**纯血鸿蒙手机**,在「设置 → 系统和更新 → 开发者选项」里打开
   **USB 调试**(开发者选项需先在「关于手机」里连点版本号解锁)。

## ⚠️ 最关键的一步:打开「正确的文件夹」
DevEco **必须**打开鸿蒙工程那一层(含 `build-profile.json5` 的目录),也就是:

```
D:\worksace\other\Getwords\harmony\GetWords     ← 打开这个
```

**不要**打开仓库根目录 `D:\worksace\other\Getwords`(那里面混着网页/安卓/鸿蒙,
DevEco 不认,会报「选择一个 OpenHarmony 或 HarmonyOS 项目」)。

> 如果嫌路径深,可以直接把 `harmony\GetWords` 整个文件夹**剪切/复制**到别处
> (例如 `D:\GetWords`)再用 DevEco 打开,效果一样。

## 编译 & 安装步骤
1. 打开 DevEco Studio → **File → Open** → 选择 `...\harmony\GetWords` 文件夹
   (见上方说明)。打开后点提示里的 **Sync Now**,DevEco 会自动生成 `hvigorw`、
   下载 `oh_modules`、生成 `local.properties` 等(需要联网)。
2. 第一次打开会自动 **Sync**(下载 oh_modules、生成 hvigor 包装器),等它跑完。
3. 顶部菜单 **File → Project Structure → Signing Configs** → 勾选
   **Automatically generate signature**,登录你的华为账号,等它生成证书。
4. 手机用数据线连电脑,DevEco 右上角设备框选中你的手机。
5. 点 **▶ Run**(或 Shift+F10)。它会编译 → 签名 → 安装并启动 App。

> 如果只想要安装包:**Build → Build Hap(s)/APP(s) → Build Hap(s)**,
> 产物 `entry/build/default/outputs/default/entry-default-signed.hap` 就是
> 签名后的安装包,可用 `hdc install xxx.hap` 装到手机。

## 工程结构
```
GetWords/
├─ AppScope/app.json5                     应用级配置(包名/版本/图标)
├─ build-profile.json5  hvigorfile.ts      工程构建配置
├─ oh-package.json5
└─ entry/                                  主模块
   ├─ build-profile.json5  hvigorfile.ts
   ├─ oh-package.json5
   └─ src/main/
      ├─ module.json5                      模块配置 + INTERNET 权限
      ├─ ets/
      │  ├─ entryability/EntryAbility.ets  入口 Ability
      │  ├─ pages/Index.ets                主界面(UI)
      │  └─ services/Subtitles.ets         取字幕 + 生成 TXT/SRT 的核心逻辑
      └─ resources/                        图标/字符串/颜色/页面路由
```

## 功能说明
- **取字幕**:App 直接在手机本地请求 `youtube.com/watch`,从页面里解析出
  `captionTracks`,再拉取 `fmt=json3` 的字幕轨道并解析。**需要手机能正常访问
  YouTube**。
- **导出**:点「导出 TXT / SRT」会弹出系统文件保存框,自己选位置(可存到
  「文件」App / 网盘)。「复制」把全文复制到剪贴板。
- **时间戳**:开关打开后,显示与导出都会带 `[mm:ss]` 时间戳。

## 关于 PDF
鸿蒙端没有现成的、能嵌入中文字体的 PDF 生成库,所以这一版先做 **TXT / SRT /
复制**(已覆盖「文本导出」)。需要 PDF 的话,最简单是导出 TXT 后用系统「打印 →
保存为 PDF」。如果你确实要 App 内直接生成中文 PDF,告诉我,我再单独做(需要内置
字体 + 手写 PDF 写入,工作量较大)。

## 说明 / 已知事项
- 工程按 **HarmonyOS NEXT API 12(`5.0.0(12)`)** 编写。如果你的 DevEco/SDK
  版本不同,打开时它通常会提示并帮你迁移;`build-profile.json5` 里的
  `compatibleSdkVersion` 也可手动改成你本地的版本。
- ArkTS 是强类型,个别 API(如 `DocumentViewPicker` 的构造方式、`http` 的
  字段)在不同 SDK 小版本间略有差异;若 Run 时报个别类型/导入错误,按 DevEco
  的提示点一下基本就能修好,核心逻辑在 `Subtitles.ets` 里是通用的。
