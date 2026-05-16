// 跨页全文搜索控制器。
// 调用流程：
//   const ctrl = new SearchController();
//   ctrl.search('金额', doc.pages);              // 一次构建所有页索引并收集匹配
//   const cur = ctrl.next();                     // 跳到下一个 → { pageIndex, rect, ... }
//   const hits = ctrl.hitsForPage(pageIndex);    // 给该页 OFDPageView 渲染高亮
//
// 设计简化：search() 是同步遍历所有页，单文档 < 几十页时性能没问题。多页大文档（>100 页）
// 后续可改 async + 分批。

import { OFDPage } from '../parser/types';
import { SelectionRect } from '../renderer/OFDRenderer';
import { CharBoxIndex } from './CharBoxIndex';

export interface SearchMatch {
  pageIndex: number;
  rect: SelectionRect;
}

export class SearchController {
  matches: SearchMatch[] = [];
  activeIndex: number = -1;
  query: string = '';

  search(query: string, pages: OFDPage[]): void {
    this.query = query;
    this.matches = [];
    this.activeIndex = -1;
    if (query.length === 0) {
      return;
    }
    const idx: CharBoxIndex = new CharBoxIndex();
    for (let p: number = 0; p < pages.length; p++) {
      idx.build(pages[p]);
      const hits: SelectionRect[] = idx.search(query);
      for (let i: number = 0; i < hits.length; i++) {
        this.matches.push({ pageIndex: p, rect: hits[i] });
      }
    }
    if (this.matches.length > 0) {
      this.activeIndex = 0;
    }
  }

  next(): SearchMatch | undefined {
    if (this.matches.length === 0) {
      return undefined;
    }
    this.activeIndex = (this.activeIndex + 1) % this.matches.length;
    return this.matches[this.activeIndex];
  }

  prev(): SearchMatch | undefined {
    if (this.matches.length === 0) {
      return undefined;
    }
    this.activeIndex = (this.activeIndex - 1 + this.matches.length) % this.matches.length;
    return this.matches[this.activeIndex];
  }

  current(): SearchMatch | undefined {
    if (this.activeIndex < 0 || this.activeIndex >= this.matches.length) {
      return undefined;
    }
    return this.matches[this.activeIndex];
  }

  // 返回当前页所有命中矩形，active 命中标 search-active，其余 search-passive。
  hitsForPage(pageIndex: number): SelectionRect[] {
    const result: SelectionRect[] = [];
    for (let i: number = 0; i < this.matches.length; i++) {
      const m: SearchMatch = this.matches[i];
      if (m.pageIndex !== pageIndex) {
        continue;
      }
      const isActive: boolean = i === this.activeIndex;
      result.push({
        x: m.rect.x,
        y: m.rect.y,
        w: m.rect.w,
        h: m.rect.h,
        type: isActive ? 'search-active' : 'search-passive'
      });
    }
    return result;
  }

  clear(): void {
    this.matches = [];
    this.activeIndex = -1;
    this.query = '';
  }
}
