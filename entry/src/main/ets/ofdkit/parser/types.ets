// 功能开头：阶段一只承载 OFD 文档基础信息，供页面展示和控制台日志使用。
// 未来计划：阶段二会在这里扩展文字、路径、图片、字体、绘制参数和资源索引等结构。
export interface OFDDocument {
  version: string;
  docType: string;
  pages: OFDPage[];
}

export interface OFDPage {
  id: string;
  pageIndex: number;
  physicalBox: PageBox;
}

export interface PageBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface OFDPackageEntry {
  docRoot: string;
  version: string;
  docType: string;
}

export interface OFDPageRef {
  id: string;
  baseLoc: string;
}

export interface OFDFileAdapter {
  exists(path: string): Promise<boolean>;
  readText(path: string): Promise<string>;
  joinPath(basePath: string, childPath: string): string;
}

export interface OFDZipAdapter {
  extract(ofdPath: string, outputDir: string): Promise<string>;
}

export interface OFDParserOptions {
  workDir?: string;
  fileAdapter?: OFDFileAdapter;
  zipAdapter?: OFDZipAdapter;
}
