// 将 OFD 页面对象渲染到 Canvas。
// 坐标系：OFD 用毫米。每次绘制根据 ctx.width / physicalBox.width 现场算 px/mm，避开 vp/px 混淆。
// 对象局部坐标：translate(boundary.x, boundary.y) 后再 transform(CTM)，内部坐标都基于 boundary 局部坐标系。
// 资源依赖：renderText 查注册过的字体名，renderImage 查 PixelMap，DrawParam 提供绘制参数默认值。

import { image } from '@kit.ImageKit';
import {
  OFDPage,
  Layer,
  PageObject,
  TextObject,
  PathObject,
  ImageObject,
  CompositeBlock,
  CustomPageObject,
  TextCode,
  CTM,
  Color,
  OFDResources,
  OFDFont,
  OFDDrawParam
} from '../parser/types';
import { ResourceParser } from '../parser/ResourceParser';

export interface RenderResources {
  resources: OFDResources;
  pixelMaps: Map<string, image.PixelMap>;
  fontFamilies: Map<string, string>;
}

// 传给自定义渲染扩展的上下文：包含当前 px/mm 比例、资源索引、已加载的字体/图片。
export interface RenderContext {
  pxPerMm: number;
  resources: OFDResources | undefined;
  pixelMaps: Map<string, image.PixelMap>;
  fontFamilies: Map<string, string>;
}

// 对象渲染扩展点：按 customType 注册，渲染 CustomPageObject。
// 调用前框架已 translate 到 boundary 原点并应用 CTM，扩展直接用对象局部坐标 (mm) 绘制即可。
export interface ObjectRendererExt {
  customType: string;
  render(obj: CustomPageObject, ctx: CanvasRenderingContext2D, context: RenderContext): void;
}

export class OFDRenderer {
  private static customRenderers: Map<string, ObjectRendererExt> = new Map<string, ObjectRendererExt>();
  // 全局兜底字体 family。OFD 文件没嵌入 FontFile 时，文字会落到这个 family；
  // 调用方负责 font.registerFont 注册具体字体文件，本库不打包任何字体（避免凭空增加包体积）。
  // 典型用法：app 启动时 registerFont('SourceHanSerif', 'file://.../source-han.ttf')，
  // 然后 OFDRenderer.setFallbackFontFamily('SourceHanSerif')，OFD 视觉上更接近纸质 PDF。
  private static fallbackFontFamily: string | undefined = undefined;

  static registerRenderer(ext: ObjectRendererExt): void {
    OFDRenderer.customRenderers.set(ext.customType, ext);
  }

  static clearRenderers(): void {
    OFDRenderer.customRenderers.clear();
  }

  static setFallbackFontFamily(family: string | undefined): void {
    OFDRenderer.fallbackFontFamily = family;
  }

  static getFallbackFontFamily(): string | undefined {
    return OFDRenderer.fallbackFontFamily;
  }

  private renderResources: RenderResources | undefined = undefined;
  // 当前页 px/mm 换算系数，渲染时更新。
  // HarmonyOS Canvas 中 ctx.font 的字号是绝对 vp，不跟 ctx.scale 变换，所以字号需要单独乘 pxPerMm。
  private pxPerMm: number = 1;

  setResources(resources: RenderResources | undefined): void {
    this.renderResources = resources;
  }

  renderPage(page: OFDPage, ctx: CanvasRenderingContext2D): void {
    const widthPx: number = ctx.width;
    const heightPx: number = ctx.height;
    ctx.clearRect(0, 0, widthPx, heightPx);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, widthPx, heightPx);

    if (page.content === undefined) {
      console.warn(`[ofdkit] 页面 ${page.pageIndex + 1} 无内容`);
      return;
    }
    if (page.physicalBox.width <= 0) {
      console.warn(`[ofdkit] 页面 ${page.pageIndex + 1} PhysicalBox 宽度异常`);
      return;
    }

    this.pxPerMm = widthPx / page.physicalBox.width;
    ctx.save();
    ctx.scale(this.pxPerMm, this.pxPerMm);
    page.content.layers.forEach((layer: Layer) => this.renderLayer(layer, ctx));
    ctx.restore();

