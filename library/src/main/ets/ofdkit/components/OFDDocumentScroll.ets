// 多页连续滚动视图：纵向 List + 每页用 OFDPageView(embedded=true)。
// 用户单指上下滑动连续浏览整个文档；缩放/侧滑等手势在嵌入模式下禁用，避免跟 List 滚动冲突。
//
// 跳转：父级通过 @Prop scrollToIndex 触发（比如缩略图条点击、搜索跳页）；改变此值时
// 组件用 List.scrollToIndex 滚到对应页。
//
// 搜索高亮：父级提供 hitsByPage 函数，按页返回 SelectionRect[]，本组件透传给每页 OFDPageView。

import { OFDPage } from '../parser/types';
import { SelectionRect } from '../renderer/OFDRenderer';
import { OFDPageView } from './OFDPageView';

@Component
export struct OFDDocumentScroll {
  pages: OFDPage[] = [];
  // 父组件想跳到某页时改这个值，本组件 @Watch 之后调 list.scrollToIndex。
  @Prop @Watch('onScrollToIndexChanged') scrollToIndex: number = 0;
  // 按页提供搜索高亮矩形。没传或没该页 key 时给 OFDPageView 空数组。
  hitsByPage?: (pageIndex: number) => SelectionRect[];
  // 当前可见页变化时通知父（一般是最顶端 item）
  onVisiblePageChange?: (index: number) => void;

  private scroller: Scroller = new Scroller();

  build() {
    List({ space: 12, scroller: this.scroller }) {
      ForEach(this.pages, (page: OFDPage, index: number) => {
        ListItem() {
          OFDPageView({
            page,
            searchHits: this.hitsByPage !== undefined ? this.hitsByPage(index) : [],
            embedded: true
          })
        }
      }, (page: OFDPage, index: number) => `scroll_${page.id}_${index}`)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor('#EEEEEE')
    .onScrollIndex((first: number) => {
      if (this.onVisiblePageChange !== undefined) {
        this.onVisiblePageChange(first);
      }
    })
  }

  private onScrollToIndexChanged(): void {
    if (this.scrollToIndex >= 0 && this.scrollToIndex < this.pages.length) {
      this.scroller.scrollToIndex(this.scrollToIndex, true);
    }
  }
}
