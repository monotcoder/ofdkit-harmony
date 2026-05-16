// OFD 单页 Canvas 渲染组件。
// Canvas 自适应父容器宽度，高度按 PhysicalBox 比例自动计算。
// 切换 @Prop page 时：预加载本页字体（注册到系统）+ 解码本页图片到 PixelMap，准备好后再渲染。
// 手势：双指捏合缩放（0.5x~5x）、单指拖动平移、双击复位、长按选中文字。视觉级 transform，不重渲染 Canvas。

import { image } from '@kit.ImageKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  OFDPage,
  PageObject,
  TextObject,
  ImageObject,
  CompositeBlock,
  Layer,
  OFDFont,
  OFDMultiMedia
} from '../parser/types';
import { OFDRenderer, RenderResources, SelectionRect } from '../renderer/OFDRenderer';
import { CharBoxIndex, TextSegment } from './CharBoxIndex';

const registeredFontFamilies: Set<string> = new Set<string>();
const MIN_SCALE: number = 0.5;
const MAX_SCALE: number = 5.0;

@Component
export struct OFDPageView {
  @Prop @Watch('onPageChanged') page: OFDPage;
  @State private scaleVal: number = 1.0;
  @State private offsetX: number = 0;
  @State private offsetY: number = 0;
  @State private selectMode: boolean = false;
  @State private selectedTextLength: number = 0;
  private selectedText: string = '';
  private baseScale: number = 1.0;
  private baseOffsetX: number = 0;
  private baseOffsetY: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private renderer: OFDRenderer = new OFDRenderer();
  private charIndex: CharBoxIndex = new CharBoxIndex();
  private pixelMaps: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private fontFamilies: Map<string, string> = new Map<string, string>();
  private canvasReady: boolean = false;
  private resourcesReady: boolean = false;

  aboutToAppear(): void {
    this.prepare();
  }

  aboutToDisappear(): void {
    this.releasePixelMaps();
  }

