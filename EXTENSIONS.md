# ofdkit-harmony 扩展开发指南

`ofdkit-harmony` 通过三类扩展点开放对解析与渲染的介入，**所有扩展通过依赖关系叠加，不需要 fork 或 patch 核心代码**。

商业版 [`ofdkit-harmony-pro`](https://gitee.com/notcoder/ofdkit-harmony-pro)（建设中）使用同一套扩展点接入国密验签、OFD↔PDF 转换等付费功能；本文档既是 Pro 版的接口契约，也是开源用户编写自有扩展的参考。

## 概览

| 扩展点 | 用途 | 注册位置 |
|--|--|--|
| `ObjectParserExt` | 解析 Content.xml 中的自定义 XML 标签为页面对象 | `ContentParser.registerObjectParser` |
| `ObjectRendererExt` | 渲染 `CustomPageObject` | `OFDRenderer.registerRenderer` |
| `DocumentExtension` | 监听 Document.xml 的自定义元素，加载关联文件、修改 pages | `OFDParser.registerDocumentExtension` |

注册全部是 **静态方法**，进程级生效。Pro 仓库初始化时调用 `installDefaultExtensions()` 装好开源默认，然后注册自己的扩展按 `customType` 同名覆盖。

## 数据流

```
OFD.xml + Document.xml
        │
        ▼
   [OFDParser]──── DocumentExtension.apply(ctx)   ◄── 加载外部资源、追加 PageObject 到 pages
        │
        ▼
   [ContentParser.parseObject]
        │  内部 switch 已知类型；未知标签 ──► ObjectParserExt.parse(node)
        ▼
   PageObject[]（含 CustomPageObject）
        │
        ▼
   [OFDRenderer.renderObject]
        │  switch obj.type；'custom' 分支 ──► ObjectRendererExt.render(obj, ctx, context)
        ▼
   Canvas 输出
```

## 自定义页面对象类型

扩展产出的对象统一走 `CustomPageObject`（在 `PageObject` 类型 union 内）：

```typescript
interface CustomPageObject extends BasePageObject {
  type: 'custom';
  customType: string;   // 路由标识，渲染器同名注册即可处理
  payload: Object;      // 扩展自定义数据，渲染器自行 cast
}

interface BasePageObject {
  id: string;
  boundary: PageBox;
  ctm?: CTM;
  drawParam?: string;
  visible?: boolean;
}
```

`customType` 由扩展方约定，建议形如 `'signature'` / `'watermark'` / `'formfield'` / `'<vendor>.<feature>'`。

## ObjectParserExt：解析自定义 XML 对象

监听 Content.xml 里 Layer 下未知的子标签，把它转成 `CustomPageObject`。

### 接口

```typescript
import { ContentParser, ObjectParserExt, CustomPageObject } from 'ofdkit-harmony';
import { XmlNode, XmlParser, ParseHelpers } from 'ofdkit-harmony';

interface ObjectParserExt {
  customType: string;      // 与 ObjectRendererExt 配对的路由标识
  nodeNames: string[];     // 监听的 XML 标签名，多个会被分别注册
  parse(node: XmlNode): CustomPageObject | undefined;
}
```

### 示例：水印对象

假设你的厂商扩展了 OFD，在 Content.xml 里出现 `<vendor:Watermark Boundary="..." Text="机密" Opacity="0.3"/>` 标签。

```typescript
import { ContentParser, ObjectParserExt, CustomPageObject, XmlNode, XmlParser, ParseHelpers } from 'ofdkit-harmony';

interface WatermarkPayload {
  text: string;
  opacity: number;
}

class WatermarkParser implements ObjectParserExt {
  readonly customType: string = 'watermark';
  readonly nodeNames: string[] = ['Watermark'];

  parse(node: XmlNode): CustomPageObject | undefined {
    const boundary = ParseHelpers.box(XmlParser.requireAttr(node, 'Boundary'));
    const payload: WatermarkPayload = {
      text: XmlParser.attr(node, 'Text') ?? '',
      opacity: ParseHelpers.optionalNumber(XmlParser.attr(node, 'Opacity')) ?? 0.3
    };
    return {
      type: 'custom',
      id: XmlParser.requireAttr(node, 'ID'),
      boundary,
      ctm: ParseHelpers.optionalCTM(XmlParser.attr(node, 'CTM')),
      drawParam: XmlParser.attr(node, 'DrawParam'),
      customType: 'watermark',
      payload
    };
  }
}

ContentParser.registerObjectParser(new WatermarkParser());
```

## ObjectRendererExt：渲染自定义对象

每个 `CustomPageObject` 在 `OFDRenderer.renderObject` 中按 `customType` 查表，命中扩展就调它的 `render`。

### 接口

```typescript
import { OFDRenderer, ObjectRendererExt, RenderContext, CustomPageObject } from 'ofdkit-harmony';

interface ObjectRendererExt {
  customType: string;
  render(obj: CustomPageObject, ctx: CanvasRenderingContext2D, context: RenderContext): void;
}

interface RenderContext {
  pxPerMm: number;                              // 当前 Canvas 的 mm→px 系数
  resources: OFDResources | undefined;          // 全文档资源索引（字体/图片/DrawParam）
  pixelMaps: Map<string, image.PixelMap>;       // OFDPageView 已预加载的图片
  fontFamilies: Map<string, string>;            // resourceID → 已注册的 Canvas 字体族名
}
```

### 调用约定

框架调用 `render` **之前**：
- 已经 `ctx.translate(obj.boundary.x, obj.boundary.y)` —— 你直接用对象局部坐标绘制
- 已经 `ctx.transform(...)` 应用了 `obj.ctm`（若有）
- 整个 ctx 处于 `ctx.scale(pxPerMm, pxPerMm)` 状态 —— 路径、几何用 mm 单位

**唯一例外**：HarmonyOS Canvas 中 `ctx.font` 的字号是绝对 vp，不跟随 `ctx.scale`，所以**字号要单独乘 `context.pxPerMm`**：

```typescript
const fontMm: number = 5;  // 你想要 5mm 高的字
ctx.font = `${fontMm * context.pxPerMm}px sans-serif`;
ctx.fillText('文本', 0, fontMm);  // 坐标用 mm，框架已经 translate 过
```

### 示例：渲染水印

承接前面 `WatermarkParser`：

```typescript
import { OFDRenderer, ObjectRendererExt, RenderContext, CustomPageObject } from 'ofdkit-harmony';

class WatermarkRenderer implements ObjectRendererExt {
  readonly customType: string = 'watermark';

  render(obj: CustomPageObject, ctx: CanvasRenderingContext2D, context: RenderContext): void {
    const w = obj.boundary.width;
    const h = obj.boundary.height;
    const payload = obj.payload as WatermarkPayload;

    ctx.globalAlpha = payload.opacity;
    ctx.fillStyle = '#888888';
    const fontMm = Math.min(w, h) / 3;
    ctx.font = `bold ${fontMm * context.pxPerMm}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(payload.text, w / 2, h / 2);
    ctx.globalAlpha = 1.0;
  }
}

