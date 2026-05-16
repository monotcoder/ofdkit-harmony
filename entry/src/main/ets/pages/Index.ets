import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import {
  OFDDocument,
  OFDPage,
  OFDParser,
  PageContent,
  Layer,
  FileUtils,
  OFDPageView,
  OFDThumbnailStrip,
  OFDSearchBar,
  OFDDocumentScroll,
  SearchController,
  SearchMatch,
  SelectionRect,
  installDefaultExtensions
} from 'ofdkit-harmony';

@Entry
@Component
struct Index {
  @State message: string = '请选择一个 OFD 文件';
  @State errorMessage: string = '';
  @State documentInfo: OFDDocument | undefined = undefined;
  @State @Watch('onPageIndexChanged') selectedPageIndex: number = 0;
  @State showPreview: boolean = false;
  @State searchOpen: boolean = false;
  @State searchQuery: string = '';
  @State searchActiveIndex: number = -1;
  @State searchTotalMatches: number = 0;
  @State currentPageSearchHits: SelectionRect[] = [];
  @State continuousMode: boolean = false;
  // 连续滚动里跳页的触发——值变化时 OFDDocumentScroll @Watch 触发 scrollToIndex。
  @State scrollJumpIndex: number = 0;
  private searchCtrl: SearchController = new SearchController();

  aboutToAppear(): void {
    installDefaultExtensions();
  }

  private onPageIndexChanged(): void {
    // 切页时刷新当前页的搜索高亮（active 也可能跟着跳）
    this.currentPageSearchHits = this.searchCtrl.hitsForPage(this.selectedPageIndex);
  }

  private doSearch(q: string): void {
    if (this.documentInfo === undefined) {
      return;
    }
    this.searchQuery = q;
    this.searchCtrl.search(q, this.documentInfo.pages);
    this.searchTotalMatches = this.searchCtrl.matches.length;
    this.searchActiveIndex = this.searchCtrl.activeIndex;
    this.jumpToActiveMatch();
  }

  private jumpToActiveMatch(): void {
    const cur: SearchMatch | undefined = this.searchCtrl.current();
    if (cur === undefined) {
      this.currentPageSearchHits = [];
      return;
    }
    if (this.selectedPageIndex !== cur.pageIndex) {
      this.selectedPageIndex = cur.pageIndex;  // 触发 onPageIndexChanged → 刷新 hits
    } else {
      this.currentPageSearchHits = this.searchCtrl.hitsForPage(this.selectedPageIndex);
    }
    // 连续模式下也滚到对应页（即使 selectedPageIndex 没变，也强制重新触发）
    if (this.continuousMode) {
      this.scrollJumpIndex = cur.pageIndex;
    }
  }

  // 给 OFDDocumentScroll 按页提供搜索高亮——返回闭包，连续模式下每个 ListItem 调一次
  private hitsForPageProvider(): (pageIndex: number) => SelectionRect[] {
    const ctrl: SearchController = this.searchCtrl;
    return (pageIndex: number): SelectionRect[] => ctrl.hitsForPage(pageIndex);
  }

  private searchNext(): void {
    this.searchCtrl.next();
    this.searchActiveIndex = this.searchCtrl.activeIndex;
    this.jumpToActiveMatch();
  }

  private searchPrev(): void {
    this.searchCtrl.prev();
    this.searchActiveIndex = this.searchCtrl.activeIndex;
    this.jumpToActiveMatch();
  }

  private closeSearch(): void {
    this.searchOpen = false;
    this.searchCtrl.clear();
    this.searchQuery = '';
    this.searchActiveIndex = -1;
    this.searchTotalMatches = 0;
    this.currentPageSearchHits = [];
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Button('选择 OFD 文件')
          .onClick(() => {
            this.pickOFDFile();
          })

        Text(this.message)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor(Color.Red)
        }

        if (this.documentInfo !== undefined) {
          this.renderDocumentInfo()
        }

