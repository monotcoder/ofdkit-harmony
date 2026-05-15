// 默认签章渲染器：红色虚线框 + "签章 / 需 Pro 验签" 占位文字。
// Pro 仓库可注册同名 customType 的 ObjectRendererExt 覆盖，绘制实际签章图像 + 验签结果徽章。

import { ObjectRendererExt, RenderContext } from '../OFDRenderer';
import { CustomPageObject } from '../../parser/types';

export class SignaturePlaceholderRenderer implements ObjectRendererExt {
  readonly customType: string = 'signature';

  render(obj: CustomPageObject, ctx: CanvasRenderingContext2D, context: RenderContext): void {
    const w: number = obj.boundary.width;
    const h: number = obj.boundary.height;

    ctx.strokeStyle = '#CC0066';
    ctx.lineWidth = 0.35;
    ctx.setLineDash([1.5, 1.5]);
    ctx.strokeRect(0, 0, w, h);
    ctx.setLineDash([]);

    const titleMm: number = Math.min(w, h) / 5;
    const hintMm: number = titleMm * 0.55;
    ctx.fillStyle = '#CC0066';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `bold ${titleMm * context.pxPerMm}px sans-serif`;
    ctx.fillText('签章', w / 2, h / 2 - titleMm * 0.45);
    ctx.font = `${hintMm * context.pxPerMm}px sans-serif`;
    ctx.fillText('需 Pro 验签', w / 2, h / 2 + titleMm * 0.45);
  }
}