OFDRenderer.registerRenderer(new WatermarkRenderer());
```

### 覆盖开源版默认渲染

开源版自带 `SignaturePlaceholderRenderer`（customType = `'signature'`）。Pro 版要绘制真实印章，只需注册同名 customType：

```typescript
import { installDefaultExtensions, OFDRenderer, ObjectRendererExt, RenderContext, CustomPageObject, SignaturePayload } from 'ofdkit-harmony';

installDefaultExtensions();  // 先装开源默认

class ProSignatureRenderer implements ObjectRendererExt {
  readonly customType: string = 'signature';

  render(obj: CustomPageObject, ctx: CanvasRenderingContext2D, context: RenderContext): void {
    const payload = obj.payload as SignaturePayload;
    // 1. 用 payload.signedValuePath 解 PKCS#7 → 取证书与签名值
    // 2. 用证书公钥做 SM2 验签
    // 3. 提取签章图像 PixelMap，drawImage
    // 4. 角标绘制 ✓ 验签通过 / ✗ 验签失败
  }
}

OFDRenderer.registerRenderer(new ProSignatureRenderer());  // 同 customType 覆盖默认
```

## DocumentExtension：文档级资源加载

监听 Document.xml 的自定义元素（如 `<Annotations>` / `<Signatures>` / 厂商自定义），加载外部文件并修改 `pages`。

### 接口

```typescript
import { OFDParser, DocumentExtension, DocumentExtensionContext } from 'ofdkit-harmony';

interface DocumentExtension {
  name: string;
  apply(context: DocumentExtensionContext): Promise<void>;
}

interface DocumentExtensionContext {
  extractDir: string;          // OFD 已解压目录的绝对路径
  docBaseDir: string;          // Document.xml 所在的相对路径（如 'Doc_0'）
  documentNode: XmlNode;       // 已解析的 Document.xml 根节点
  pages: OFDPage[];            // 已组装的页面数组，可读取/修改
  fileAdapter: OFDFileAdapter; // 文件读取接口
}
```

### 调用时机

`OFDParser.parse` 在以下步骤之后调用所有已注册的 `DocumentExtension`：

1. OFD.xml 解析
2. Document.xml 解析、资源加载、模板页应用、所有 Content.xml 加载
3. `pages` 数组构造完毕
4. **此时** 顺序调用每个 `DocumentExtension.apply(ctx)`

扩展可以：
- 在 `documentNode` 上找自己关心的元素
- 加载关联的 XML 文件（用 `fileAdapter.readText`）
- 解析后追加 `Layer` 或 `PageObject` 到 `pages` 中对应页

### 示例：加载厂商扩展的"页面书签"

```typescript
import { OFDParser, DocumentExtension, DocumentExtensionContext, XmlParser, OFDPage, Layer } from 'ofdkit-harmony';

