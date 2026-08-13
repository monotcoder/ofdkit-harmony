import { PagePoint } from '../core';
import { AnnotationMetadata } from '../metadata';

// 功能开头：手写签批先以矢量笔迹建模，保证缩放清晰且可后续编辑。
// 未来计划：加入压力平滑、速度采样、橡皮擦命中、笔锋算法和导出适配。
export interface InkPoint extends PagePoint {
  pressure?: number;
  timestamp?: number;
}

export interface InkStrokeStyle {
  color: string;
  width: number;
  alpha?: number;
}

export interface InkStroke {
  id: string;
  points: InkPoint[];
  style: InkStrokeStyle;
}

export interface InkAnnotation {
  id: string;
  pageIndex: number;
  strokes: InkStroke[];
  metadata?: AnnotationMetadata;
}
