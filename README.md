# ofdkit-harmony

面向 HarmonyOS NEXT 的 ArkTS 原生 OFD（GB/T 33190-2016）解析与渲染库。

无需 Web 引擎、无需 JNI，纯 ArkTS 实现 + Canvas 直绘。适合阅读电子发票、电子公文、电子合同等场景。

> **国密签章验签** 等付费功能由商业版 [`ofdkit-harmony-pro`](#与商业版的关系) 通过扩展点接入，本仓库提供完整扩展点 API。

---

## 仓库

- **主仓库（Gitee）**：https://gitee.com/notcoder/ofdkit-harmony
- **GitHub 镜像**：https://github.com/monotcoder/ofdkit-harmony

Issue / PR / 讨论请优先提交到 Gitee 主仓库。

## 功能矩阵

| 能力 | 状态 |
|---|---|
| OFD ZIP 解压 + 包结构解析（OFD.xml / Document.xml / Content.xml） | ✅ |
| 多页、PageBlock 嵌套、变换矩阵（CTM） | ✅ |
| TextObject 文字（DeltaX / DeltaY 逐字定位，含 `g N v` 重复格式） | ✅ |
| PathObject 路径（S / M / L / Q / B / C 命令） | ✅ |
| ImageObject 图片（嵌入资源解码到 PixelMap） | ✅ |
| 资源索引（PublicRes / DocumentRes：Fonts / MultiMedias / DrawParams） | ✅ |
| DrawParam Relative 继承链合并 | ✅ |
| 嵌入字体注册（`font.registerFont`） | ✅ |
| TemplatePage 模板页（ZOrder Background / Foreground） | ✅ |
| Annotations 注释加载与渲染 | ✅ |
| Signatures 签章解析（StampAnnot → CustomPageObject） | ✅ |
| 大小写不敏感路径解析（兼容 OFD 自身写错大小写的样本） | ✅ |
| 三类扩展点（对象解析 / 对象渲染 / 文档级） | ✅ |
| OFD 嵌入 OFD 渲染入口（`renderEmbedded`，给矢量印章用） | ✅ |
| **国密 SM2/SM3 签章验签 + 真实印章绘制** | Pro 版 |
| **OFD ↔ PDF 转换** | Pro 版（规划中）|
| AbbreviatedData `A` 圆弧命令 | 未实现 |
| ColorSpace（CMYK / Pattern / Gradient） | 未实现（当前按 RGB 处理） |
| 表单填充（CT_FormFile） | 未实现 |
| 文字选择 / 复制 | 未实现 |

## 环境要求

- HarmonyOS NEXT 6.1.0 / API 23+
- DevEco Studio + ohpm
- ArkTS / ArkUI

## 安装

发布到 ohpm 之后通过 `oh-package.json5` 引用即可。本地开发可用 file 协议：

```jsonc
{
  "dependencies": {
    "ofdkit-harmony": "file:../path/to/library"
  }
}
```

## 快速开始

```typescript
import {
  OFDParser,
  OFDDocument,
  OFDPageView,
  installDefaultExtensions
} from 'ofdkit-harmony';

// 1) 应用启动时安装内置扩展（Annotations + Signature 占位）
installDefaultExtensions();

// 2) 解析 OFD
const parser = new OFDParser({ workDir: '/path/to/cache' });
const doc: OFDDocument = await parser.parse('/path/to/file.ofd');

// 3) 渲染
@Component
struct Reader {
  @State pageIndex: number = 0;
  @State doc: OFDDocument = ...;

  build() {
    // OFDPageView 已封装资源预加载 + 手势（捏合 / 拖动 / 双击复位）
    OFDPageView({ page: this.doc.pages[this.pageIndex] })
  }
}
```

`OFDPageView` 已自动处理：
- 本页用到的嵌入字体 `font.registerFont`
- 本页用到的图片 `createImageSource → PixelMap`
- 手势：双指捏合缩放（0.5x ~ 5x）、单指拖动平移、双击复位

## 项目结构

```text
ofdkit-harmony/
├── entry/                        # 示例应用（picker + 渲染 + 手势）
└── library/                      # 发布的 ohpm 包 (name = ofdkit-harmony)
    ├── Index.ets                 # 公共导出
    └── src/main/ets/ofdkit/
        ├── parser/
        │   ├── OFDParser.ets         # 顶层入口
        │   ├── DocumentParser.ets    # Document.xml
        │   ├── ContentParser.ets     # Content.xml + 页面对象
        │   ├── ResourceParser.ets    # PublicRes / DocumentRes
        │   ├── ParseHelpers.ets
        │   ├── types.ets             # 文档对象模型
        │   └── extensions/           # AnnotationExtension / SignatureExtension
        ├── renderer/
        │   ├── OFDRenderer.ets       # Canvas 渲染（含 renderEmbedded）
        │   └── extensions/           # SignaturePlaceholderRenderer
        ├── components/
        │   └── OFDPageView.ets       # ArkUI Canvas 组件
        ├── utils/
        │   ├── XmlParser.ets         # 自研 XML DOM
        │   ├── FileUtils.ets         # 含 resolveCaseInsensitive
        │   └── ZipUtils.ets
        └── defaults.ets              # installDefaultExtensions
```

## 扩展点

三类扩展点：

- **`ObjectParserExt`** — 自定义对象解析（如把某种自定义节点解析成 `CustomPageObject`）
- **`ObjectRendererExt` + `RenderContext`** — 自定义对象渲染（按 `customType` 路由）
- **`DocumentExtension`** — 文档级扩展，解析完成后异步处理（验签、外部资源加载等）

`renderEmbedded(page, ctx, boundsW, boundsH, outerPxPerMm)` 是 `OFDRenderer` 的嵌入渲染入口，专门给"OFD 套 OFD"的场景用（典型场景：矢量电子印章 `SES_ESPictureInfo.type='OFD'`）。

详见 [EXTENSIONS.md](./EXTENSIONS.md)。

## 与商业版的关系

[`ofdkit-harmony-pro`](https://gitee.com/notcoder/ofdkit-harmony-pro)（闭源商业版）通过本仓库的扩展点机制接入：

- ✅ 国密 SM2/SM3 验签（依赖 `@kit.CryptoArchitectureKit` / `@kit.DeviceCertificateKit`）
- ✅ Reference 文件完整性校验
- ✅ SES_Signature ASN.1 DER 解析（GB/T 35275-2017）
- ✅ 光栅印章（PNG / JPG）解码绘制
- ✅ 矢量印章（type='OFD'）嵌入 OFD 递归解析渲染

**Pro 版不修改开源版代码**，依赖关系单向（pro → opensource）。所有 Pro 能力都通过开源版定义的扩展点 API 实现，因此你完全可以用同样的方式接入自研的验签 / 转换 / 表单实现。

## 路线图

- ✅ 阶段一：OFD 文件结构解析
- ✅ 阶段二：页面内容对象解析
- ✅ 阶段三：Canvas 页面渲染
- ✅ 阶段四：字体 / 图片 / 资源管理
- ✅ 阶段五：扩展点系统 + ohpm Library 抽离
- ✅ 阶段六：商业版 Pro 接入（验签 + 完整性 + 矢量印章）
- ⏳ 阶段七：ColorSpace / 圆弧 / 表单 / 文字选择

## 协议

Apache License 2.0。Copyright 2026-present Mo and contributors.

## 贡献

欢迎提交 Issue 和 Pull Request。贡献前请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。