  build() {
    Stack() {
      Canvas(this.context)
        .width('100%')
        .aspectRatio(this.pageAspect())
        .backgroundColor('#FFFFFF')
        .scale({ x: this.scaleVal, y: this.scaleVal })
        .translate({ x: this.offsetX, y: this.offsetY })
        .onReady(() => {
          this.canvasReady = true;
          this.renderIfReady();
        })

      // 选中态：浮动复制按钮（位于页面顶部居中）
      if (this.selectMode) {
        Row() {
          Text(`复制 ${this.selectedTextLength} 字符`)
            .fontSize(14)
            .fontColor('#FFFFFF')
          Text('  ✕')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .opacity(0.7)
            .onClick(() => this.clearSelection())
        }
        .padding({ left: 16, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#2196F3')
        .borderRadius(20)
        .shadow({ radius: 8, color: '#33000000', offsetY: 2 })
        .position({ top: 16 })
        .zIndex(10)
        .onClick(() => this.copySelection())
      }
    }
    .width('100%')
    .clip(true)
    .alignContent(Alignment.Top)
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.baseScale = this.scaleVal;
          })
          .onActionUpdate((event: GestureEvent) => {
            const target: number = this.baseScale * event.scale;
            this.scaleVal = Math.max(MIN_SCALE, Math.min(MAX_SCALE, target));
          }),
        PanGesture()
          .onActionStart(() => {
            this.baseOffsetX = this.offsetX;
            this.baseOffsetY = this.offsetY;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.offsetX = this.baseOffsetX + event.offsetX;
            this.offsetY = this.baseOffsetY + event.offsetY;
          }),
        TapGesture({ count: 2 })
          .onAction(() => {
            this.resetTransform();
          }),
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction((event: GestureEvent) => {
            this.handleLongPress(event);
          })
      )
    )
  }

  private handleLongPress(event: GestureEvent): void {
    if (event.fingerList.length === 0) {
      return;
    }
    const finger = event.fingerList[0];
    if (finger === undefined) {
      return;
    }
    // localX/localY 是 vp 单位，是相对组件 layout 的坐标（已反算 scale/translate 变换）
    const localPxX: number = vp2px(finger.localX);
    const localPxY: number = vp2px(finger.localY);
    if (this.context.width <= 0 || this.context.height <= 0) {
      return;
    }
    const ofdX: number = localPxX / this.context.width * this.page.physicalBox.width;
    const ofdY: number = localPxY / this.context.height * this.page.physicalBox.height;

    const hitId: string | undefined = this.charIndex.hitText(ofdX, ofdY);
    if (hitId === undefined) {
      // 长按到空白处：取消选区
      if (this.selectMode) {
        this.clearSelection();
      }
      return;
    }
    const seg: TextSegment | undefined = this.charIndex.getSegment(hitId);
    if (seg === undefined) {
      return;
    }
    this.selectedText = seg.text;
    this.selectedTextLength = seg.text.length;
    this.selectMode = true;
    const rect: SelectionRect = { x: seg.boundaryX, y: seg.boundaryY, w: seg.boundaryW, h: seg.boundaryH };
    this.renderer.setSelectionRects([rect]);
    this.renderIfReady();
  }

  private clearSelection(): void {
    this.selectMode = false;
    this.selectedText = '';
    this.selectedTextLength = 0;
    this.renderer.setSelectionRects([]);
    this.renderIfReady();
  }

  private copySelection(): void {
    const text: string = this.selectedText;
    if (text.length === 0) {
      this.clearSelection();
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        promptAction.showToast({ message: `已复制 ${text.length} 字符`, duration: 1500 });
      })
      .catch((error: Error) => {
        console.warn(`[ofdkit] 复制失败：${error.message}`);
        promptAction.showToast({ message: '复制失败', duration: 1500 });
      });
    this.clearSelection();
  }

  private resetTransform(): void {
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
      this.scaleVal = 1.0;
      this.offsetX = 0;
      this.offsetY = 0;
    });
  }

  private pageAspect(): number {
    const w: number = this.page.physicalBox.width;
    const h: number = this.page.physicalBox.height;
    if (w <= 0 || h <= 0) {
      return 0.707;
    }
    return w / h;
  }

  private onPageChanged(): void {
    this.resourcesReady = false;
    this.releasePixelMaps();
    this.fontFamilies = new Map<string, string>();
    this.clearSelection();
    this.prepare();
  }

  private prepare(): void {
    this.preloadResources()
      .then(() => {
        this.charIndex.build(this.page);
        this.resourcesReady = true;
        this.renderIfReady();
      })
      .catch((error: Error) => {
        console.error(`[ofdkit] 资源预加载失败：${error}`);
        this.charIndex.build(this.page);
        this.resourcesReady = true;
        this.renderIfReady();
      });
  }

  private renderIfReady(): void {
    if (!this.canvasReady || !this.resourcesReady) {
      return;
    }
    if (this.page.resources !== undefined) {
      const render: RenderResources = {
        resources: this.page.resources,
        pixelMaps: this.pixelMaps,
        fontFamilies: this.fontFamilies
      };
      this.renderer.setResources(render);
    } else {
      this.renderer.setResources(undefined);
    }
    try {
      this.renderer.renderPage(this.page, this.context);
    } catch (error) {
      console.error(`[ofdkit] 渲染页面失败：${error}`);
    }
  }

  private async preloadResources(): Promise<void> {
    if (this.page.resources === undefined || this.page.content === undefined) {
      return;
    }
    const usedFonts: Set<string> = new Set<string>();
    const usedImages: Set<string> = new Set<string>();
    this.page.content.layers.forEach((layer: Layer) => {
      collectUsedRefs(layer.objects, usedFonts, usedImages);
    });

    usedFonts.forEach((fontId: string) => this.registerFontIfNeeded(fontId));
    const imageIds: string[] = Array.from(usedImages);
    for (let i: number = 0; i < imageIds.length; i++) {
      await this.decodeImage(imageIds[i]);
    }
  }

  private registerFontIfNeeded(fontId: string): void {
    const fontDef: OFDFont | undefined = this.page.resources?.fonts.get(fontId);
    if (fontDef === undefined) {
      console.info(`[ofdkit] 字体 ${fontId} 未在 Res 中定义，将退回 sans-serif`);
      return;
    }
    if (fontDef.fontFile === undefined) {
      console.info(`[ofdkit] 字体 ${fontId}(${fontDef.fontName}) 无嵌入 FontFile，将退回 sans-serif`);
      return;
    }
    const family: string = `OFD_${fontId}`;
    // HarmonyOS Font.registerFont 默认把 familySrc 当 rawfile 资源路径；要从沙箱绝对路径加载需要 file:// 前缀。
    const familySrc: string = fontDef.fontFile.startsWith('file://') ? fontDef.fontFile : `file://${fontDef.fontFile}`;
    if (!registeredFontFamilies.has(family)) {
      try {
        this.getUIContext().getFont().registerFont({ familyName: family, familySrc });
        registeredFontFamilies.add(family);
        console.info(`[ofdkit] 字体注册成功：${family} ← ${familySrc}`);
      } catch (error) {
        const msg: string = error instanceof Error ? error.message : String(error);
        console.warn(`[ofdkit] 字体注册失败 ${family} src=${familySrc}：${msg}`);
        return;
      }
    }
    this.fontFamilies.set(fontId, family);
  }

  private async decodeImage(imageId: string): Promise<void> {
    const media: OFDMultiMedia | undefined = this.page.resources?.multiMedias.get(imageId);
    if (media === undefined) {
      return;
    }
    try {
      const source: image.ImageSource = image.createImageSource(media.mediaFile);
      const pixelMap: image.PixelMap = await source.createPixelMap();
      this.pixelMaps.set(imageId, pixelMap);
      source.release();
    } catch (error) {
      console.warn(`[ofdkit] 图片 ${imageId}（${media.mediaFile}）解码失败：${error}`);
    }
  }

  private releasePixelMaps(): void {
    this.pixelMaps.forEach((pm: image.PixelMap) => {
      pm.release().catch((error: Error) => {
        console.warn(`[ofdkit] PixelMap 释放失败：${error}`);
      });
    });
    this.pixelMaps = new Map<string, image.PixelMap>();
  }
}

function collectUsedRefs(objects: PageObject[], fonts: Set<string>, images: Set<string>): void {
  objects.forEach((obj: PageObject) => {
    if (obj.type === 'text') {
      fonts.add((obj as TextObject).font);
    } else if (obj.type === 'image') {
      images.add((obj as ImageObject).resourceID);
    } else if (obj.type === 'block') {
      collectUsedRefs((obj as CompositeBlock).children, fonts, images);
    }
  });
}
