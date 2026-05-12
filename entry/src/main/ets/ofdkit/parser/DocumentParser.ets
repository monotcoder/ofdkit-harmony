import { OFDPage, OFDPageRef, PageBox } from './types';

// 功能开头：解析 Document.xml 的页面列表，并从每页 Content.xml 读取 PhysicalBox。
// 未来计划：补充 PageArea 继承规则、TemplatePage、资源引用和更完整的 XML 命名空间处理。
export class DocumentParser {
  parse(documentXml: string, pageContents: Map<string, string>): OFDPage[] {
    const refs: OFDPageRef[] = this.parsePageRefs(documentXml);
    const pages: OFDPage[] = [];

    refs.forEach((ref: OFDPageRef, index: number) => {
      const contentXml: string | undefined = pageContents.get(ref.baseLoc);
      if (!contentXml) {
        throw new Error(`未找到页面内容文件：${ref.baseLoc}`);
      }

      pages.push({
        id: ref.id,
        pageIndex: index,
        physicalBox: this.parsePhysicalBox(contentXml)
      });
    });

    return pages;
  }

  parsePageRefs(documentXml: string): OFDPageRef[] {
    const refs: OFDPageRef[] = [];
    const pageRegExp: RegExp = /<ofd:Page\b([^>]*)\/>|<Page\b([^>]*)\/>/g;
    let match: RegExpExecArray | null = pageRegExp.exec(documentXml);

    while (match !== null) {
      const attrs: string = match[1] ? match[1] : match[2];
      refs.push({
        id: this.readAttribute(attrs, 'ID'),
        baseLoc: this.readAttribute(attrs, 'BaseLoc')
      });
      match = pageRegExp.exec(documentXml);
    }

    if (refs.length === 0) {
      throw new Error('Document.xml 中未找到页面列表');
    }

    return refs;
  }

  parsePhysicalBox(contentXml: string): PageBox {
    const boxText: string = this.readElementText(contentXml, 'PhysicalBox');
    const values: number[] = boxText.split(/\s+/)
      .filter((item: string) => item.length > 0)
      .map((item: string) => Number(item));

    if (values.length !== 4 || values.some((item: number) => Number.isNaN(item))) {
      throw new Error(`PhysicalBox 格式错误：${boxText}`);
    }

    return {
      x: values[0],
      y: values[1],
      width: values[2],
      height: values[3]
    };
  }

  private readAttribute(attrs: string, name: string): string {
    const attrRegExp: RegExp = new RegExp(`${name}\\s*=\\s*["']([^"']+)["']`);
    const match: RegExpExecArray | null = attrRegExp.exec(attrs);

    if (!match) {
      throw new Error(`缺少 ${name} 属性`);
    }

    return match[1];
  }

  private readElementText(xml: string, localName: string): string {
    const elementRegExp: RegExp = new RegExp(`<(?:ofd:)?${localName}\\b[^>]*>([\\s\\S]*?)<\\/(?:ofd:)?${localName}>`);
    const match: RegExpExecArray | null = elementRegExp.exec(xml);

    if (!match) {
      throw new Error(`未找到 ${localName} 节点`);
    }

    return match[1].trim();
  }
}
