<p align="center">
  <img src=".github/assets/logo.svg" alt="ofdkit-harmony" width="160"/>
</p>

<h1 align="center">ofdkit-harmony</h1>

<p align="center">
  <a href="https://gitee.com/notcoder/ofdkit-harmony/releases"><img src="https://img.shields.io/badge/version-v0.2.0-2E7D32.svg" alt="version"/></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue.svg" alt="license"/></a>
  <img src="https://img.shields.io/badge/HarmonyOS-NEXT%206.1+-000000.svg" alt="HarmonyOS"/>
  <img src="https://img.shields.io/badge/ArkTS-pure-7E57C2.svg" alt="ArkTS"/>
  <img src="https://img.shields.io/badge/GB%2FT-33190--2016-C0282C.svg" alt="GB/T 33190-2016"/>
</p>

<p align="center">
  <img src=".github/assets/demo.gif" alt="演示" width="480"/>
</p>

<p align="center">
  <sub>电子发票、电子公文、电子合同直接打开。跨页全文搜索 + 多页连续滚动 + 长按选中复制。</sub>
</p>

HarmonyOS NEXT 上首个开源的原生 OFD 阅读库，纯 ArkTS 实现，遵循 GB/T 33190-2016。

电子发票、电子公文、电子合同等 OFD 场景都能直接在鸿蒙原生应用里打开，**无需 WebView、无需 JNI、无需第三方 SDK**。

## 亮点

- 🚀 **鸿蒙原生**：纯 ArkTS / ArkUI，零 WebView 零 JNI，包体积小、启动快
- 🔍 **跨页全文搜索**：命中实时高亮、上下条跳转、跨页连续定位
- 📜 **多页连续滚动 + 缩略图条**：一屏滚完整本文档，缩略图点击秒切页
- ✍️ **长按选中复制**：段落级文字选区，一键复制到剪贴板
- 🧩 **扩展点架构**：解析、渲染、文档级三类扩展点，验签 / 转换 / 表单都可自研接入
- 📐 **遵循国标**：GB/T 33190-2016，电子发票 / 公文 / 合同样本通用

## 仓库

- **主仓**：https://gitee.com/notcoder/ofdkit-harmony
- **GitHub 镜像**：https://github.com/monotcoder/ofdkit-harmony

Issue / PR / 讨论请到 Gitee 主仓。

## 能做什么

**文档**
- 打开 `.ofd` 文件，多页解析与切换
- 模板页（含 ZOrder Background / Foreground）
- 注释（Annotations）
- 签章占位（StampAnnot，真实验签由 Pro 接入）

**渲染**
- 文字（DeltaX/DeltaY 逐字定位、HScale、italic、weight）
- 路径（直线、二次/三次贝塞尔、闭合、圆弧 `A` 命令）
- 图片（嵌入资源解码到 PixelMap 后 Canvas 直绘）
- 嵌入字体注册到系统字体表 + 全局兜底字体 API
- 矢量绘制参数（DrawParam）继承链

**交互**
- 双指捏合缩放（0.5x ~ 5x）
- 单指拖动平移
- 双击复位
- 侧滑切页（左右滑动翻页）
- **多页连续滚动**（`OFDDocumentScroll`，一屏滚完整本文档）
- **缩略图条切页**（`OFDThumbnailStrip`，横向滚动 + 点击跳页）
- **长按选中文字 → 复制**（段落级选区 + 一键复制到剪贴板）

**搜索**
- **跨页全文搜索**（`SearchController` + `OFDSearchBar`）
- 命中实时高亮（当前匹配 / 其他匹配两种态）
- 上一个 / 下一个跳转，跨页连续定位

**扩展**
- 自定义对象解析 / 渲染 / 文档级扩展三类扩展点
- OFD 嵌入渲染入口（如矢量印章这种 OFD 套 OFD 的场景）

## 不在范围内

