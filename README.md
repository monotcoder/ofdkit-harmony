<p align="center">
  <img src=".github/assets/logo.svg" alt="ofdkit-harmony" width="160"/>
</p>

<h1 align="center">ofdkit-harmony</h1>

<p align="center">
  <a href="https://gitee.com/notcoder/ofdkit-harmony/releases"><img src="https://img.shields.io/badge/version-v0.1.0-2E7D32.svg" alt="version"/></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue.svg" alt="license"/></a>
  <img src="https://img.shields.io/badge/HarmonyOS-NEXT%206.1+-000000.svg" alt="HarmonyOS"/>
  <img src="https://img.shields.io/badge/ArkTS-pure-7E57C2.svg" alt="ArkTS"/>
  <img src="https://img.shields.io/badge/GB%2FT-33190--2016-C0282C.svg" alt="GB/T 33190-2016"/>
</p>

<p align="center">
  <video src="https://gitee.com/notcoder/ofdkit-harmony/raw/main/.github/assets/demo.mov" width="320" controls autoplay loop muted></video>
</p>

<p align="center">
  <sub>演示视频中印章渲染由商业版 <a href="https://gitee.com/notcoder/ofdkit-harmony-pro"><code>ofdkit-harmony-pro</code></a> 提供；开源版负责解析、渲染、扩展点框架。</sub>
</p>

HarmonyOS NEXT 上的原生 OFD 阅读库，纯 ArkTS 实现，遵循 GB/T 33190-2016。

电子发票、电子公文、电子合同等 OFD 场景都能直接在鸿蒙原生应用里打开，无需 WebView、无需 JNI。

> 国密签章验签、印章绘制等付费能力由商业版 [`ofdkit-harmony-pro`](#与商业版的分工) 通过开源扩展点接入。

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
- 路径（直线、二次/三次贝塞尔、闭合）
- 图片（嵌入资源解码到 PixelMap 后 Canvas 直绘）
- 嵌入字体注册到系统字体表
- 矢量绘制参数（DrawParam）继承链

**交互**
- 双指捏合缩放（0.5x ~ 5x）
- 单指拖动平移
- 双击复位

**扩展**
- 自定义对象解析 / 渲染 / 文档级扩展三类扩展点
- OFD 嵌入渲染入口（如矢量印章这种 OFD 套 OFD 的场景）

## 不在范围内

| 能力 | 说明 |
|---|---|
| 国密 SM2/SM3 签章验签 | 由 [Pro 版](#与商业版的分工) 提供 |
| 印章图像绘制（光栅 / 矢量） | 由 Pro 版提供 |
| OFD ↔ PDF 转换 | 由 Pro 版提供（规划中）|
| 路径圆弧（AbbreviatedData `A` 命令）| 未实现 |
| CMYK / Pattern / Gradient 颜色空间 | 当前按 RGB 处理 |
| 表单填充（CT_FormFile） | 未实现 |
| 文字选择 / 复制 | 未实现 |

## 环境要求

- HarmonyOS NEXT 6.1.0 / API 23+
- DevEco Studio + ohpm
- ArkTS / ArkUI

## 快速开始

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

## API 概览

| 入口 | 作用 |
|---|---|
| `OFDParser` | 解压 + 解析 OFD 包，返回 `OFDDocument`（含多页 + 资源索引）|
| `OFDPageView` | ArkUI Canvas 组件，渲染单页 + 内置手势 |
| `OFDRenderer` | 底层渲染器；`renderEmbedded` 给"OFD 套 OFD"场景 |
| `installDefaultExtensions()` | 一键安装内置扩展 |
| `ObjectParserExt` / `ObjectRendererExt` / `DocumentExtension` | 三类扩展点接口 |
| `CustomPageObject` | 扩展用的自定义页面对象类型 |

详细的扩展开发引导见 [EXTENSIONS.md](./EXTENSIONS.md)。

## 与商业版的分工

[`ofdkit-harmony-pro`](https://gitee.com/notcoder/ofdkit-harmony-pro) 闭源商业版通过本仓库的扩展点接入：

- 国密 SM2/SM3 签章验签
- Reference 文件完整性校验
- 光栅印章（PNG/JPG）绘制
- 矢量印章（type='OFD'）嵌入 OFD 渲染

Pro 版不修改开源版代码，依赖单向（pro → opensource）。所有 Pro 能力都通过开源版定义的扩展点 API 实现——你也可以用同一套机制接入自研的验签 / 转换 / 表单实现。

## 协议

Apache License 2.0。Copyright 2026-present Mo and contributors.

## 贡献

欢迎 Issue 和 Pull Request，贡献前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。
