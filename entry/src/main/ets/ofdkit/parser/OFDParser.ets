// OFD 包入口：负责解压、读 OFD.xml、读 Document.xml、读资源 XML、按页读 Content.xml，最后组装 OFDDocument。

import { DocumentParser } from './DocumentParser';
import { ResourceParser } from './ResourceParser';
import {
  OFDDocument,
  OFDFileAdapter,
  OFDPackageEntry,
  OFDPage,
  OFDPageRef,
  OFDParserOptions,
  OFDResources,
  OFDZipAdapter
} from './types';
import { XmlNode, XmlParser } from '../utils/XmlParser';
import { FileUtils } from '../utils/FileUtils';
import { ZipUtils } from '../utils/ZipUtils';

// 文档级扩展点上下文：扩展可以读已解析的 Document.xml、修改 pages（追加 layer/对象）。
export interface DocumentExtensionContext {
  extractDir: string;
  docBaseDir: string;
  documentNode: XmlNode;
  pages: OFDPage[];
  fileAdapter: OFDFileAdapter;
}

// 文档级扩展：解析后被框架顺序调用，用于接入 Annotations、Signatures 等关联文件。
export interface DocumentExtension {
  name: string;
  apply(context: DocumentExtensionContext): Promise<void>;
}

export class OFDParser {
  private static documentExtensions: DocumentExtension[] = [];

  static registerDocumentExtension(ext: DocumentExtension): void {
    OFDParser.documentExtensions.push(ext);
  }

  static clearDocumentExtensions(): void {
    OFDParser.documentExtensions = [];
  }

  private readonly fileAdapter: OFDFileAdapter;
  private readonly zipAdapter: OFDZipAdapter;
  private readonly workDir: string;
  private readonly documentParser: DocumentParser = new DocumentParser();

  constructor(options?: OFDParserOptions) {
    this.fileAdapter = options?.fileAdapter ? options.fileAdapter : new FileUtils();
    this.zipAdapter = options?.zipAdapter ? options.zipAdapter : new ZipUtils();
    this.workDir = options?.workDir ? options.workDir : '/data/storage/el2/base/cache/ofdkit';
  }

  async parse(ofdPath: string): Promise<OFDDocument> {
    console.info(`[ofdkit] 开始解析：${ofdPath}`);

    if (!ofdPath.endsWith('.ofd')) {
      throw new Error('请选择 .ofd 文件');
    }

    const fileExists: boolean = await this.fileAdapter.exists(ofdPath);
    if (!fileExists) {
      throw new Error(`文件不存在：${ofdPath}`);
    }

    const extractDir: string = await this.zipAdapter.extract(ofdPath, this.workDir);
    console.info(`[ofdkit] 解压完成：${extractDir}`);

    const ofdXmlPath: string = this.fileAdapter.joinPath(extractDir, 'OFD.xml');
    const ofdXml: string = await this.fileAdapter.readText(ofdXmlPath);
    const entry: OFDPackageEntry = this.parseOFDXml(ofdXml);
    console.info(`[ofdkit] OFD 入口：${entry.docRoot}`);

    const documentXmlPath: string = this.fileAdapter.joinPath(extractDir, entry.docRoot);
    const documentXml: string = await this.fileAdapter.readText(documentXmlPath);
    const pageRefs: OFDPageRef[] = this.documentParser.parsePageRefs(documentXml);

    const docBaseDir: string = this.parentDir(entry.docRoot);
    const resources: OFDResources = await this.loadResources(documentXml, extractDir, docBaseDir);
    console.info(`[ofdkit] 资源加载完成：字体 ${resources.fonts.size}、图片 ${resources.multiMedias.size}、绘制参数 ${resources.drawParams.size}`);

    const pageContents: Map<string, string> = new Map<string, string>();
    for (let index: number = 0; index < pageRefs.length; index++) {
      const baseLoc: string = pageRefs[index].baseLoc;
      const relativeToRoot: string = this.fileAdapter.joinPath(docBaseDir, baseLoc);
      const contentPath: string = this.fileAdapter.joinPath(extractDir, relativeToRoot);
      pageContents.set(baseLoc, await this.fileAdapter.readText(contentPath));
      console.info(`[ofdkit] 已读取页面 ${index + 1}：${baseLoc}`);
    }

    const pages: OFDPage[] = this.documentParser.parse(documentXml, pageContents);
    pages.forEach((page: OFDPage) => {
      page.resources = resources;
    });

    const document: OFDDocument = {
      version: entry.version,
      docType: entry.docType,
      pages,
      resources
    };

    await this.applyDocumentExtensions(documentXml, extractDir, docBaseDir, pages);

    console.info(`[ofdkit] 解析完成，总页数：${document.pages.length}`);
    return document;
  }

