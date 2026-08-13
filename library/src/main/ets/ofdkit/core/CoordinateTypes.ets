import { PageBox } from '../parser/types';

// 功能开头：统一描述文档页坐标、视口坐标和屏幕坐标，避免签章/批注各自计算。
// 未来计划：加入旋转、裁剪框、连续滚动偏移和多页视口映射。
export interface Point {
  x: number;
  y: number;
}

export interface PagePoint extends Point {
  pageIndex: number;
}

export interface ViewportTransform {
  scale: number;
  offsetX: number;
  offsetY: number;
}

export class PageCoordinateMapper {
  constructor(
    private readonly pageIndex: number,
    private readonly pageBox: PageBox,
    private readonly transform: ViewportTransform
  ) {}

  pageToViewport(point: Point): Point {
    return {
      x: (point.x - this.pageBox.x) * this.transform.scale + this.transform.offsetX,
      y: (point.y - this.pageBox.y) * this.transform.scale + this.transform.offsetY
    };
  }

  viewportToPage(point: Point): PagePoint {
    return {
      pageIndex: this.pageIndex,
      x: (point.x - this.transform.offsetX) / this.transform.scale + this.pageBox.x,
      y: (point.y - this.transform.offsetY) / this.transform.scale + this.pageBox.y
    };
  }
}
