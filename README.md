# ofdkit-harmony

`ofdkit-harmony` 是一个面向 HarmonyOS NEXT 的 ArkTS 原生 OFD 解析与渲染库。

项目目标是遵循 GB/T 33190-2016，提供可在鸿蒙原生应用中直接使用的 OFD 阅读能力，并在后续发布到 ohpm。

## 仓库说明

Gitee 是本项目主仓库：

https://gitee.com/notcoder/ofdkit-harmony

GitHub 仓库仅作为镜像同步使用。Issue、Pull Request 和功能讨论请优先提交到 Gitee 主仓库。

## 当前阶段

阶段四：字体、图片和资源管理。

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
- **解析 PublicRes / DocumentRes 资源索引**
- **字体加载：注册 OFD 嵌入字体到系统**
- **图片资源加载：解码到 PixelMap 并真实绘制**
- **DrawParam 绘制参数应用（含 Relative 继承链）**
- 页面预览和切换功能

暂未实现：

- 签章（CT_Signatures）与国密验签
- ColorSpace、Annotations、Template Pages
- 圆弧命令 A 的完整支持
- ohpm Library 抽离

## 环境要求

- DevEco Studio
- HarmonyOS NEXT
- ArkTS / ArkUI
- 最低支持：HarmonyOS NEXT 6.1.0 / API 23

## 项目结构

```text
entry/src/main/ets/
├── pages/
│   └── Index.ets
└── ofdkit/
    ├── parser/
    │   ├── OFDParser.ets
    │   ├── DocumentParser.ets
    │   ├── ContentParser.ets
    │   ├── ResourceParser.ets
    │   ├── ParseHelpers.ets
    │   └── types.ets
    ├── renderer/
    │   └── OFDRenderer.ets
    ├── components/
    │   └── OFDPageView.ets
    ├── utils/
    │   ├── XmlParser.ets
    │   ├── FileUtils.ets
    │   └── ZipUtils.ets
    └── index.ets
```

## 使用示例

```typescript
import { OFDParser, OFDRenderer } from './ofdkit';

const parser = new OFDParser();
const document = await parser.parse('/path/to/file.ofd');
console.info(`总页数：${document.pages.length}`);

// 访问页面内容
document.pages.forEach(page => {
  console.info(`第 ${page.pageIndex + 1} 页`);
  page.content?.layers.forEach(layer => {
    console.info(`  图层包含 ${layer.objects.length} 个对象`);
    layer.objects.forEach(obj => {
      console.info(`    - ${obj.type} 对象 ID: ${obj.id}`);
    });
  });
});

// 渲染页面到 Canvas
const renderer = new OFDRenderer(2.0); // 2倍缩放
const context = new CanvasRenderingContext2D(settings);
renderer.renderPage(document.pages[0], context);
```

## 开发计划

- 阶段一：解析 OFD 文件结构
- 阶段二：解析页面内容对象
- 阶段三：Canvas 页面渲染
- 阶段四：字体、图片和资源管理
- 阶段五：封装 Library 并发布 ohpm

## 贡献

欢迎提交 Issue 和 Pull Request。贡献前请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 协议

本项目基于 Apache License 2.0 开源。

Copyright 2026-present Mo and contributors.
