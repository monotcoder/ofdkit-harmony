// 横向滚动的多页缩略图条。每个缩略图复用 OFDPageView 的 thumbnailMode（无手势、纯渲染）。
// 点击缩略图触发 onPageSelect(index)；当前页用蓝色描边高亮。
//
// 注意性能：每个缩略图都是独立 OFDPageView 实例，会加载本页字体/图片到内存。
// 大文档（>20 页）可能有内存压力，调用方按需控制是否显示缩略图条。

import { OFDPage } from '../parser/types';
import { OFDPageView } from './OFDPageView';

@Component
export struct OFDThumbnailStrip {
  pages: OFDPage[] = [];
  @Prop currentIndex: number = 0;
  // 每个缩略图的宽度（vp）。高度按 page.physicalBox 比例自动算。
  thumbnailWidth: number = 80;
  // 缩略图条整体高度（vp）。默认按一个常见 A4 横向（80×56）+ 边距 + 页码估算。
  stripHeight: number = 110;
  onPageSelect?: (index: number) => void;

  build() {
    Scroll() {
      Row({ space: 12 }) {
        ForEach(this.pages, (page: OFDPage, index: number) => {
          Column({ space: 4 }) {
            // 缩略图本体：用 OFDPageView 的 thumbnailMode，外层加 border 标识选中状态
            Column() {
              OFDPageView({ page, thumbnailMode: true })
            }
            .width(this.thumbnailWidth)
            .aspectRatio(this.pageAspect(page))
            .border({
              width: this.currentIndex === index ? 2 : 1,
              color: this.currentIndex === index ? '#2196F3' : '#CCCCCC',
              radius: 4
            })
            .clip(true)

            Text(`${index + 1}`)
              .fontSize(11)
              .fontColor(this.currentIndex === index ? '#2196F3' : '#666666')
              .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
          }
          .onClick(() => {
            if (this.onPageSelect !== undefined) {
              this.onPageSelect(index);
            }
          })
        }, (page: OFDPage, index: number) => `thumb_${page.id}_${index}`)
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .height(this.stripHeight)
    .width('100%')
    .backgroundColor('#F5F5F5')
  }

  private pageAspect(page: OFDPage): number {
    const w: number = page.physicalBox.width;
    const h: number = page.physicalBox.height;
    if (w <= 0 || h <= 0) {
      return 0.707;
    }
    return w / h;
  }
}
