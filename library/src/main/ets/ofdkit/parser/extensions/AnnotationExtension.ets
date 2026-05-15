// Annotations 注释加载扩展（用 DocumentExtension 接入，验证扩展点 API）。
//
// OFD 注释结构：
//   Document.xml: <Annotations>Annots.xml</Annotations>
//   Annots.xml:   <Annotations><Page PageID="x"><FileLoc>...</FileLoc></Page></Annotations>
//   Annot.xml:    <PageAnnot><Annot ID Type Subject><Appearance Boundary>...对象...</Appearance></Annot></PageAnnot>
//
// 策略：每页所有 Annot 的 Appearance 内对象合并为一个新 Layer 追加到 page.content.layers 末尾（注释覆盖在内容之上）。

import { DocumentExtension, DocumentExtensionContext } from '../OFDParser';
import { ContentParser } from '../ContentParser';
import { CompositeBlock, Layer, OFDPage, PageBox, PageObject } from '../types';
import { XmlNode, XmlParser } from '../../utils/XmlParser';
import { ParseHelpers } from '../ParseHelpers';

export class AnnotationExtension implements DocumentExtension {
  readonly name: string = 'annotations';
  private readonly contentParser: ContentParser = new ContentParser();

  async apply(context: DocumentExtensionContext): Promise<void> {
    const annotsLoc: string | undefined = XmlParser.childText(context.documentNode, 'Annotations');
    if (annotsLoc === undefined || annotsLoc.length === 0) {
      return;
    }

    const annotsXmlPath: string = context.fileAdapter.joinPath(
      context.extractDir,
      context.fileAdapter.joinPath(context.docBaseDir, annotsLoc)
    );
    const exists: boolean = await context.fileAdapter.exists(annotsXmlPath);
    if (!exists) {
      console.warn(`[ofdkit] Annotations 索引文件不存在：${annotsXmlPath}`);
      return;
    }

    const annotsXml: string = await context.fileAdapter.readText(annotsXmlPath);
    const annotsNode: XmlNode = XmlParser.parse(annotsXml);
    const annotsBaseDir: string = this.parentDir(annotsXmlPath);

    const pageEntries: XmlNode[] = XmlParser.findChildren(annotsNode, 'Page');
    for (let i: number = 0; i < pageEntries.length; i++) {
      const pageNode: XmlNode = pageEntries[i];
      const pageID: string | undefined = XmlParser.attr(pageNode, 'PageID');
      const fileLoc: string | undefined = XmlParser.childText(pageNode, 'FileLoc');
      if (pageID === undefined || fileLoc === undefined) {
        continue;
      }
      const target: OFDPage | undefined = context.pages.find((p: OFDPage) => p.id === pageID);
      if (target === undefined) {
        console.warn(`[ofdkit] 注释引用了不存在的 PageID=${pageID}`);
        continue;
      }
      await this.loadAnnotForPage(target, annotsBaseDir, fileLoc, context);
    }
  }

  private async loadAnnotForPage(
    page: OFDPage,
    annotsBaseDir: string,
    fileLoc: string,
    context: DocumentExtensionContext
  ): Promise<void> {
    const annotXmlPath: string = context.fileAdapter.joinPath(annotsBaseDir, fileLoc);
    const exists: boolean = await context.fileAdapter.exists(annotXmlPath);
    if (!exists) {
      console.warn(`[ofdkit] Annot 文件不存在：${annotXmlPath}`);
      return;
    }
    const xml: string = await context.fileAdapter.readText(annotXmlPath);
    const pageAnnotNode: XmlNode = XmlParser.parse(xml);

    const objects: PageObject[] = [];
    XmlParser.findChildren(pageAnnotNode, 'Annot').forEach((annot: XmlNode) => {
      const visible: string | undefined = XmlParser.attr(annot, 'Visible');
      if (visible !== undefined && visible.toLowerCase() === 'false') {
        return;
      }
      const appearance: XmlNode | undefined = XmlParser.findChild(annot, 'Appearance');
      if (appearance === undefined) {
        return;
      }
      const inner: PageObject[] = this.contentParser.parseObjects(appearance);
      if (inner.length === 0) {
        return;
      }
      // <Appearance Boundary="x y w h"> 是注释在页面坐标系的位置；内部对象 Boundary 是相对 Appearance 原点的局部坐标。
      // 包成 CompositeBlock 让渲染器 translate 到正确位置，否则印章/水印会塌到 (0,0)。
      const boundary: PageBox | undefined = ParseHelpers.optionalBox(XmlParser.attr(appearance, 'Boundary'));
      if (boundary !== undefined) {
        const block: CompositeBlock = { type: 'block', boundary, children: inner };
        objects.push(block);
      } else {
        inner.forEach((obj: PageObject) => objects.push(obj));
      }
    });

    if (objects.length === 0) {
      return;
    }
    if (page.content === undefined) {
      page.content = { layers: [] };
    }
    const annotLayer: Layer = {
      id: `annot_${page.id}`,
      type: 'Annot',
      objects
    };
    page.content.layers.push(annotLayer);
    console.info(`[ofdkit] 页面 ${page.pageIndex + 1} 追加注释层，对象数 ${objects.length}`);
  }

  private parentDir(path: string): string {
    const idx: number = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(0, idx) : '';
  }
}
