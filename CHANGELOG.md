# Changelog

本项目遵循简洁的变更记录格式，正式发布后会按版本整理。

## Unreleased

- 初始化 HarmonyOS NEXT ArkTS 工程。
- 搭建 OFD 阶段一解析骨架。
- 接入 OFD 文件选择、缓存复制和 ZIP 解压。
- 将最低兼容版本调整为 HarmonyOS NEXT 6.1.0 / API 23。
- 补充开源协议和贡献文档。
- 实现阶段二：页面内容对象解析。
- 新增 ContentParser 解析文字、路径、图片对象。
- 支持图层结构和变换矩阵（CTM）解析。
- 更新 Index 页面展示页面内容统计信息。
- **实现阶段三：Canvas 页面渲染。**
- **新增 OFDRenderer 渲染器，支持文字、路径、图片对象渲染。**
- **新增 OFDPageView 组件，封装 Canvas 渲染逻辑。**
- **支持页面预览和切换功能。**
- **实现路径数据解析（M、L、C、Q、Z 命令）。**
- **修正坐标系统：正确实现 OFD 毫米到像素的转换（1mm = 96/25.4 px，遵循 GB/T 33190-2016 标准）。**
- **修正 TextObject 渲染：TextCode 的 X、Y 是相对于 Boundary 的偏移量。**
- **修正字体大小单位：OFD 字体大小单位是毫米。**
- **启用 PathObject 渲染：实现基本的路径绘制功能。**
- **修复 ArkTS 类型安全问题。**
- 用自研 XML DOM 解析器替换正则解析，修正命名空间、嵌套节点、XML 实体处理。
- 修正 OFD 对象属性识别（Font/Size/Stroke/Fill/CTM/ResourceID 等本是属性，原作为子元素读取）。
- ContentParser 按文档顺序遍历，保留绘制 z-order，支持 PageBlock 嵌套。
- 修正 AbbreviatedData 命令解析为 GB/T 33190 规定的 S/M/L/Q/B/A/C。
- 修正 TextCode 坐标：CTM 应用前先 translate 到 Boundary 局部原点。
- 实现 DeltaX/DeltaY 逐字定位，含 ST_Array `g N v` 重复格式。
- OFDPageView 监听 @Prop 变化自动重绘。
- **实现阶段四：资源管理。**
- **新增 ResourceParser，解析 PublicRes/DocumentRes（Fonts/MultiMedias/DrawParams）。**
- **字体加载：通过 font.registerFont 注册 OFD 嵌入字体到系统。**
- **图片加载：使用 image.createImageSource 解码到 PixelMap，Canvas 真实绘制。**
- **DrawParam 应用：支持 Relative 继承链合并（含循环引用保护）。**
- **实现阶段五：扩展点系统 + Library 抽离。**
- **三类扩展点：对象解析（ObjectParserExt）、对象渲染（ObjectRendererExt + RenderContext）、文档级（DocumentExtension）。**
- **CustomPageObject 类型对扩展开放，类型 union 加 'custom' 分支。**
- **AnnotationExtension：加载 Annots.xml，把 Annot.Appearance 转成 Layer 追加。**
- **TemplatePage 模板页继承：支持 ZOrder Background/Foreground，模板内容合并到主页 layer 列表。**
- **SignatureExtension + SignaturePlaceholderRenderer：解析 StampAnnot 占位，红虚线框 + "需 Pro 验签"。**
- **installDefaultExtensions：一键安装开源版默认扩展。**
- **ohpm Library 抽离：ofdkit 代码从 entry 移到独立 library 模块，name=ofdkit-harmony。**
- **手势：双指捏合缩放（0.5x ~ 5x）、单指拖动平移、双击复位（视觉级 transform）。**
- 修复 ctx.font 在 HarmonyOS Canvas 中不跟随 ctx.scale 变换的差异（字号单独乘 pxPerMm）。
- 修复 drawTextCode 在无 DeltaX/DeltaY 时所有字符叠在同一像素（改为整段 fillText）。
- 修复 Canvas 大小问题，统一改用 width('100%') + aspectRatio 自适应父容器。

