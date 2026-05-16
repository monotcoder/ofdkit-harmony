# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [0.1.0] - 2026-05-16

第一个相对完整的版本：能解析、能渲染、能扩展，能配合 Pro 版做真实国密验签。

### 解析

- OFD 包入口：`OFD.xml` → `Document.xml` → `Content.xml` 全链路解析
- 自研 XML DOM 解析器（命名空间、嵌套节点、XML 实体处理）
- 页面对象：TextObject / PathObject / ImageObject / CompositeBlock（PageBlock 嵌套）
- 变换矩阵（CTM）、Boundary 局部坐标、ZOrder
- 资源索引：PublicRes / DocumentRes 的 Fonts / MultiMedias / DrawParams
- DrawParam 继承链合并（含 Relative 循环引用保护）
- AbbreviatedData 命令：S / M / L / Q / B / C（A 圆弧暂占位）
- DeltaX / DeltaY 逐字定位，含 ST_Array `g N v` 重复格式
- TemplatePage 模板页继承（ZOrder Background / Foreground）
- 路径大小写不敏感解析：`OFDFileAdapter.resolveCaseInsensitive` 兜底 OFD 自身写错大小写的样本（如 `TPLS` vs `Tpls`）

### 渲染

- Canvas 页面渲染（按文档顺序保留 z-order）
- 文字：字体注册 / italic / weight / HScale / DeltaX / DeltaY
- 路径：S/M/L/Q/B/C；Fill="true" 但无 FillColor 时跳过填充（对齐主流阅读器）
- 图片：image.createImageSource → PixelMap → drawImage
- DrawParam：Layer 层默认值下传作为子对象 fallback
- `OFDRenderer.renderEmbedded`：嵌入渲染入口，给 OFD 套 OFD 场景（如矢量电子印章）用
- OFDPageView 组件：捏合缩放（0.5x ~ 5x）、单指拖动平移、双击复位

### 扩展点

- 三类扩展点：
  - `ObjectParserExt` — 自定义对象解析
  - `ObjectRendererExt` + `RenderContext` — 自定义对象渲染
  - `DocumentExtension` — 文档级扩展，解析后异步处理（验签、外部资源等）
- `CustomPageObject` 对扩展开放，类型 union 加 `'custom'` 分支
- 内置扩展：
  - `AnnotationExtension`：加载 `Annots.xml`，按 `Appearance.Boundary` 封装为 CompositeBlock 追加到对应 layer
  - `SignatureExtension`：解析 `StampAnnot`，`SignaturePayload` 暴露 `signedValuePath` / `signatureXmlPath` / `extractDir` 给 Pro 版验签使用；兼容 `Signs/Signatures.xml` 兜底路径
  - `SignaturePlaceholderRenderer`：红虚线框 + "需 Pro 验签"
- `installDefaultExtensions()`：一键安装

### 工程

- ohpm library 抽离：发布为独立 `ofdkit-harmony` 包，entry 通过 file 协议依赖
- 详细扩展开发指南：[EXTENSIONS.md](./EXTENSIONS.md)
- 最低支持：HarmonyOS NEXT 6.1.0 / API 23

### 关键修复

- `ctx.font` 在 HarmonyOS Canvas 中不跟随 `ctx.scale` 变换 → 字号单独乘 pxPerMm
- `drawTextCode` 无 DeltaX/DeltaY 时所有字符叠在同一像素 → 改为整段 fillText
- Canvas 大小不一致 → 统一改用 `width('100%') + aspectRatio` 自适应父容器
- TextCode DeltaX 字符自然宽度 > DeltaX 时按自然宽度推进（防字符叠在一起）
- TextCode 防叠字加 10% 容差，避免 CJK 度量误差撑开整段 label
- DeltaX 数组短于字符数时重复使用最后一个值（修发票标题"重庆增值税电子普通发票"塌成一个字位）
- 负 DeltaX（如密码区 `-67.5`）不被自然宽度兜底覆盖（修密码区多行布局）
- 字体注册路径加 `file://` 前缀，否则被当 rawfile 找不到嵌入字体
- Layer.DrawParam 下传作为子对象 fallback（修发票字段/边框颜色丢失）
- PathObject `Fill="true"` 但无 FillColor 时跳过填充（修防伪暗记被涂成实心盘）
- Annotation 内对象按 `Appearance.Boundary` 偏移定位（修印章/水印塌到左上角）
- 模板页解析放宽 `<Area>` 要求——模板页通常不带 PhysicalBox
- TextObject / PathObject / ImageObject 的 `ID` 改为可选——部分发票样本不带 ID

### 已知未实现

- ColorSpace（CMYK / Pattern / Gradient）：当前都按 RGB 处理
- AbbreviatedData `A` 圆弧命令
- 表单填充（CT_FormFile）
- 文字选择 / 复制
- 多页缩略图

### 工程实践 / 自托管字体

- 当前对没嵌入字体的 OFD（例如多数发票），文字会退回 HarmonyOS Sans。视觉上比纸质宋体/楷体粗黑，属正常现象。如需更接近纸质，可在 app 侧打包思源黑体/宋体等 OFL 字体并通过 `font.registerFont` 兜底（非本库职责）。
