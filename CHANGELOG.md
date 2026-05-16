# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [0.1.0] - 2026-05-16

首个公开版本。

### 文档与渲染

- 打开 `.ofd` 文件并按页解析、渲染（GB/T 33190-2016）
- 多页、模板页（Background / Foreground 两种 ZOrder）、PageBlock 嵌套
- 文字：DeltaX / DeltaY 逐字定位，含 ST_Array `g N v` 重复格式，italic / weight / HScale
- 路径：S / M / L / Q / B / C 命令
- 图片：嵌入资源解码到 PixelMap，Canvas 直绘
- 嵌入字体注册到系统字体表
- DrawParam Relative 继承链
- 注释（Annotations）自动加载与渲染
- 签章占位（StampAnnot；真实验签由 Pro 接入）

### 交互

- 双指捏合缩放（0.5x ~ 5x）
- 单指拖动平移
- 双击复位

### 扩展点

- 三类扩展点：自定义对象解析（`ObjectParserExt`）、自定义对象渲染（`ObjectRendererExt`）、文档级扩展（`DocumentExtension`）
- `CustomPageObject` 类型对扩展开放
- `renderEmbedded`：OFD 嵌入渲染入口，给"OFD 套 OFD"场景使用（如矢量电子印章）

### 兼容性

- 路径大小写不敏感解析：兼容 OFD 自身写错大小写的样本
- 部分发票样本对象不带 `ID` 属性也能正常解析

### 工程

- ohpm library 抽离：发布为独立 `ofdkit-harmony` 包
- 最低支持：HarmonyOS NEXT 6.1.0 / API 23
- 扩展开发指南：[EXTENSIONS.md](./EXTENSIONS.md)