| 能力 | 说明 |
|---|---|
| 国密 SM2/SM3 签章验签 | 由 [Pro 版](#pro) 提供 |
| 印章图像绘制（光栅 / 矢量） | 由 Pro 版提供 |
| OFD ↔ PDF 转换 | 由 Pro 版提供（规划中）|
| CMYK / Pattern / Gradient 颜色空间 | 当前按 RGB 处理 |
| 表单填充（CT_FormFile） | 未实现 |

## 环境要求

- HarmonyOS NEXT 6.1.0 / API 23+
- DevEco Studio + ohpm
- ArkTS / ArkUI

> ⚠️ **当前仅支持 HarmonyOS NEXT，不支持 OpenHarmony**。
> 库内使用了 `@kit.*` Kit 命名空间 API（ImageKit / CoreFileKit / BasicServicesKit / ArkUI 等），OpenHarmony 的 `@ohos.*` 命名空间下没有直接对应，需要做适配才能跑通。OpenHarmony 兼容性目前不在路线图上，如有此需求欢迎到 Gitee 主仓提 Issue 讨论。

## 快速开始

### 安装

```bash
ohpm install ofdkit-harmony
```

### 使用

```typescript
import {
  OFDParser,
  OFDDocument,
  OFDPageView,
  installDefaultExtensions
} from 'ofdkit-harmony';

// 应用启动时调用一次：注册内置扩展（注释加载 + 签章占位）
installDefaultExtensions();

// 解析
const parser = new OFDParser({ workDir: '/path/to/cache' });
const doc: OFDDocument = await parser.parse('/path/to/file.ofd');

// 渲染（OFDPageView 已封装资源预加载 + 手势）
@Component
struct Reader {
  @State doc: OFDDocument = ...;
  @State pageIndex: number = 0;

  build() {
    OFDPageView({ page: this.doc.pages[this.pageIndex] })
  }
}
```

`OFDPageView` 内部自动完成本页字体注册、图片解码、Canvas 绘制和手势。

### 改善没嵌入字体的中文显示

大多数电子发票的字体只在 OFD 里写了 `FontName="宋体"` 但没把字体文件嵌进去，渲染会退到 HarmonyOS Sans，看起来比纸质宋体粗黑。如果你的 app 自带 OFL 协议的中文字体（思源宋体/黑体等），可以注册成兜底字体：

```typescript
import { font } from '@kit.ArkUI';
import { OFDRenderer } from 'ofdkit-harmony';

// app 启动时一次性注册（路径替换成你自己的字体文件 URI）
font.registerFont({ familyName: 'OFD-Fallback', familySrc: 'file:///data/.../source-han-serif.ttf' });
OFDRenderer.setFallbackFontFamily('OFD-Fallback');
```

之后所有没嵌入字体的 OFD 文字都会优先用 `OFD-Fallback`，串到原 fallback 链最前面。本库本身**不打包任何字体**，由调用方按需提供。

## API 概览

| 入口 | 作用 |
|---|---|
| `OFDParser` | 解压 + 解析 OFD 包，返回 `OFDDocument`（含多页 + 资源索引）|
| `OFDPageView` | ArkUI Canvas 组件，渲染单页 + 内置手势 / 长按选中复制 |
| `OFDDocumentScroll` | 多页连续滚动视图（纵向 List + 每页 `OFDPageView`）|
| `OFDThumbnailStrip` | 横向缩略图条，点击跳页 |
| `OFDSearchBar` | 搜索栏 UI（输入框 + 上/下匹配 + 计数）|
| `SearchController` | 跨页全文搜索控制器（`search` / `next` / `prev` / `hitsForPage`）|
| `OFDRenderer` | 底层渲染器；`renderEmbedded` 给"OFD 套 OFD"场景；`setFallbackFontFamily` 全局兜底字体 |
| `installDefaultExtensions()` | 一键安装内置扩展 |
| `ObjectParserExt` / `ObjectRendererExt` / `DocumentExtension` | 三类扩展点接口 |
| `CustomPageObject` | 扩展用的自定义页面对象类型 |

详细的扩展开发引导见 [EXTENSIONS.md](./EXTENSIONS.md)。

## 路线图

后续能力会按 `core / parser / resources / render / signature / annotation / metadata / components` 分层演进，便于不同客户套餐按需打包。

详细计划见 [ROADMAP.md](./ROADMAP.md)。

### 组合：连续滚动 + 缩略图 + 全文搜索

```typescript
import {
  OFDDocumentScroll,
  OFDThumbnailStrip,
  OFDSearchBar,
  SearchController,
  SelectionRect
} from 'ofdkit-harmony';

@Component
struct Reader {
  @State doc: OFDDocument = ...;
  @State currentPage: number = 0;
  @State scrollTarget: number = 0;
  @State query: string = '';
  @State activeIndex: number = -1;
  @State totalMatches: number = 0;
  private search: SearchController = new SearchController();

  build() {
    Column() {
      OFDSearchBar({
        query: this.query,
        activeIndex: this.activeIndex,
        totalMatches: this.totalMatches,
        onQuerySubmit: (q: string) => {
          this.search.search(q, this.doc.pages);
          this.activeIndex = this.search.activeIndex;
          this.totalMatches = this.search.matches.length;
          const cur = this.search.current();
          if (cur !== undefined) this.scrollTarget = cur.pageIndex;
        },
        onNext: () => {
          const m = this.search.next();
          this.activeIndex = this.search.activeIndex;
          if (m !== undefined) this.scrollTarget = m.pageIndex;
        },
        onPrev: () => {
          const m = this.search.prev();
          this.activeIndex = this.search.activeIndex;
          if (m !== undefined) this.scrollTarget = m.pageIndex;
        }
      })

      OFDDocumentScroll({
        pages: this.doc.pages,
        scrollToIndex: this.scrollTarget,
        hitsByPage: (i: number): SelectionRect[] => this.search.hitsForPage(i),
        onVisiblePageChange: (i: number) => { this.currentPage = i; }
      })
      .layoutWeight(1)

      OFDThumbnailStrip({
        pages: this.doc.pages,
        currentIndex: this.currentPage,
        onPageSelect: (i: number) => { this.scrollTarget = i; }
      })
    }
  }
}
```

<a id="pro"></a>

## 🛡️ 与商业版的分工

`ofdkit-harmony-pro` 是开源版的闭源商业扩展包，专攻**电子发票 / 公文 / 合同场景里的国密签章验签与红章渲染**——这部分能力涉及 GB/T 35275-2017、`@kit.CryptoArchitectureKit` 调用约定、各家签发工具（数科 / 福昕 / CFCA）的差异适配，自行实现成本较高。

<table align="center">
  <tr>
    <td align="center" width="50%">
      <img src=".github/assets/render-opensource.png" alt="开源版渲染（红章为占位）"/>
      <br/>
      <sub><b>开源版</b>：红章为虚线占位框</sub>
    </td>
    <td align="center" width="50%">
      <img src=".github/assets/render-pro.png" alt="Pro 版渲染（红章完整 + 国密验签）"/>
      <br/>
      <sub><b>Pro 版</b>：红章完整渲染 + 国密验签</sub>
    </td>
  </tr>
</table>

### Pro 能解锁什么

**签章验签**（GB/T 35275-2017）
- ASN.1 DER + SES_Signature 完整解析
- SM2/SM3 签名值验证（基于鸿蒙 `@kit.CryptoArchitectureKit`）
- Reference 文件 SM3 完整性校验
- SignedInfo dataHash 摘要校验

**印章绘制**
- 光栅印章（PNG / JPG / GIF / BMP）解码到 PixelMap 后 Canvas 直绘
- 矢量印章（`picture.type='OFD'`）嵌入 OFD 递归解析与渲染
- 字体注册带命名空间，避免与主文档冲突

**5 级验签状态视觉化**

| 状态 | 含义 | 渲染表现 |
|---|---|---|
| `valid` | SM2 数学验签通过 | 印章图原样 |
| `invalid` | 签名值与证书公钥不匹配 | 印章图 + 红色描边 + ✗ 红色角标 |
| `tampered` | 文件被篡改 | 印章图 + 橙色描边 + ⚠ 橙色角标 |
| `error` | DER / SM2 调用异常 | 同 invalid（能取到图也尽量展示）|
| `unknown` | 无 SignedValue 路径 | 琥珀色虚线占位 |

### 一行代码接入

```typescript
import { installDefaultExtensions } from 'ofdkit-harmony';
import { installProExtensions } from 'ofdkit-harmony-pro';

aboutToAppear(): void {
  installDefaultExtensions();   // 先开源默认（含签章灰色占位）
  installProExtensions();       // 再 Pro 覆盖（验签 + 印章渲染）
}
```

之后开源版的 `OFDPageView` / `OFDDocumentScroll` 正常使用，签章会自动按状态分级显示，无需改业务代码。

### 工程约定

- **依赖单向**：Pro → 开源版，Pro 不修改开源版任何代码
- **扩展点同源**：Pro 能力全部通过开源版定义的 `ObjectRendererExt` / `DocumentExtension` 接入；你也可以用同一套机制接入自研的验签 / 转换 / 表单实现
- **试用 / 报价 / 定制开发 / 技术咨询** → 见下方 [商务合作](#商务合作)

## 商务合作

Pro 版试用、定价、定制开发、技术咨询，欢迎扫码加微信：

<p align="center">
  <img src=".github/assets/wechat-qr.jpg" alt="作者微信" width="200"/>
</p>

## 协议

Apache License 2.0。Copyright 2026-present Mo and contributors.

## 贡献

欢迎 Issue 和 Pull Request，贡献前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。
