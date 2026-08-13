import { PagePoint } from '../core';
import { InkAnnotation, InkPoint, InkStroke } from './InkTypes';

// 功能开头：管理矢量批注集合，提供新增、撤销、清空和点击命中能力。
// 未来计划：加入持久化、局部擦除、空间索引和多用户合并冲突处理。
export class AnnotationStore {
  private annotations: InkAnnotation[] = [];

  addAnnotation(annotation: InkAnnotation): void {
    this.annotations.push(annotation);
  }

  addStroke(annotationId: string, stroke: InkStroke): boolean {
    const annotation: InkAnnotation | undefined = this.findById(annotationId);
    if (annotation === undefined) {
      return false;
    }
    annotation.strokes.push(stroke);
    return true;
  }

  all(): InkAnnotation[] {
    return this.annotations.slice();
  }

  annotationsForPage(pageIndex: number): InkAnnotation[] {
    return this.annotations.filter((annotation: InkAnnotation) => annotation.pageIndex === pageIndex);
  }

  clear(): void {
    this.annotations = [];
  }

  undoLast(): InkAnnotation | undefined {
    return this.annotations.pop();
  }

  hitTest(point: PagePoint, tolerance: number): InkAnnotation | undefined {
    const pageAnnotations: InkAnnotation[] = this.annotationsForPage(point.pageIndex);
    for (let i: number = pageAnnotations.length - 1; i >= 0; i--) {
      const annotation: InkAnnotation = pageAnnotations[i];
      if (this.hitAnnotation(annotation, point, tolerance)) {
        return annotation;
      }
    }
    return undefined;
  }

  private findById(id: string): InkAnnotation | undefined {
    return this.annotations.find((annotation: InkAnnotation) => annotation.id === id);
  }

  private hitAnnotation(annotation: InkAnnotation, point: PagePoint, tolerance: number): boolean {
    return annotation.strokes.some((stroke: InkStroke) => this.hitStroke(stroke, point, tolerance));
  }

  private hitStroke(stroke: InkStroke, point: PagePoint, tolerance: number): boolean {
    if (stroke.points.length === 0) {
      return false;
    }

    if (stroke.points.length === 1) {
      return this.distance(stroke.points[0], point) <= tolerance;
    }

    for (let i: number = 1; i < stroke.points.length; i++) {
      if (this.distanceToSegment(point, stroke.points[i - 1], stroke.points[i]) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  private distance(a: InkPoint | PagePoint, b: PagePoint): number {
    const dx: number = a.x - b.x;
    const dy: number = a.y - b.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private distanceToSegment(point: PagePoint, start: InkPoint, end: InkPoint): number {
    const dx: number = end.x - start.x;
    const dy: number = end.y - start.y;
    const lenSq: number = dx * dx + dy * dy;
    if (lenSq === 0) {
      return this.distance(start, point);
    }

    const rawT: number = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lenSq;
    const t: number = Math.max(0, Math.min(1, rawT));
    const projected: PagePoint = {
      pageIndex: point.pageIndex,
      x: start.x + t * dx,
      y: start.y + t * dy
    };
    return this.distance(projected, point);
  }
}
