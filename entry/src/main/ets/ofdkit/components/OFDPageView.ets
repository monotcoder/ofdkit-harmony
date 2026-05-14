// OFD 单页 Canvas 渲染组件。
// Canvas 自适应父容器宽度，高度按 PhysicalBox 比例自动计算。
// 切换 @Prop page 时：预加载本页字体（注册到系统）+ 解码本页图片到 PixelMap，准备好后再渲染。

import { font } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
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
import { OFDRenderer, RenderResources } from '../renderer/OFDRenderer';

const registeredFontFamilies: Set<string> = new Set<string>();

@Component
export struct OFDPageView {
  @Prop @Watch('onPageChanged') page: OFDPage;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private renderer: OFDRenderer = new OFDRenderer();
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
    Column() {
      Canvas(this.context)
        .width('100%')
        .aspectRatio(this.aspectRatio())
        .backgroundColor('#FFFFFF')
        .onReady(() => {
          this.canvasReady = true;
          this.renderIfReady();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  private aspectRatio(): number {
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
    this.prepare();
  }

  private prepare(): void {
    this.preloadResources()
      .then(() => {
        this.resourcesReady = true;
        this.renderIfReady();
      })
      .catch((error: Error) => {
        console.error(`[ofdkit] 资源预加载失败：${error}`);
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
    if (fontDef === undefined || fontDef.fontFile === undefined) {
      return;
    }
    const family: string = `OFD_${fontId}`;
    if (!registeredFontFamilies.has(family)) {
      try {
        font.registerFont({ familyName: family, familySrc: fontDef.fontFile });
        registeredFontFamilies.add(family);
      } catch (error) {
        console.warn(`[ofdkit] 字体 ${fontDef.fontName} 注册失败：${error}`);
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
