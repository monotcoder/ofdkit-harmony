// 字符位置索引：遍历一页所有 TextObject，把每个字符放到 OFD 物理坐标系下（mm）。
// 用于触摸 hit-test + 文字选择 + 复制。
//
// 简化：
// 1) 暂不处理 TextObject 上的 CTM——多数电子发票文本不用 CTM，常用的只是 boundary + textcode.x/y 定位。
//    带 CTM 的稀有情况下，hit-test 会偏差，渲染仍然正常。
// 2) CompositeBlock 只处理 boundary translate；不处理 block 上的 CTM。
// 3) 字符宽度按 fontSize 估算（CJK ≈ fontSize，ASCII ≈ fontSize × 0.55）。Canvas measureText 需要
//    渲染上下文，但 hit-test 命中容忍 ~1 字符宽度，估算够用。

import {
  OFDPage,
  PageObject,
  TextObject,
  TextCode,
  CompositeBlock,
  Layer
} from '../parser/types';

// 单个字符的位置盒子。x/y 是字符 *top-left* 在 OFD 物理坐标系（mm）的位置。
export interface CharBox {
  char: string;
  x: number;
  y: number;
  w: number;
  h: number;
  // 所属 TextObject 的 id（用于"选中一整段文字"）
  textObjId: string;
}

// 一整个 TextObject 聚合后的信息：定位 + 完整文本 + 句子拼接顺序
export interface TextSegment {
  id: string;
  boundaryX: number;
  boundaryY: number;
  boundaryW: number;
  boundaryH: number;
  text: string;     // 这个 TextObject 内所有 TextCode 文字拼起来
}

export class CharBoxIndex {
  readonly charBoxes: CharBox[] = [];
  readonly segments: Map<string, TextSegment> = new Map<string, TextSegment>();
  // 内部递增 key——OFD 标准里 TextObject.ID 可选，发票样本里多数 TextObject 没 ID 或都是 ""，
  // 用 obj.id 当 map key 会让所有匿名段被覆盖成同一个。
  private internalKeyCounter: number = 0;

  build(page: OFDPage): void {
    this.charBoxes.length = 0;
    this.segments.clear();
    this.internalKeyCounter = 0;
    if (page.content === undefined) {
      return;
    }
    page.content.layers.forEach((layer: Layer) => {
      this.walk(layer.objects, 0, 0);
    });
  }

  // 找出落在 (x, y) 点上的 TextObject id；如果同点有多个，取最后绘制的（z 顺序最高）
  hitText(x: number, y: number): string | undefined {
    let hit: string | undefined = undefined;
    for (let i: number = 0; i < this.charBoxes.length; i++) {
      const cb: CharBox = this.charBoxes[i];
      if (x >= cb.x && x <= cb.x + cb.w && y >= cb.y && y <= cb.y + cb.h) {
        hit = cb.textObjId;
      }
    }
    return hit;
  }

  getSegment(id: string): TextSegment | undefined {
    return this.segments.get(id);
  }

  private walk(objects: PageObject[], offX: number, offY: number): void {
    objects.forEach((obj: PageObject) => {
      if (obj.type === 'text') {
        this.collectText(obj as TextObject, offX, offY);
      } else if (obj.type === 'block') {
        const b: CompositeBlock = obj as CompositeBlock;
        const childOffX: number = offX + (b.boundary !== undefined ? b.boundary.x : 0);
        const childOffY: number = offY + (b.boundary !== undefined ? b.boundary.y : 0);
        this.walk(b.children, childOffX, childOffY);
      }
    });
  }

  private collectText(obj: TextObject, offX: number, offY: number): void {
    const baseX: number = offX + obj.boundary.x;
    const baseY: number = offY + obj.boundary.y;
    let combinedText: string = '';
    const internalKey: string = `_seg_${this.internalKeyCounter}`;
    this.internalKeyCounter = this.internalKeyCounter + 1;

    obj.textCodes.forEach((code: TextCode) => {
      const chars: string[] = Array.from(code.text);
      combinedText = combinedText + code.text;
      let cx: number = code.x !== undefined ? code.x : 0;
      let cy: number = code.y !== undefined ? code.y : 0;

      for (let i: number = 0; i < chars.length; i++) {
        if (i > 0) {
          if (code.deltaX !== undefined && code.deltaX.length > 0) {
            const idx: number = i - 1 < code.deltaX.length ? i - 1 : code.deltaX.length - 1;
            cx = cx + code.deltaX[idx];
          }
          if (code.deltaY !== undefined && code.deltaY.length > 0) {
            const idx: number = i - 1 < code.deltaY.length ? i - 1 : code.deltaY.length - 1;
            cy = cy + code.deltaY[idx];
          }
        }
        const w: number = isAscii(chars[i]) ? obj.size * 0.55 : obj.size;
        this.charBoxes.push({
          char: chars[i],
          x: baseX + cx,
          y: baseY + cy - obj.size,
          w,
          h: obj.size,
          textObjId: internalKey
        });
      }
    });

    this.segments.set(internalKey, {
      id: internalKey,
      boundaryX: baseX,
      boundaryY: baseY,
      boundaryW: obj.boundary.width,
      boundaryH: obj.boundary.height,
      text: combinedText
    });
  }
}

function isAscii(ch: string): boolean {
  if (ch.length === 0) return false;
  const code: number = ch.charCodeAt(0);
  return code >= 0x20 && code < 0x80;
}