  private async applyDocumentExtensions(
    documentXml: string,
    extractDir: string,
    docBaseDir: string,
    pages: OFDPage[]
  ): Promise<void> {
    if (OFDParser.documentExtensions.length === 0) {
      return;
    }
    const docNode: XmlNode = XmlParser.parse(documentXml);
    const context: DocumentExtensionContext = {
      extractDir,
      docBaseDir,
      documentNode: docNode,
      pages,
      fileAdapter: this.fileAdapter
    };
    for (let i: number = 0; i < OFDParser.documentExtensions.length; i++) {
      const ext: DocumentExtension = OFDParser.documentExtensions[i];
      try {
        await ext.apply(context);
      } catch (error) {
        console.warn(`[ofdkit] 文档扩展 ${ext.name} 失败：${error}`);
      }
    }
  }

  parseOFDXml(ofdXml: string): OFDPackageEntry {
    const root: XmlNode = XmlParser.parse(ofdXml);
    if (root.name !== 'OFD') {
      throw new Error(`OFD.xml 根节点应为 <OFD>，实际：<${root.name}>`);
    }

    const docBodyNode: XmlNode | undefined = XmlParser.findChild(root, 'DocBody');
    if (docBodyNode === undefined) {
      throw new Error('OFD.xml 缺少 <DocBody>');
    }
    const docRoot: string | undefined = XmlParser.childText(docBodyNode, 'DocRoot');
    if (docRoot === undefined) {
      throw new Error('OFD.xml 缺少 <DocRoot>');
    }

    return {
      docRoot,
      version: XmlParser.attr(root, 'Version') ?? '1.0',
      docType: XmlParser.attr(root, 'DocType') ?? 'OFD'
    };
  }

  private async loadResources(documentXml: string, extractDir: string, docBaseDir: string): Promise<OFDResources> {
    const merged: OFDResources = ResourceParser.empty();
    const refs: string[] = this.parseResourceRefs(documentXml);

    for (let i: number = 0; i < refs.length; i++) {
      const rel: string = refs[i];
      const relativeToRoot: string = this.fileAdapter.joinPath(docBaseDir, rel);
      const resXmlPath: string = this.fileAdapter.joinPath(extractDir, relativeToRoot);
      const exists: boolean = await this.fileAdapter.exists(resXmlPath);
      if (!exists) {
        console.warn(`[ofdkit] 资源文件不存在：${resXmlPath}`);
        continue;
      }
      try {
        const resXml: string = await this.fileAdapter.readText(resXmlPath);
        const resXmlDir: string = this.parentDir(resXmlPath);
        const parsed: OFDResources = ResourceParser.parse(resXml, resXmlDir, this.fileAdapter);
        ResourceParser.merge(merged, parsed);
      } catch (error) {
        console.warn(`[ofdkit] 解析资源 ${rel} 失败：${error}`);
      }
    }
    return merged;
  }

  private parseResourceRefs(documentXml: string): string[] {
    const docNode: XmlNode = XmlParser.parse(documentXml);
    const commonData: XmlNode | undefined = XmlParser.findChild(docNode, 'CommonData');
    if (commonData === undefined) {
      return [];
    }
    const refs: string[] = [];
    // PublicRes 先，DocumentRes 后；后者同 ID 会覆盖前者。
    XmlParser.findChildren(commonData, 'PublicRes').forEach((node: XmlNode) => {
      const t: string = node.text.trim();
      if (t.length > 0) refs.push(t);
    });
    XmlParser.findChildren(commonData, 'DocumentRes').forEach((node: XmlNode) => {
      const t: string = node.text.trim();
      if (t.length > 0) refs.push(t);
    });
    return refs;
  }

  private parentDir(path: string): string {
    const index: number = path.lastIndexOf('/');
    return index >= 0 ? path.substring(0, index) : '';
  }
}
