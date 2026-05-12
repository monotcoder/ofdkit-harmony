# ofdkit-harmony

`ofdkit-harmony` 是一个面向 HarmonyOS NEXT 的 ArkTS 原生 OFD 解析与渲染库。

项目目标是遵循 GB/T 33190-2016，提供可在鸿蒙原生应用中直接使用的 OFD 阅读能力，并在后续发布到 ohpm。

## 当前阶段

阶段一：OFD 文件结构解析。

当前已完成基础骨架：

- 选择 `.ofd` 文件
- 将文件复制到应用缓存目录
- 解压 OFD ZIP 包
- 解析 `OFD.xml` 和 `Document.xml`
- 展示文档版本、总页数和页面物理尺寸

暂未实现：

- 页面内容渲染
- 字体处理
- 图片资源解析
- 签章处理
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
    │   └── types.ets
    ├── utils/
    │   ├── FileUtils.ets
    │   └── ZipUtils.ets
    └── index.ets
```

## 使用示例

```typescript
import { OFDParser } from './ofdkit';

const parser = new OFDParser();
const document = await parser.parse('/path/to/file.ofd');
console.info(`总页数：${document.pages.length}`);
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
