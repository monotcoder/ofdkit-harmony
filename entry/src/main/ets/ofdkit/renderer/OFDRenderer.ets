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
  TextCode,
  CTM,
  Color,
  OFDResources,
  OFDDrawParam
} from '../parser/types';
import { ResourceParser } from '../parser/ResourceParser';

export interface RenderResources {
  resources: OFDResources;
  pixelMaps: Map<string, image.PixelMap>;
  fontFamilies: Map<string, string>;
}

export class OFDRenderer {
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
    console.info(`[ofdkit][diag] ctx.width=${widthPx} ctx.height=${heightPx} pxPerMm=${this.pxPerMm.toFixed(3)}`);

    // sanity check：绕开所有 OFD 数据，在 Canvas 左上角画一个明显的红字
    ctx.save();
    ctx.fillStyle = '#FF0000';
    ctx.font = '40px sans-serif';
    ctx.textBaseline = 'top';
    ctx.textAlign = 'left';
    ctx.fillText('TEST 测试 ABC', 10, 10);
    console.info(`[ofdkit][diag] sanity test painted; ctx.font="${ctx.font}" fillStyle="${ctx.fillStyle}"`);
    ctx.restore();

    ctx.save();
    ctx.scale(this.pxPerMm, this.pxPerMm);

    // sanity check 2：在 scale 状态下画一个紫色大字，验证 ctx.scale 后 fillText 是否工作
    ctx.save();
    ctx.fillStyle = '#FF00FF';
    ctx.font = `${30 * this.pxPerMm}px sans-serif`;
    ctx.textBaseline = 'top';
    ctx.textAlign = 'left';
    ctx.fillText('SCALED 紫字', 20, 80);
    console.info('[ofdkit][diag] scaled sanity painted at mm(20,80) font size 30mm');
    ctx.restore();

    page.content.layers.forEach((layer: Layer) => this.renderLayer(layer, ctx));
    ctx.restore();

    console.info(`[ofdkit] 页面 ${page.pageIndex + 1} 渲染完成（${widthPx}x${heightPx}px, ${this.pxPerMm.toFixed(2)}px/mm）`);
  }

  private renderLayer(layer: Layer, ctx: CanvasRenderingContext2D): void {
    layer.objects.forEach((obj: PageObject) => this.renderObject(obj, ctx));
  }

  private renderObject(obj: PageObject, ctx: CanvasRenderingContext2D): void {
    ctx.save();
    try {
      if (obj.type === 'text') {
        this.renderText(obj as TextObject, ctx);
      } else if (obj.type === 'path') {
        this.renderPath(obj as PathObject, ctx);
      } else if (obj.type === 'image') {
        this.renderImage(obj as ImageObject, ctx);
      } else if (obj.type === 'block') {
        this.renderBlock(obj as CompositeBlock, ctx);
      }
    } catch (error) {
      console.warn(`[ofdkit] 渲染对象失败：${error}`);
    }
    ctx.restore();
  }

  private renderText(obj: TextObject, ctx: CanvasRenderingContext2D): void {
    ctx.translate(obj.boundary.x, obj.boundary.y);
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }
    if (obj.hScale !== undefined && obj.hScale !== 1) {
      ctx.scale(obj.hScale, 1);
    }

    const dp: OFDDrawParam | undefined = this.resolveDrawParam(obj.drawParam);
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

    console.info(`[ofdkit][text] id=${obj.id} fontId=${obj.font} sizeMm=${obj.size} fontPx=${fontPx.toFixed(2)} family=${family} effectiveFont="${ctx.font}" fill=${ctx.fillStyle} shouldFill=${shouldFill} codes=${obj.textCodes.length}`);

    obj.textCodes.forEach((code: TextCode) => this.drawTextCode(code, ctx, shouldFill, shouldStroke));
  }

  private drawTextCode(code: TextCode, ctx: CanvasRenderingContext2D, fill: boolean, stroke: boolean): void {
    if (code.text.length === 0) {
      console.info(`[ofdkit][text] empty TextCode skipped`);
      return;
    }
    const chars: string[] = Array.from(code.text);
    let x: number = code.x ?? 0;
    let y: number = code.y ?? 0;
    console.info(`[ofdkit][text] drawTextCode text="${code.text}" startPos=(${x},${y}) chars=${chars.length} fill=${fill} stroke=${stroke}`);

    for (let i: number = 0; i < chars.length; i++) {
      if (i > 0) {
        if (code.deltaX !== undefined && i - 1 < code.deltaX.length) {
          x = x + code.deltaX[i - 1];
        }
        if (code.deltaY !== undefined && i - 1 < code.deltaY.length) {
          y = y + code.deltaY[i - 1];
        }
      }
      if (fill) {
        ctx.fillText(chars[i], x, y);
      }
      if (stroke) {
        ctx.strokeText(chars[i], x, y);
      }
    }
  }

  private renderPath(obj: PathObject, ctx: CanvasRenderingContext2D): void {
    ctx.translate(obj.boundary.x, obj.boundary.y);
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }

    const data: string | undefined = obj.abbreviatedData;
    if (data === undefined || data.length === 0) {
      return;
    }

    const dp: OFDDrawParam | undefined = this.resolveDrawParam(obj.drawParam);
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

    if (fill) {
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

  private renderBlock(obj: CompositeBlock, ctx: CanvasRenderingContext2D): void {
    if (obj.boundary !== undefined) {
      ctx.translate(obj.boundary.x, obj.boundary.y);
    }
    if (obj.ctm !== undefined) {
      this.applyCTM(obj.ctm, ctx);
    }
    obj.children.forEach((child: PageObject) => this.renderObject(child, ctx));
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
    const registered: string | undefined = this.renderResources?.fontFamilies.get(fontId);
    if (registered !== undefined) {
      return `"${registered}", sans-serif`;
    }
    return 'sans-serif';
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
