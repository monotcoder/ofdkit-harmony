// 解析 Document.xml：拿到页面引用列表，并把每页的 Content.xml 交给 ContentParser。

import { OFDPage, OFDPageRef, PageBox, ParsedPage } from './types';
import { XmlNode, XmlParser } from '../utils/XmlParser';
import { ContentParser } from './ContentParser';
import { ParseHelpers } from './ParseHelpers';

export class DocumentParser {
  private readonly contentParser: ContentParser = new ContentParser();

  parse(documentXml: string, pageContents: Map<string, string>): OFDPage[] {
    const docNode: XmlNode = XmlParser.parse(documentXml);
    if (docNode.name !== 'Document') {
      throw new Error(`Document.xml 根节点应为 <Document>，实际：<${docNode.name}>`);
    }

    const fallbackBox: PageBox | undefined = this.parseDefaultPageBox(docNode);
    const refs: OFDPageRef[] = this.collectPageRefs(docNode);
    if (refs.length === 0) {
      throw new Error('Document.xml 中未找到页面列表');
    }

    const pages: OFDPage[] = [];
    refs.forEach((ref: OFDPageRef, index: number) => {
      const contentXml: string | undefined = pageContents.get(ref.baseLoc);
      if (contentXml === undefined) {
        throw new Error(`未找到页面内容文件：${ref.baseLoc}`);
      }

      try {
        const parsed: ParsedPage = this.contentParser.parsePage(contentXml);
        pages.push({
          id: ref.id,
          pageIndex: index,
          physicalBox: parsed.physicalBox,
          content: parsed.content
        });
      } catch (error) {
        console.warn(`[ofdkit] 解析页面 ${index + 1} 失败，降级：${error}`);
        if (fallbackBox === undefined) {
          throw new Error(`页面 ${index + 1} 解析失败且没有可用的默认 PhysicalBox`);
        }
        pages.push({
          id: ref.id,
          pageIndex: index,
          physicalBox: fallbackBox
        });
      }
    });

    return pages;
  }

  parsePageRefs(documentXml: string): OFDPageRef[] {
    const docNode: XmlNode = XmlParser.parse(documentXml);
    if (docNode.name !== 'Document') {
      throw new Error(`Document.xml 根节点应为 <Document>，实际：<${docNode.name}>`);
    }
    const refs: OFDPageRef[] = this.collectPageRefs(docNode);
    if (refs.length === 0) {
      throw new Error('Document.xml 中未找到页面列表');
    }
    return refs;
  }

  private collectPageRefs(docNode: XmlNode): OFDPageRef[] {
    const pagesNode: XmlNode | undefined = XmlParser.findChild(docNode, 'Pages');
    if (pagesNode === undefined) {
      return [];
    }
    const refs: OFDPageRef[] = [];
    XmlParser.findChildren(pagesNode, 'Page').forEach((pageNode: XmlNode) => {
      try {
        refs.push({
          id: XmlParser.requireAttr(pageNode, 'ID'),
          baseLoc: XmlParser.requireAttr(pageNode, 'BaseLoc')
        });
      } catch (error) {
        console.warn(`[ofdkit] 跳过非法 Page 引用：${error}`);
      }
    });
    return refs;
  }

  private parseDefaultPageBox(docNode: XmlNode): PageBox | undefined {
    const commonData: XmlNode | undefined = XmlParser.findChild(docNode, 'CommonData');
    if (commonData === undefined) {
      return undefined;
    }
    const pageArea: XmlNode | undefined = XmlParser.findChild(commonData, 'PageArea');
    if (pageArea === undefined) {
      return undefined;
    }
    const boxText: string | undefined = XmlParser.childText(pageArea, 'PhysicalBox');
    if (boxText === undefined) {
      return undefined;
    }
    try {
      return ParseHelpers.box(boxText);
    } catch (error) {
      console.warn(`[ofdkit] Document.xml 中 PhysicalBox 格式错误：${error}`);
      return undefined;
    }
  }
}
