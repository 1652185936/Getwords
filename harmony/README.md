# 🎬 GetWords —— 纯血鸿蒙 (HarmonyOS NEXT) 字幕提取 & 翻译 App

> 📺 粘贴 YouTube 链接 → 🪄 一键抓字幕 → ✂️ 自动合并成句 → 🌏 DeepSeek 中英翻译 → 📄 导出漂亮排版 PDF / TXT / SRT。
> 用 **ArkTS / ArkUI** 写的纯血鸿蒙原生应用，工程在 [`GetWords/`](./GetWords)。🐰

---

## ✨ 功能一览

| 功能 | 说明 | 图标 |
|------|------|:---:|
| 🪄 **抓字幕** | 粘贴 YouTube 链接即可拉取字幕（走 InnerTube 接口，绕过风控） | ✅ |
| ✂️ **合并成句** | 把零碎的自动字幕碎片拼成完整句子，阅读更顺 | ✅ |
| 🌏 **中英翻译** | 接入 **DeepSeek**，英译中，支持「英文上 / 中文下」逐句对照 | ✅ |
| ⏱️ **时间戳** | 一键开关，显示 & 导出都能带 `[mm:ss]` | ✅ |
| 📄 **导出 PDF** | HTML 排版渲染成真 PDF：标题 + 时间戳列 + 整句 + 留白，超好看 | ✅ |
| 📝 **导出 TXT** | 带「序号 + 时间轴」的纯文本 | ✅ |
| 🎞️ **导出 SRT** | 标准字幕文件，中英开关开启时导双语 | ✅ |
| 📋 **一键复制** | 全文复制到剪贴板（可含中文 / 时间戳） | ✅ |

---

## 🚀 怎么跑起来

### 方式一：DevEco Studio 一键 Run（真机 / 模拟器）🖥️

1. 📥 装好 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（会一起装 HarmonyOS SDK）。
2. 📂 **File → Open** 选择 **含 `build-profile.json5` 的那层目录**：

   ```
   ...\harmony\GetWords      ← 打开这个，别打开仓库根目录！
   ```
3. 🔄 打开后点 **Sync Now**，等它下载 `oh_modules` / 生成 `hvigorw`。
4. 🔐 真机安装要签名：**File → Project Structure → Signing Configs → 勾选 Automatically generate signature**（登录华为账号）。
   > 🧪 本地**模拟器**开发者模式可直接装未签名包，省掉这步。
5. ▶️ 点 **Run**，自动编译 → 签名 → 安装 → 启动。🎉

### 方式二：命令行编译 + hdc 装模拟器 ⌨️

```bash
# 编译（hvigor 在 DevEco 安装目录里）
hvigorw assembleHap --mode module -p product=default -p buildMode=debug

# 装到模拟器（开发者模式可装未签名包）
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell aa start -b com.getwords.app -a EntryAbility
```

---

## 🔑 配置 DeepSeek（用翻译功能才需要）

1. 去 [DeepSeek 开放平台](https://platform.deepseek.com/) 申请 API Key（`sk-...`）。🗝️
2. App 里点右上角 **⚙ Key**，粘贴你的 Key，点「完成」。
3. ✅ Key 存在手机本地（`PersistentStorage`），**不写进代码、不上传仓库**，重启也在。
4. 抓到字幕后点 **翻译中文**，再打开 **中英** 开关即可看到对照。🌏

---

## 🧩 它是怎么工作的（技术小记）🤓

- 🕵️ **抓取**：不再爬 `watch` 网页（那条路拿到的字幕地址需要 `pot` 令牌、返回空）。改为调 YouTube **InnerTube `player` 接口**，请求头**伪装成官方 iOS 客户端**拿到不需要 `pot` 的 `baseUrl`，再取 `fmt=json3` 字幕；ANDROID 客户端兜底，空响应 / XML 都有容错。
- ✂️ **合并成句**：按句末标点（`. ! ?` 等）把相邻碎片拼成整句，时间取首片段。
- 🌏 **翻译**：`deepseek-chat`，每 20 行一批、带序号回填对齐、有进度提示。
- 📄 **PDF**：HTML/CSS 排版 → 隐藏 `Web` 组件加载（**base64 加载规避 `#` 截断**）→ ArkWeb **`createPdf`** 导出真 PDF → 系统文件框保存。

---

## 📁 工程结构

```
GetWords/
├─ 📦 AppScope/app.json5                      应用级配置（包名 com.getwords.app / 版本 / 图标）
├─ ⚙️ build-profile.json5  hvigorfile.ts       工程构建配置（锁定纯血鸿蒙 6.1.1(24)）
├─ oh-package.json5
└─ 📂 entry/                                   主模块
   └─ src/main/
      ├─ 🔐 module.json5                       模块配置 + INTERNET 权限
      ├─ ets/
      │  ├─ 🚪 entryability/EntryAbility.ets   入口 Ability（持久化 DeepSeek Key）
      │  ├─ 🖼️ pages/Index.ets                 主界面 UI + 交互
      │  └─ 🧰 services/
      │     ├─ Subtitles.ets                  抓字幕 + 合并成句 + TXT/SRT 生成
      │     ├─ Translate.ets                  DeepSeek 翻译
      │     └─ PdfExport.ets                  HTML 排版（供渲染 PDF）
      └─ 🎨 resources/                         图标 / 字符串 / 颜色 / 页面路由
```

---

## ⚠️ 注意事项

- 🌐 **需要手机能正常访问 YouTube**（抓取走的是 YouTube 在线接口）。
- 🏠 本项目定位为**个人自用工具**：在线抓取第三方平台内容涉及其服务条款与版权，**不建议上架应用商店**。
- 📱 工程按 **HarmonyOS NEXT 6.1.1(24)** 编写（纯血鸿蒙，不向下兼容老设备）。
- 🤖 DeepSeek 调用会消耗你账号的 token，按量计费，量力而行。💸

---

## 📜 简要变更

- 🆕 抓取改用 InnerTube(iOS) 绕过 PoToken，修复「获取字幕失败 / Empty Text」
- 🆕 自动字幕合并成完整句子
- 🆕 集成 DeepSeek 中英双语（显示 + 导出）
- 🆕 新增 PDF 导出（标题 + 时间戳列 + 留白排版）
- 🆕 导出 TXT 增加序号 + 时间轴
- 🔒 锁定纯血鸿蒙 `targetSdkVersion 6.1.1(24)`

---

made with ❤️ for 自己用 · 🎬 GetWords
