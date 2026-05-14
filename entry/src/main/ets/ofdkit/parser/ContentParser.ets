// 解析单页 Content.xml：拿到 PhysicalBox + 图层下的页面对象。
// 按文档顺序遍历，支持 PageBlock 嵌套，保留对象 z-order。

import {
  PageContent,
  Layer,
  PageObject,
  TextObject,
  PathObject,
  ImageObject,
  CompositeBlock,
  TextCode,
  PageBox,
  ParsedPage
} from './types';
import { XmlNode, XmlParser } from '../utils/XmlParser';
import { ParseHelpers } from './ParseHelpers';

export class ContentParser {
  parsePage(contentXml: string): ParsedPage {
    const pageNode: XmlNode = XmlParser.parse(contentXml);
    if (pageNode.name !== 'Page') {
      throw new Error(`Content.xml 根节点应为 <Page>，实际：<${pageNode.name}>`);
    }
    return {
      physicalBox: this.parsePhysicalBox(pageNode),
      content: this.parseContent(pageNode)
    };
  }

  private parsePhysicalBox(pageNode: XmlNode): PageBox {
    const areaNode: XmlNode | undefined = XmlParser.findChild(pageNode, 'Area');
    if (areaNode === undefined) {
      throw new Error('Page 缺少 <Area>');
    }
    const boxText: string | undefined = XmlParser.childText(areaNode, 'PhysicalBox');
    if (boxText === undefined) {
      throw new Error('Page 缺少 <PhysicalBox>');
    }
    return ParseHelpers.box(boxText);
  }

  private parseContent(pageNode: XmlNode): PageContent {
    const contentNode: XmlNode | undefined = XmlParser.findChild(pageNode, 'Content');
    if (contentNode === undefined) {
      return { layers: [] };
    }
    const layers: Layer[] = [];
    XmlParser.findChildren(contentNode, 'Layer').forEach((layerNode: XmlNode) => {
      try {
        layers.push(this.parseLayer(layerNode));
      } catch (error) {
        console.warn(`[ofdkit] 解析图层失败：${error}`);
      }
    });
    return { layers };
  }

  private parseLayer(layerNode: XmlNode): Layer {
    return {
      id: XmlParser.attr(layerNode, 'ID'),
      type: XmlParser.attr(layerNode, 'Type'),
      drawParam: XmlParser.attr(layerNode, 'DrawParam'),
      objects: this.parseObjects(layerNode)
    };
  }

  private parseObjects(parent: XmlNode): PageObject[] {
    const objects: PageObject[] = [];
    parent.children.forEach((child: XmlNode) => {
      const obj: PageObject | undefined = this.parseObject(child);
      if (obj !== undefined) {
        objects.push(obj);
      }
    });
    return objects;
  }

  private parseObject(node: XmlNode): PageObject | undefined {
    switch (node.name) {
      case 'TextObject':
        return this.parseTextObject(node);
      case 'PathObject':
        return this.parsePathObject(node);
      case 'ImageObject':
        return this.parseImageObject(node);
      case 'PageBlock':
        return this.parsePageBlock(node);
      default:
        return undefined;
    }
  }

  private parseTextObject(node: XmlNode): TextObject | undefined {
    try {
      const result: TextObject = {
        type: 'text',
        id: XmlParser.requireAttr(node, 'ID'),
        boundary: ParseHelpers.box(XmlParser.requireAttr(node, 'Boundary')),
        font: XmlParser.requireAttr(node, 'Font'),
        size: ParseHelpers.number(XmlParser.requireAttr(node, 'Size')),
        ctm: ParseHelpers.optionalCTM(XmlParser.attr(node, 'CTM')),
        drawParam: XmlParser.attr(node, 'DrawParam'),
        stroke: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Stroke')),
        fill: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Fill')),
        hScale: ParseHelpers.optionalNumber(XmlParser.attr(node, 'HScale')),
        weight: ParseHelpers.optionalNumber(XmlParser.attr(node, 'Weight')),
        italic: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Italic')),
        fillColor: ParseHelpers.color(XmlParser.findChild(node, 'FillColor')),
        strokeColor: ParseHelpers.color(XmlParser.findChild(node, 'StrokeColor')),
        textCodes: this.parseTextCodes(node)
      };
      return result;
    } catch (error) {
      console.warn(`[ofdkit] 解析 TextObject 失败：${error}`);
      return undefined;
    }
  }

  private parseTextCodes(node: XmlNode): TextCode[] {
    const codes: TextCode[] = [];
    XmlParser.findChildren(node, 'TextCode').forEach((codeNode: XmlNode) => {
      codes.push({
        text: codeNode.text,
        x: ParseHelpers.optionalNumber(XmlParser.attr(codeNode, 'X')),
        y: ParseHelpers.optionalNumber(XmlParser.attr(codeNode, 'Y')),
        deltaX: ParseHelpers.optionalDeltaArray(XmlParser.attr(codeNode, 'DeltaX')),
        deltaY: ParseHelpers.optionalDeltaArray(XmlParser.attr(codeNode, 'DeltaY'))
      });
    });
    return codes;
  }

  private parsePathObject(node: XmlNode): PathObject | undefined {
    try {
      const result: PathObject = {
        type: 'path',
        id: XmlParser.requireAttr(node, 'ID'),
        boundary: ParseHelpers.box(XmlParser.requireAttr(node, 'Boundary')),
        ctm: ParseHelpers.optionalCTM(XmlParser.attr(node, 'CTM')),
        drawParam: XmlParser.attr(node, 'DrawParam'),
        abbreviatedData: XmlParser.childText(node, 'AbbreviatedData'),
        stroke: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Stroke')),
        fill: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Fill')),
        lineWidth: ParseHelpers.optionalNumber(XmlParser.attr(node, 'LineWidth')),
        fillColor: ParseHelpers.color(XmlParser.findChild(node, 'FillColor')),
        strokeColor: ParseHelpers.color(XmlParser.findChild(node, 'StrokeColor'))
      };
      return result;
    } catch (error) {
      console.warn(`[ofdkit] 解析 PathObject 失败：${error}`);
      return undefined;
    }
  }

  private parseImageObject(node: XmlNode): ImageObject | undefined {
    try {
      const result: ImageObject = {
        type: 'image',
        id: XmlParser.requireAttr(node, 'ID'),
        boundary: ParseHelpers.box(XmlParser.requireAttr(node, 'Boundary')),
        resourceID: XmlParser.requireAttr(node, 'ResourceID'),
        ctm: ParseHelpers.optionalCTM(XmlParser.attr(node, 'CTM')),
        drawParam: XmlParser.attr(node, 'DrawParam')
      };
      return result;
    } catch (error) {
      console.warn(`[ofdkit] 解析 ImageObject 失败：${error}`);
      return undefined;
    }
  }

  private parsePageBlock(node: XmlNode): CompositeBlock {
    return {
      type: 'block',
      id: XmlParser.attr(node, 'ID'),
      boundary: ParseHelpers.optionalBox(XmlParser.attr(node, 'Boundary')),
      ctm: ParseHelpers.optionalCTM(XmlParser.attr(node, 'CTM')),
      drawParam: XmlParser.attr(node, 'DrawParam'),
      children: this.parseObjects(node)
    };
  }
}
