import { DocumentParser } from './DocumentParser';
import {
  OFDDocument,
  OFDFileAdapter,
  OFDPackageEntry,
  OFDPageRef,
  OFDParserOptions,
  OFDZipAdapter
} from './types';
import { FileUtils } from '../utils/FileUtils';
import { ZipUtils } from '../utils/ZipUtils';

// 功能开头：负责从 .ofd 包入口串起解压、OFD.xml、Document.xml 和页面尺寸解析。
// 未来计划：加入资源目录索引、错误码体系、日志回调、进度回调和多文档入口支持。
export class OFDParser {
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
    const pageLocs: string[] = pageRefs.map((ref: OFDPageRef) => ref.baseLoc);
    const pageContents: Map<string, string> = new Map<string, string>();
    const docBaseDir: string = this.parentDir(entry.docRoot);

    for (let index = 0; index < pageLocs.length; index++) {
      const pageLoc: string = pageLocs[index];
      const contentPath: string = this.fileAdapter.joinPath(extractDir, this.fileAdapter.joinPath(docBaseDir, pageLoc));
      pageContents.set(pageLoc, await this.fileAdapter.readText(contentPath));
      console.info(`[ofdkit] 已读取页面 ${index + 1}：${pageLoc}`);
    }

    const document: OFDDocument = {
      version: entry.version,
      docType: entry.docType,
      pages: this.documentParser.parse(documentXml, pageContents)
    };

    console.info(`[ofdkit] 解析完成，总页数：${document.pages.length}`);
    return document;
  }

  parseOFDXml(ofdXml: string): OFDPackageEntry {
    return {
      docRoot: this.readElementText(ofdXml, 'DocRoot'),
      version: this.readAttributeFromRoot(ofdXml, 'Version', '1.0'),
      docType: this.readAttributeFromRoot(ofdXml, 'DocType', 'OFD')
    };
  }

  private readElementText(xml: string, localName: string): string {
    const elementRegExp: RegExp = new RegExp(`<(?:ofd:)?${localName}\\b[^>]*>([\\s\\S]*?)<\\/(?:ofd:)?${localName}>`);
    const match: RegExpExecArray | null = elementRegExp.exec(xml);

    if (!match) {
      throw new Error(`OFD.xml 缺少 ${localName} 节点`);
    }

    return match[1].trim();
  }

  private readAttributeFromRoot(xml: string, name: string, fallback: string): string {
    const rootRegExp: RegExp = /<(?:ofd:)?OFD\b([^>]*)>/;
    const rootMatch: RegExpExecArray | null = rootRegExp.exec(xml);

    if (!rootMatch) {
      throw new Error('OFD.xml 根节点格式错误');
    }

    const attrRegExp: RegExp = new RegExp(`${name}\\s*=\\s*["']([^"']+)["']`);
    const attrMatch: RegExpExecArray | null = attrRegExp.exec(rootMatch[1]);
    return attrMatch ? attrMatch[1] : fallback;
  }

  private parentDir(path: string): string {
    const index: number = path.lastIndexOf('/');
    return index >= 0 ? path.substring(0, index) : '';
  }
}