class BookmarkExtension implements DocumentExtension {
  readonly name: string = 'bookmarks';

  async apply(context: DocumentExtensionContext): Promise<void> {
    const loc = XmlParser.childText(context.documentNode, 'VendorBookmarks');
    if (loc === undefined) return;
    const path = context.fileAdapter.joinPath(
      context.extractDir,
      context.fileAdapter.joinPath(context.docBaseDir, loc)
    );
    if (!(await context.fileAdapter.exists(path))) return;
    const xml = await context.fileAdapter.readText(path);
    const root = XmlParser.parse(xml);

    XmlParser.findChildren(root, 'Bookmark').forEach((bm: XmlNode) => {
      const pageID = XmlParser.attr(bm, 'PageID');
      const target = context.pages.find((p: OFDPage) => p.id === pageID);
      if (target === undefined) return;
      // 追加书签层、自定义对象、改 page.content.layers 等...
    });
  }
}

OFDParser.registerDocumentExtension(new BookmarkExtension());
```

### 参考实现

开源版自带的两个 `DocumentExtension` 是最佳学习材料：

- [`AnnotationExtension`](./library/src/main/ets/ofdkit/parser/extensions/AnnotationExtension.ets) —— 加载 `Annots.xml`，把 Annot.Appearance 内的对象作为 Layer 追加
- [`SignatureExtension`](./library/src/main/ets/ofdkit/parser/extensions/SignatureExtension.ets) —— 加载 `Signatures.xml` 与每个 `Signature.xml`，把 StampAnnot 作为 `CustomPageObject` 追加，配合 `SignaturePlaceholderRenderer` 形成完整链路

## 工具与公共能力

扩展内可直接调用的核心工具：

| 工具 | 用途 |
|--|--|
| `XmlParser.parse(xml)` | XML → DOM 树（`XmlNode`） |
| `XmlParser.findChild` / `findChildren` / `attr` / `requireAttr` / `childText` | DOM 节点访问 |
| `ParseHelpers.box / optionalCTM / color / number / optionalNumber / numberArray` | OFD 数据格式（Box / CTM / Color / ST_Array） |
| `ParseHelpers.optionalDeltaArray` | OFD `g N v` 重复格式的 ST_Array |
| `ResourceParser.resolveDrawParam(id, drawParams)` | 沿 Relative 链合并 DrawParam |

import 路径：

```typescript
import { XmlParser, ParseHelpers, ResourceParser } from 'ofdkit-harmony';
```

## customType 命名约定

避免冲突：

| customType | 占用方 |
|--|--|
| `signature` | 开源版 `SignatureExtension`（占位） / Pro 版（真实验签） |
| `annotation` | 开源版（实际未用，Annotations 直接转 Layer 而非 CustomPageObject） |
| `formfield`、`barcode` 等 | 预留未占用 |
| `<vendor>.<feature>` | 第三方厂商自用 |

如果你计划注册的 `customType` 与未来开源版冲突，建议加 `vendor.` 前缀。

## 注册时机

推荐在应用启动时（如 `EntryAbility.onCreate` 或入口 `@Component.aboutToAppear`）调用一次：

```typescript
import { installDefaultExtensions } from 'ofdkit-harmony';

aboutToAppear(): void {
  installDefaultExtensions();
  // 接着注册你自己的扩展
  ContentParser.registerObjectParser(new WatermarkParser());
  OFDRenderer.registerRenderer(new WatermarkRenderer());
  OFDParser.registerDocumentExtension(new BookmarkExtension());
}
```

扩展注册是进程级、幂等可重复调用（同 `customType` 后注册的覆盖先注册的）。如需清空重装，调用 `OFDParser.clearDocumentExtensions()` / `OFDRenderer.clearRenderers()` / `ContentParser.clearObjectParsers()`。

## FAQ

**Q：能不能在解析阶段就替换内置对象（如 TextObject）？**
A：当前不支持。`ObjectParserExt` 只处理"内置 switch 没认出的"标签。内置类型修改需要 fork 核心，不在扩展点范围内。

**Q：扩展能拦截全文档（多页）解析失败再降级吗？**
A：`DocumentExtension.apply` 中可以读所有 `context.pages`，但当前未提供 hook 在解析失败时回调。如有需要可提 Issue。

**Q：注册顺序重要吗？**
A：`ObjectParserExt` 和 `ObjectRendererExt` 按 `customType` 路由，**后注册的覆盖先注册的**。`DocumentExtension` 按注册顺序遍历调用（开源默认装的 Annotation / Signature 会先跑）。