    console.info(`[ofdkit] 页面 ${page.pageIndex + 1} 渲染完成`);
  }

  // 嵌入渲染：把 page 画到调用方已 translate 到的局部坐标系内 (0,0)-(boundsW,boundsH) mm。
  // 用于矢量印章等"OFD 套 OFD"场景：印章 picture.data 解析后是一个完整 OFD，要按印章 boundary 缩放渲染。
  // 与 renderPage 的区别：不 clearRect、不画白底、不动外层 transform，调用方负责 save/restore。
  // outerPxPerMm 是外层 Canvas 当前 1mm 对应的物理像素数（OFD 字号是 mm，但 ctx.font 不跟随 ctx.scale，
  //   所以 renderText 必须知道最终 1mm 等于多少像素才能算字号）。
  renderEmbedded(
    page: OFDPage,
    ctx: CanvasRenderingContext2D,
    boundsW: number,
    boundsH: number,
    outerPxPerMm: number
  ): void {
    if (page.content === undefined) {
      return;
    }
    if (page.physicalBox.width <= 0 || page.physicalBox.height <= 0) {
      return;
    }
    const sx: number = boundsW / page.physicalBox.width;
    const sy: number = boundsH / page.physicalBox.height;
    const previousPxPerMm: number = this.pxPerMm;
    // 缩放后 1mm（印章内部坐标）= sx mm（外层局部坐标）= sx * outerPxPerMm 像素。
    // 印章内坐标在多数情况下 sx≈sy（保持等比），renderText 字号用 sx 做依据。
    this.pxPerMm = outerPxPerMm * sx;
    ctx.save();
    ctx.scale(sx, sy);
    try {
      page.content.layers.forEach((layer: Layer) => this.renderLayer(layer, ctx));
    } finally {
      ctx.restore();
      this.pxPerMm = previousPxPerMm;
    }
  }

  private renderLayer(layer: Layer, ctx: CanvasRenderingContext2D): void {
    // Layer.DrawParam 作为层级默认值传给子对象。OFD 标准里发票常把整层颜色挂 Layer 上，子对象省略。
    layer.objects.forEach((obj: PageObject) => this.renderObject(obj, ctx, layer.drawParam));
  }

  private renderObject(obj: PageObject, ctx: CanvasRenderingContext2D, layerDrawParam?: string): void {
    ctx.save();
    try {
      if (obj.type === 'text') {
        this.renderText(obj as TextObject, ctx, layerDrawParam);
      } else if (obj.type === 'path') {
        this.renderPath(obj as PathObject, ctx, layerDrawParam);
      } else if (obj.type === 'image') {
        this.renderImage(obj as ImageObject, ctx);
      } else if (obj.type === 'block') {
        this.renderBlock(obj as CompositeBlock, ctx, layerDrawParam);
      } else if (obj.type === 'custom') {
        this.renderCustom(obj as CustomPageObject, ctx);
      }
    } catch (error) {
      console.warn(`[ofdkit] 渲染对象失败：${error}`);
    }
    ctx.restore();
  }

  private renderCustom(obj: CustomPageObject, ctx: CanvasRenderingContext2D): void {
    const ext: ObjectRendererExt | undefined = OFDRenderer.customRenderers.get(obj.customType);
    if (ext === undefined) {
      console.warn(`[ofdkit] 未注册 ${obj.customType} 渲染器，跳过对象 ${obj.id}`);
      return;
    }
    ctx.translate(obj.boundary.x, obj.boundary.y);
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }
    ext.render(obj, ctx, this.makeRenderContext());
  }

  private makeRenderContext(): RenderContext {
    const empty: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
    const emptyFonts: Map<string, string> = new Map<string, string>();
    return {
      pxPerMm: this.pxPerMm,
      resources: this.renderResources !== undefined ? this.renderResources.resources : undefined,
      pixelMaps: this.renderResources !== undefined ? this.renderResources.pixelMaps : empty,
      fontFamilies: this.renderResources !== undefined ? this.renderResources.fontFamilies : emptyFonts
    };
  }

  private renderText(obj: TextObject, ctx: CanvasRenderingContext2D, layerDrawParam?: string): void {
    ctx.translate(obj.boundary.x, obj.boundary.y);
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }
    if (obj.hScale !== undefined && obj.hScale !== 1) {
      ctx.scale(obj.hScale, 1);
    }

    const dp: OFDDrawParam | undefined = this.resolveDrawParam(obj.drawParam ?? layerDrawParam);
    const fillColor: Color | undefined = obj.fillColor ?? dp?.fillColor;
    const strokeColor: Color | undefined = obj.strokeColor ?? dp?.strokeColor;
    const family: string = this.fontFamilyFor(obj.font);

    const italic: string = obj.italic === true ? 'italic ' : '';
    const weight: string = obj.weight !== undefined && obj.weight >= 700 ? 'bold ' : '';
    const fontPx: number = obj.size * this.pxPerMm;
    ctx.font = `${italic}${weight}${fontPx}px ${family}`;
    ctx.fillStyle = colorToCss(fillColor, '#000000');
    ctx.strokeStyle = colorToCss(strokeColor, '#000000');
    ctx.textBaseline = 'alphabetic';
    ctx.textAlign = 'left';

    const shouldStroke: boolean = obj.stroke === true;
    const shouldFill: boolean = obj.fill !== false;

    obj.textCodes.forEach((code: TextCode) => this.drawTextCode(code, ctx, shouldFill, shouldStroke));
  }

  private drawTextCode(code: TextCode, ctx: CanvasRenderingContext2D, fill: boolean, stroke: boolean): void {
    if (code.text.length === 0) {
      return;
    }
    const x: number = code.x ?? 0;
    const y: number = code.y ?? 0;

    // 无字符间距数组：让 Canvas 按字体自然字符宽度整段绘制。
    if (code.deltaX === undefined && code.deltaY === undefined) {
      if (fill) {
        ctx.fillText(code.text, x, y);
      }
      if (stroke) {
        ctx.strokeText(code.text, x, y);
      }
      return;
    }

    // 有 DeltaX/DeltaY：按 OFD 标准逐字符放置，相邻字符间用 Delta 推进。
    const chars: string[] = Array.from(code.text);
    let cx: number = x;
    let cy: number = y;
    for (let i: number = 0; i < chars.length; i++) {
      if (i > 0) {
        if (code.deltaX !== undefined && code.deltaX.length > 0) {
          // OFD 规范：DeltaX 数组比字符数少时，最后一个值要重复用（很多发票的标题就一个 DeltaX 覆盖全部字间距）。
          // 防叠字：嵌入子集字体的 ASCII 半角度量在 Canvas 里有时不生效，按 DeltaX 推进时字母相互覆盖。
          // 用自然字形宽度兜底，但留 10% 容差——measureText 对 CJK 字符通常会比真实 1em 略高 ~6%，
          // 不加容差会让整段中文 label 累计撑开 1-2mm，反而撞进相邻字段。
          // HarmonyOS Canvas 在 ctx.scale 之后，measureText 返回的就是用户坐标系（mm）宽度，无需再换算。
          const dxIdx: number = i - 1 < code.deltaX.length ? i - 1 : code.deltaX.length - 1;
          const requestedDx: number = code.deltaX[dxIdx];
          // 仅在正 DeltaX 时考虑自然宽度兜底。负 DeltaX（密码区那种"换行回到行首"的 -67.5）是显式位置控制，必须原样推进。
          if (requestedDx > 0) {
            const naturalMm: number = ctx.measureText(chars[i - 1]).width;
            cx = cx + (naturalMm > requestedDx * 1.1 ? naturalMm : requestedDx);
          } else {
            cx = cx + requestedDx;
          }
        }
        if (code.deltaY !== undefined && code.deltaY.length > 0) {
          const dyIdx: number = i - 1 < code.deltaY.length ? i - 1 : code.deltaY.length - 1;
          cy = cy + code.deltaY[dyIdx];
        }
      }
      if (fill) {
        ctx.fillText(chars[i], cx, cy);
      }
      if (stroke) {
        ctx.strokeText(chars[i], cx, cy);
      }
    }
  }

  private renderPath(obj: PathObject, ctx: CanvasRenderingContext2D, layerDrawParam?: string): void {
    ctx.translate(obj.boundary.x, obj.boundary.y);
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }

    const data: string | undefined = obj.abbreviatedData;
    if (data === undefined || data.length === 0) {
      return;
    }

    const dp: OFDDrawParam | undefined = this.resolveDrawParam(obj.drawParam ?? layerDrawParam);
    const stroke: boolean = obj.stroke !== false;
    const fill: boolean = obj.fill === true;
    const lineWidth: number = obj.lineWidth ?? dp?.lineWidth ?? 0.353;
    const fillColor: Color | undefined = obj.fillColor ?? dp?.fillColor;
    const strokeColor: Color | undefined = obj.strokeColor ?? dp?.strokeColor;

    if (dp !== undefined) {
      if (dp.cap !== undefined) {
        ctx.lineCap = mapLineCap(dp.cap);
      }
      if (dp.join !== undefined) {
        ctx.lineJoin = mapLineJoin(dp.join);
      }
      if (dp.miterLimit !== undefined) {
        ctx.miterLimit = dp.miterLimit;
      }
      if (dp.dashPattern !== undefined) {
        ctx.setLineDash(dp.dashPattern);
      }
      if (dp.dashOffset !== undefined) {
        ctx.lineDashOffset = dp.dashOffset;
      }
    }

    ctx.beginPath();
    PathDataParser.run(data, ctx);

    // Fill="true" 但未指定 FillColor 时，按主流阅读器（数科/福昕）的实际行为跳过填充。
    // 否则发票防伪暗记（圆+X）等只描边的 icon 会被涂成实心盘，遮住描边内容。
    if (fill && fillColor !== undefined) {
      ctx.fillStyle = colorToCss(fillColor, '#000000');
      ctx.fill();
    }
    if (stroke) {
      ctx.strokeStyle = colorToCss(strokeColor, '#000000');
      ctx.lineWidth = lineWidth;
      ctx.stroke();
    }
  }

  private renderImage(obj: ImageObject, ctx: CanvasRenderingContext2D): void {
    ctx.translate(obj.boundary.x, obj.boundary.y);
    const pixelMap: image.PixelMap | undefined = this.renderResources?.pixelMaps.get(obj.resourceID);

    if (pixelMap === undefined) {
      // 资源缺失，画红色占位框
      if (obj.ctm !== undefined) {
        this.applyCTM(obj.ctm, ctx);
      }
      this.drawImagePlaceholder(obj.boundary.width, obj.boundary.height, ctx, true);
      return;
    }

    if (obj.ctm !== undefined) {
      // CTM 把单位正方形 (0,0)-(1,1) 映射到 boundary
      this.applyCTM(obj.ctm, ctx);
      ctx.drawImage(pixelMap, 0, 0, 1, 1);
    } else {
      ctx.drawImage(pixelMap, 0, 0, obj.boundary.width, obj.boundary.height);
    }
  }

  private drawImagePlaceholder(width: number, height: number, ctx: CanvasRenderingContext2D, isError: boolean): void {
    const color: string = isError ? '#FF3333' : '#999999';
    ctx.strokeStyle = color;
    ctx.lineWidth = 0.353;
    ctx.setLineDash([1.5, 1.5]);
    ctx.strokeRect(0, 0, width, height);
    ctx.setLineDash([]);

    ctx.fillStyle = color;
    ctx.font = `${Math.min(width, height) * this.pxPerMm / 4}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(isError ? '图片缺失' : '图片', width / 2, height / 2);
  }

  private renderBlock(obj: CompositeBlock, ctx: CanvasRenderingContext2D, layerDrawParam?: string): void {
    if (obj.boundary !== undefined) {
      ctx.translate(obj.boundary.x, obj.boundary.y);
    }
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }
    // PageBlock 自身的 DrawParam 优先于上层 Layer
    const inherited: string | undefined = obj.drawParam ?? layerDrawParam;
    obj.children.forEach((child: PageObject) => this.renderObject(child, ctx, inherited));
  }

  private applyCTM(ctm: CTM, ctx: CanvasRenderingContext2D): void {
    ctx.transform(ctm.a, ctm.b, ctm.c, ctm.d, ctm.e, ctm.f);
  }

  private resolveDrawParam(id: string | undefined): OFDDrawParam | undefined {
    if (id === undefined || this.renderResources === undefined) {
      return undefined;
    }
    return ResourceParser.resolveDrawParam(id, this.renderResources.resources.drawParams);
  }

  private fontFamilyFor(fontId: string): string {
    const fallback: string | undefined = OFDRenderer.fallbackFontFamily;
    const tail: string = fallback !== undefined && fallback.length > 0
      ? `"${fallback}", sans-serif`
      : 'sans-serif';

    const registered: string | undefined = this.renderResources?.fontFamilies.get(fontId);
    if (registered !== undefined) {
      // 嵌入字体优先，但仍把 fallback 串到末尾——嵌入字体可能子集化、缺某些字符（比如签章里出现的生僻字）。
      return `"${registered}", ${tail}`;
    }
    // 未嵌入 FontFile 时，把 OFD 标注的 FamilyName/FontName 也加进 fallback 链。
    // HarmonyOS 自带宋体/楷体/Courier New 等通用字体的话，Canvas 可以择优匹配，避免全退到 sans-serif 引起字距错位。
    const fontDef: OFDFont | undefined = this.renderResources?.resources.fonts.get(fontId);
    if (fontDef === undefined) {
      return tail;
    }
    const names: string[] = [];
    if (fontDef.familyName !== undefined && fontDef.familyName.length > 0) {
      names.push(`"${fontDef.familyName}"`);
    }
    if (fontDef.fontName.length > 0 && fontDef.fontName !== fontDef.familyName) {
      names.push(`"${fontDef.fontName}"`);
    }
    names.push(tail);
    return names.join(', ');
  }
}

function colorToCss(color: Color | undefined, fallback: string): string {
  if (color === undefined) {
    return fallback;
  }
  const parts: number[] = color.value.split(/\s+/)
    .filter((item: string) => item.length > 0)
    .map((item: string) => Number(item))
    .filter((value: number) => !Number.isNaN(value));
  if (parts.length < 3) {
    return fallback;
  }
  const r: number = clampByte(parts[0]);
  const g: number = clampByte(parts[1]);
  const b: number = clampByte(parts[2]);
  if (color.alpha !== undefined) {
    const a: number = Math.max(0, Math.min(1, color.alpha / 255));
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  }
  return `rgb(${r}, ${g}, ${b})`;
}

function clampByte(n: number): number {
  if (n <= 1 && n >= 0 && !Number.isInteger(n)) {
    return Math.round(n * 255);
  }
  return Math.max(0, Math.min(255, Math.round(n)));
}

function mapLineCap(cap: string): CanvasLineCap {
  if (cap === 'Round') return 'round';
  if (cap === 'Square') return 'square';
  return 'butt';
}

function mapLineJoin(join: string): CanvasLineJoin {
  if (join === 'Round') return 'round';
  if (join === 'Bevel') return 'bevel';
  return 'miter';
}

// OFD AbbreviatedData 命令（GB/T 33190-2016）：
// S/M x y - 起始点；L x y - 直线；Q x1 y1 x y - 二次贝塞尔；B x1 y1 x2 y2 x y - 三次贝塞尔；
// A rx ry rot largeArc sweep x y - 圆弧；C - 闭合
class PathDataParser {
  static run(data: string, ctx: CanvasRenderingContext2D): void {
    const tokens: string[] = data.trim().split(/\s+/).filter((t: string) => t.length > 0);
    let i: number = 0;
    while (i < tokens.length) {
      const cmd: string = tokens[i];
      i++;
      switch (cmd) {
        case 'S':
        case 'M': {
          const x: number = Number(tokens[i]);
          const y: number = Number(tokens[i + 1]);
          i += 2;
          if (!Number.isNaN(x) && !Number.isNaN(y)) {
            ctx.moveTo(x, y);
          }
          break;
        }
        case 'L': {
          const x: number = Number(tokens[i]);
          const y: number = Number(tokens[i + 1]);
          i += 2;
          if (!Number.isNaN(x) && !Number.isNaN(y)) {
            ctx.lineTo(x, y);
          }
          break;
        }
        case 'Q': {
          const x1: number = Number(tokens[i]);
          const y1: number = Number(tokens[i + 1]);
          const x: number = Number(tokens[i + 2]);
          const y: number = Number(tokens[i + 3]);
          i += 4;
          if (!Number.isNaN(x) && !Number.isNaN(y)) {
            ctx.quadraticCurveTo(x1, y1, x, y);
          }
          break;
        }
        case 'B': {
          const x1: number = Number(tokens[i]);
          const y1: number = Number(tokens[i + 1]);
          const x2: number = Number(tokens[i + 2]);
          const y2: number = Number(tokens[i + 3]);
          const x: number = Number(tokens[i + 4]);
          const y: number = Number(tokens[i + 5]);
          i += 6;
          if (!Number.isNaN(x) && !Number.isNaN(y)) {
            ctx.bezierCurveTo(x1, y1, x2, y2, x, y);
          }
          break;
        }
        case 'A': {
          i += 7;
          console.warn('[ofdkit] AbbreviatedData 命令 A（圆弧）暂未支持');
          break;
        }
        case 'C': {
          ctx.closePath();
          break;
        }
        default:
          console.warn(`[ofdkit] AbbreviatedData 未识别命令：${cmd}`);
          break;
      }
    }
  }
}
