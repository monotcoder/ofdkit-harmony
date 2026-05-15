// 解析 PublicRes.xml / DocumentRes.xml：拿到 Fonts / MultiMedias / DrawParams 索引。
// Res XML 根节点 <Res BaseLoc="...">，所有 FontFile/MediaFile 相对该 BaseLoc。

import {
  OFDResources,
  OFDFont,
  OFDMultiMedia,
  OFDDrawParam,
  OFDFileAdapter
} from './types';
import { XmlNode, XmlParser } from '../utils/XmlParser';
import { ParseHelpers } from './ParseHelpers';

export class ResourceParser {
  static empty(): OFDResources {
    return {
      fonts: new Map<string, OFDFont>(),
      multiMedias: new Map<string, OFDMultiMedia>(),
      drawParams: new Map<string, OFDDrawParam>()
    };
  }

  static merge(target: OFDResources, source: OFDResources): void {
    source.fonts.forEach((value: OFDFont, key: string) => target.fonts.set(key, value));
    source.multiMedias.forEach((value: OFDMultiMedia, key: string) => target.multiMedias.set(key, value));
    source.drawParams.forEach((value: OFDDrawParam, key: string) => target.drawParams.set(key, value));
  }

  // resXmlDir：res 文件所在目录的绝对路径。
  // fileAdapter：用于路径拼接。
  static parse(resXml: string, resXmlDir: string, fileAdapter: OFDFileAdapter): OFDResources {
    const root: XmlNode = XmlParser.parse(resXml);
    if (root.name !== 'Res') {
      throw new Error(`Res 文件根节点应为 <Res>，实际：<${root.name}>`);
    }
    const baseLoc: string = XmlParser.attr(root, 'BaseLoc') ?? '';
    const resourceBaseDir: string = baseLoc.length > 0 ? fileAdapter.joinPath(resXmlDir, baseLoc) : resXmlDir;

    const result: OFDResources = ResourceParser.empty();
    root.children.forEach((section: XmlNode) => {
      if (section.name === 'Fonts') {
        ResourceParser.parseFonts(section, resourceBaseDir, fileAdapter, result.fonts);
      } else if (section.name === 'MultiMedias') {
        ResourceParser.parseMultiMedias(section, resourceBaseDir, fileAdapter, result.multiMedias);
      } else if (section.name === 'DrawParams') {
        ResourceParser.parseDrawParams(section, result.drawParams);
      }
    });
    return result;
  }

  private static parseFonts(
    section: XmlNode,
    baseDir: string,
    fileAdapter: OFDFileAdapter,
    out: Map<string, OFDFont>
  ): void {
    XmlParser.findChildren(section, 'Font').forEach((node: XmlNode) => {
      try {
        const id: string = XmlParser.requireAttr(node, 'ID');
        const fontFileRel: string | undefined = XmlParser.childText(node, 'FontFile');
        const font: OFDFont = {
          id,
          fontName: XmlParser.attr(node, 'FontName') ?? '',
          familyName: XmlParser.attr(node, 'FamilyName'),
          charset: XmlParser.attr(node, 'Charset'),
          serif: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Serif')),
          bold: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Bold')),
          italic: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'Italic')),
          fixedWidth: ParseHelpers.optionalBoolean(XmlParser.attr(node, 'FixedWidth')),
          fontFile: fontFileRel !== undefined ? fileAdapter.joinPath(baseDir, fontFileRel) : undefined
        };
        out.set(id, font);
      } catch (error) {
        console.warn(`[ofdkit] 解析 Font 失败：${error}`);
      }
    });
  }

  private static parseMultiMedias(
    section: XmlNode,
    baseDir: string,
    fileAdapter: OFDFileAdapter,
    out: Map<string, OFDMultiMedia>
  ): void {
    XmlParser.findChildren(section, 'MultiMedia').forEach((node: XmlNode) => {
      try {
        const id: string = XmlParser.requireAttr(node, 'ID');
        const mediaFileRel: string | undefined = XmlParser.childText(node, 'MediaFile');
        if (mediaFileRel === undefined) {
          throw new Error('MultiMedia 缺少 <MediaFile>');
        }
        const media: OFDMultiMedia = {
          id,
          type: XmlParser.attr(node, 'Type') ?? 'Image',
          format: XmlParser.attr(node, 'Format'),
          mediaFile: fileAdapter.joinPath(baseDir, mediaFileRel)
        };
        out.set(id, media);
      } catch (error) {
        console.warn(`[ofdkit] 解析 MultiMedia 失败：${error}`);
      }
    });
  }

  private static parseDrawParams(section: XmlNode, out: Map<string, OFDDrawParam>): void {
    XmlParser.findChildren(section, 'DrawParam').forEach((node: XmlNode) => {
      try {
        const id: string = XmlParser.requireAttr(node, 'ID');
        const dp: OFDDrawParam = {
          id,
          relative: XmlParser.attr(node, 'Relative'),
          lineWidth: ParseHelpers.optionalNumber(XmlParser.attr(node, 'LineWidth')),
          join: XmlParser.attr(node, 'Join'),
          cap: XmlParser.attr(node, 'Cap'),
          miterLimit: ParseHelpers.optionalNumber(XmlParser.attr(node, 'MiterLimit')),
          dashOffset: ParseHelpers.optionalNumber(XmlParser.attr(node, 'DashOffset')),
          dashPattern: ParseHelpers.optionalNumberArray(XmlParser.attr(node, 'DashPattern')),
          strokeColor: ParseHelpers.color(XmlParser.findChild(node, 'StrokeColor')),
          fillColor: ParseHelpers.color(XmlParser.findChild(node, 'FillColor'))
        };
        out.set(id, dp);
      } catch (error) {
        console.warn(`[ofdkit] 解析 DrawParam 失败：${error}`);
      }
    });
  }

  // 把 DrawParam 沿着 Relative 链合并，自身属性覆盖继承属性。
  static resolveDrawParam(id: string, all: Map<string, OFDDrawParam>): OFDDrawParam | undefined {
    return ResourceParser.resolveDrawParamWithGuard(id, all, new Set<string>());
  }

  private static resolveDrawParamWithGuard(
    id: string,
    all: Map<string, OFDDrawParam>,
    visited: Set<string>
  ): OFDDrawParam | undefined {
    if (visited.has(id)) {
      console.warn(`[ofdkit] DrawParam ${id} 存在循环引用`);
      return all.get(id);
    }
    const self: OFDDrawParam | undefined = all.get(id);
    if (self === undefined) {
      return undefined;
    }
    if (self.relative === undefined) {
      return self;
    }
    visited.add(id);
    const base: OFDDrawParam | undefined = ResourceParser.resolveDrawParamWithGuard(self.relative, all, visited);
    if (base === undefined) {
      return self;
    }
    return {
      id: self.id,
      relative: self.relative,
      lineWidth: self.lineWidth ?? base.lineWidth,
      join: self.join ?? base.join,
      cap: self.cap ?? base.cap,
      miterLimit: self.miterLimit ?? base.miterLimit,
      dashOffset: self.dashOffset ?? base.dashOffset,
      dashPattern: self.dashPattern ?? base.dashPattern,
      strokeColor: self.strokeColor ?? base.strokeColor,
      fillColor: self.fillColor ?? base.fillColor
    };
  }
}
