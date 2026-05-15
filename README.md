# ofdkit-harmony

`ofdkit-harmony` 是一个面向 HarmonyOS NEXT 的 ArkTS 原生 OFD 解析与渲染库。

项目目标是遵循 GB/T 33190-2016，提供可在鸿蒙原生应用中直接使用的 OFD 阅读能力，并在后续发布到 ohpm。

## 仓库说明

Gitee 是本项目主仓库：

https://gitee.com/notcoder/ofdkit-harmony

GitHub 仓库仅作为镜像同步使用。Issue、Pull Request 和功能讨论请优先提交到 Gitee 主仓库。

## 当前阶段

阶段五：扩展点系统 + Library 抽离。

当前已完成：

- 选择 `.ofd` 文件并复制到应用缓存目录
- 解压 OFD ZIP 包
- 自研轻量 XML DOM 解析器，替代正则解析
- 解析 `OFD.xml` / `Document.xml` / `Content.xml`
- 解析页面内容对象（文字、路径、图片）、图层结构、PageBlock 嵌套
- 解析变换矩阵（CTM）
- Canvas 页面渲染（按文档绘制顺序保留 z-order）
- 文字对象渲染（支持 DeltaX/DeltaY 逐字定位、HScale、italic/weight）
- 路径对象渲染（支持 S/M/L/Q/B/C 命令，A 暂占位）
- 解析 PublicRes / DocumentRes 资源索引
- 字体加载：注册 OFD 嵌入字体到系统
- 图片资源加载：解码到 PixelMap 并真实绘制
- DrawParam 绘制参数应用（含 Relative 继承链）
- **Annotations 注释加载与渲染**
- **TemplatePage 模板页继承（Background / Foreground）**
- **Signatures 签章占位（解析 StampAnnot，红色虚线框 + "需 Pro 验签"）**
- **扩展点系统**：自定义对象解析 / 渲染 / 文档级扩展（见 [EXTENSIONS.md](./EXTENSIONS.md)）
- **ohpm Library 抽离**：发布为独立 `ofdkit-harmony` 包
- 手势：双指捏合缩放、单指拖动平移、双击复位
- 页面预览和切换功能

暂未实现：

- 签章国密验签（SM2/SM3）与真实印章图像绘制 — 留给 Pro 商业版
- OFD ↔ PDF 转换 — 留给 Pro 商业版
- ColorSpace（CMYK / Pattern / Gradient）
- 圆弧命令 A 的完整支持
- 表单填充（CT_FormFile）

## 环境要求

- DevEco Studio
- HarmonyOS NEXT
- ArkTS / ArkUI
- 最低支持：HarmonyOS NEXT 6.1.0 / API 23

## 项目结构

```text
ofdkit-harmony/
├── entry/                     # 示例应用（演示 picker + 渲染 + 手势）
│   └── src/main/ets/
│       ├── pages/Index.ets
│       └── entryability/
└── library/                   # 发布的 ohpm 包，name = ofdkit-harmony
    ├── oh-package.json5
    ├── Index.ets              # 公共导出入口
    └── src/main/ets/ofdkit/
        ├── parser/
        │   ├── OFDParser.ets
        │   ├── DocumentParser.ets
        │   ├── ContentParser.ets
        │   ├── ResourceParser.ets
        │   ├── ParseHelpers.ets
        │   ├── types.ets
        │   └── extensions/    # 内置文档级扩展（Annotations / Signatures）
        ├── renderer/
        │   ├── OFDRenderer.ets
        │   └── extensions/    # 内置占位渲染器
        ├── components/
        │   └── OFDPageView.ets
        ├── utils/
        │   ├── XmlParser.ets
        │   ├── FileUtils.ets
        │   └── ZipUtils.ets
        ├── defaults.ets       # installDefaultExtensions
        └── index.ets
```

## 使用示例

```typescript
import {
  OFDParser,
  OFDDocument,
  OFDPageView,
  installDefaultExtensions
} from 'ofdkit-harmony';

// 1. 应用启动时安装默认扩展（注释、签章占位等）
installDefaultExtensions();

// 2. 解析 OFD
const parser = new OFDParser({ workDir: '/path/to/cache' });
const doc: OFDDocument = await parser.parse('/path/to/file.ofd');
console.info(`总页数：${doc.pages.length}`);

// 3. 渲染（在 ArkUI Component 中）
//    OFDPageView 组件已封装 Canvas + 资源预加载 + 手势
@Component
struct Reader {
  @State pageIndex: number = 0;
  @State doc: OFDDocument = ...;

  build() {
    OFDPageView({ page: this.doc.pages[this.pageIndex] })
  }
}
```

## 扩展开发

如果你要接入自定义对象类型（如水印）、自定义渲染器（如真实签章绘制）或自定义文档级资源（如自定义表单），请参考 [EXTENSIONS.md](./EXTENSIONS.md)。

商业版 [`ofdkit-harmony-pro`](./PRO.md)（计划中）通过同一套扩展点接入国密验签、OFD↔PDF 转换等高级功能。

## 开发计划

- 阶段一：解析 OFD 文件结构 ✅
- 阶段二：解析页面内容对象 ✅
- 阶段三：Canvas 页面渲染 ✅
- 阶段四：字体、图片和资源管理 ✅
- 阶段五：扩展点系统 + ohpm Library 抽离 ✅
- 阶段六：商业版 `ofdkit-harmony-pro`（签章国密验签 / OFD↔PDF / 表单）

## 贡献

欢迎提交 Issue 和 Pull Request。贡献前请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 协议

本项目基于 Apache License 2.0 开源。

Copyright 2026-present Mo and contributors.
