# Roadmap

本路线图用于拆分开源版与 Pro 版共享的文档内核能力。当前阶段先聚焦 OFD，不启动 PDF 同步实现。

## 分层目标

`ofdkit-harmony` 后续按低耦合模块组织，便于不同客户套餐按需打包。

```text
ofdkit/
├── core/          基础模型、坐标系统、错误类型、模块通用能力
├── parser/        OFD 包结构、页面对象和资源引用解析
├── resources/     字体、图片、签章资源、绘制参数等资源索引
├── render/        Canvas 渲染、缩放、翻页、页面坐标转换
├── signature/     数字签章显示、签章外观解析、签章位置映射
├── annotation/    手写签批、矢量笔迹、防误触、橡皮擦、撤销
├── metadata/      批注元数据、点击追溯、字段配置
└── components/    可选 ArkUI 组件和 Demo 组合能力
```

## 按需打包策略

早期先采用单 ohpm 包、多模块入口导出；等商业套餐稳定后，再拆成多个 ohpm 包。

```text
基础阅读版：
core + parser + resources + render

签章阅读版：
基础阅读版 + signature

签批版：
签章阅读版 + annotation

政企追溯版：
签批版 + metadata
```

模块依赖原则：

- `core` 不依赖任何高层模块。
- `parser` 不依赖 UI 和 `components`。
- `render` 不依赖 `annotation` 和 `metadata`。
- `signature` 可以依赖 `core`、`parser`、`resources`、`render` 的公共接口。
- `annotation` 可以依赖 `core` 的坐标系统，但不直接依赖业务 UI。
- `metadata` 不直接依赖 UI，只提供展示字段和追溯数据模型。

## 近期里程碑

### M1：模块边界与坐标系统

- 建立 `core`、`resources`、`render`、`signature`、`annotation`、`metadata` 入口。
- 抽象文档坐标、视口坐标、屏幕坐标转换。
- 现有签章、缩放、搜索能力保持兼容。

### M2：手写签批能力包

- 支持手写笔直接书写。
- 手指保留拖动和缩放。
- 手写笔书写期间启用防误触。
- 笔迹保存为矢量 stroke，不保存为低清图片。

### M3：矢量笔迹与缩放适配

- 笔迹点保存到页面坐标系。
- 缩放、平移、旋转后笔迹不漂移、不模糊。
- 支持撤销、清除和基础橡皮擦能力。

### M4：批注元数据追溯

- 每个批注对象携带可配置 metadata。
- 默认字段包括用户、部门、角色、时间、业务 ID。
- 点击笔迹后命中批注，并返回可展示字段。
- Demo 层可用 Toast、气泡或弹窗展示。

### M5：OFD Demo 联调

- 打开 OFD。
- 显示数字签章或签章占位。
- 手写批注。
- 缩放后笔迹位置稳定。
- 点击笔迹展示元数据。

## 暂不进入

- PDF 同步实现。
- OFD 验签。
- 批注防篡改。
- 服务端同步。
- 复杂权限系统。
- 多 ohpm 包发布。