        if (this.showPreview && this.documentInfo !== undefined) {
          this.renderPagePreview()
        }
      }
      .width('100%')
      .padding(24)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private renderDocumentInfo(): void {
    Column({ space: 12 }) {
      Text(`版本号：${this.documentInfo!.version}`)
        .fontSize(14)
      Text(`文档类型：${this.documentInfo!.docType}`)
        .fontSize(14)
      Text(`总页数：${this.documentInfo!.pages.length}`)
        .fontSize(14)

      Button(this.showPreview ? '隐藏预览' : '显示预览')
        .onClick(() => {
          this.showPreview = !this.showPreview;
        })

      ForEach(this.documentInfo!.pages, (page: OFDPage) => {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text(`第 ${page.pageIndex + 1} 页：${page.physicalBox.width} × ${page.physicalBox.height} mm`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)

            if (this.showPreview) {
              Button('预览')
                .fontSize(12)
                .height(28)
                .onClick(() => {
                  this.selectedPageIndex = page.pageIndex;
                })
            }
          }
          .width('100%')

          if (page.content !== undefined) {
            this.renderPageContent(page.content)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, top: 8, bottom: 8 })
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
      }, (page: OFDPage) => page.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private renderPagePreview(): void {
    Column({ space: 8 }) {
      Text(`预览第 ${this.selectedPageIndex + 1} 页`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)

      // 顶部工具栏：搜索栏 / 搜索按钮 + 视图模式切换
      Row({ space: 8 }) {
        if (this.searchOpen) {
          OFDSearchBar({
            query: this.searchQuery,
            activeIndex: this.searchActiveIndex,
            totalMatches: this.searchTotalMatches,
            onQuerySubmit: (q: string) => this.doSearch(q),
            onPrev: () => this.searchPrev(),
            onNext: () => this.searchNext(),
            onClose: () => this.closeSearch()
          })
        } else {
          Button('搜索')
            .fontSize(14)
            .onClick(() => {
              this.searchOpen = true;
            })
          if (this.documentInfo!.pages.length > 1) {
            Button(this.continuousMode ? '单页模式' : '连续滚动')
              .fontSize(14)
              .onClick(() => {
                this.continuousMode = !this.continuousMode;
                if (this.continuousMode) {
                  this.scrollJumpIndex = this.selectedPageIndex;
                }
              })
          }
        }
      }
      .width('100%')

      if (this.continuousMode) {
        // 连续滚动模式：纵向 List 一口气看所有页
        Column() {
          OFDDocumentScroll({
            pages: this.documentInfo!.pages,
            scrollToIndex: this.scrollJumpIndex,
            hitsByPage: this.hitsForPageProvider(),
            onVisiblePageChange: (index: number) => {
              this.selectedPageIndex = index;
            }
          })
        }
        .height(600)
        .width('100%')
      } else if (this.selectedPageIndex < this.documentInfo!.pages.length) {
        // 单页模式：保留侧滑、缩放、长按选中、缩略图条
        OFDPageView({
          page: this.documentInfo!.pages[this.selectedPageIndex],
          searchHits: this.currentPageSearchHits,
          onSwipeNext: () => {
            if (this.selectedPageIndex < this.documentInfo!.pages.length - 1) {
              this.selectedPageIndex++;
            }
          },
          onSwipePrev: () => {
            if (this.selectedPageIndex > 0) {
              this.selectedPageIndex--;
            }
          }
        })

        if (this.documentInfo!.pages.length > 1) {
          OFDThumbnailStrip({
            pages: this.documentInfo!.pages,
            currentIndex: this.selectedPageIndex,
            onPageSelect: (index: number) => {
              this.selectedPageIndex = index;
            }
          })
        }
      }

      Row({ space: 8 }) {
        Button('上一页')
          .enabled(this.selectedPageIndex > 0)
          .onClick(() => {
            if (this.selectedPageIndex > 0) {
              this.selectedPageIndex--;
            }
          })

        Button('下一页')
          .enabled(this.selectedPageIndex < this.documentInfo!.pages.length - 1)
          .onClick(() => {
            if (this.selectedPageIndex < this.documentInfo!.pages.length - 1) {
              this.selectedPageIndex++;
            }
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#EEEEEE')
    .borderRadius(8)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private renderPageContent(content: PageContent): void {
    Column({ space: 4 }) {
      Text(`图层数：${content.layers.length}`)
        .fontSize(12)
        .fontColor('#666666')

      ForEach(content.layers, (layer: Layer, layerIndex: number) => {
        this.renderLayerInfo(layer, layerIndex)
      }, (layer: Layer, index: number) => `layer_${index}`)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private renderLayerInfo(layer: Layer, layerIndex: number): void {
    Column({ space: 2 }) {
      Text(`图层 ${layerIndex + 1}：${layer.objects.length} 个对象`)
        .fontSize(12)
        .fontColor('#888888')

      this.renderObjectCounts(layer)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private renderObjectCounts(layer: Layer): void {
    if (this.getTextCount(layer) > 0) {
      Text(`  - 文字对象：${this.getTextCount(layer)}`)
        .fontSize(11)
        .fontColor('#999999')
    }
    if (this.getPathCount(layer) > 0) {
      Text(`  - 路径对象：${this.getPathCount(layer)}`)
        .fontSize(11)
        .fontColor('#999999')
    }
    if (this.getImageCount(layer) > 0) {
      Text(`  - 图片对象：${this.getImageCount(layer)}`)
        .fontSize(11)
        .fontColor('#999999')
    }
  }

  private getTextCount(layer: Layer): number {
    return layer.objects.filter(obj => obj.type === 'text').length;
  }

  private getPathCount(layer: Layer): number {
    return layer.objects.filter(obj => obj.type === 'path').length;
  }

  private getImageCount(layer: Layer): number {
    return layer.objects.filter(obj => obj.type === 'image').length;
  }

  private async pickOFDFile(): Promise<void> {
    this.errorMessage = '';
    this.documentInfo = undefined;

    try {
      const context: common.UIAbilityContext = this.getAbilityContext();
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const selectedUris: Array<string> = await documentPicker.select({
        fileSuffixFilters: ['OFD 文档|.ofd'],
        maxSelectNumber: 1
      });

      if (selectedUris.length === 0) {
        this.message = '未选择文件';
        return;
      }

      const localPath: string = await this.copyPickedFileToCache(selectedUris[0], context.cacheDir);
      await this.parseOFDFile(localPath, context.cacheDir);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '选择 OFD 文件失败';
      this.errorMessage = message;
      console.error(`[ofdkit] ${message}`);
    }
  }

  private async parseOFDFile(ofdPath: string, cacheDir: string): Promise<void> {
    const parser: OFDParser = new OFDParser({
      workDir: `${cacheDir}/ofdkit/extract`
    });
    const document: OFDDocument = await parser.parse(ofdPath);
    this.documentInfo = document;
    this.message = `解析完成：${ofdPath}`;
  }

  private getAbilityContext(): common.UIAbilityContext {
    const context: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!context) {
      throw new Error('获取 UIAbilityContext 失败');
    }
    return context;
  }

  private async copyPickedFileToCache(uri: string, cacheDir: string): Promise<string> {
    const fileUtils: FileUtils = new FileUtils();
    const targetDir: string = `${cacheDir}/ofdkit/source`;
    await fileUtils.ensureDir(targetDir);

    const targetPath: string = `${targetDir}/picked_${Date.now()}.ofd`;
    try {
      await fileUtils.copyFile(uri, targetPath);
      console.info(`[ofdkit] 已复制选择文件：${uri} -> ${targetPath}`);
      return targetPath;
    } catch (error) {
      throw new Error('复制所选 OFD 文件到应用缓存失败');
    }
  }
}
