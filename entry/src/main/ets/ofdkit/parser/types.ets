// OFD 文档对象模型，对齐 GB/T 33190-2016 的页面对象定义。
// 注意：OFD 中 Font、Size、Stroke、Fill、CTM、ResourceID 等均为元素属性（attribute），不是子元素。

export interface OFDDocument {
  version: string;
  docType: string;
  pages: OFDPage[];
  resources: OFDResources;
}

export interface OFDPage {
  id: string;
  pageIndex: number;
  physicalBox: PageBox;
  content?: PageContent;
  resources?: OFDResources;
}

export interface PageContent {
  layers: Layer[];
}

export interface ParsedPage {
  physicalBox: PageBox;
  content: PageContent;
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

export interface Layer {
  id?: string;
  type?: string;
  drawParam?: string;
  objects: PageObject[];
}

export type PageObject = TextObject | PathObject | ImageObject | CompositeBlock;

export interface BasePageObject {
  id: string;
  boundary: PageBox;
  ctm?: CTM;
  drawParam?: string;
  visible?: boolean;
}

export interface TextObject extends BasePageObject {
  type: 'text';
  font: string;
  size: number;
  stroke?: boolean;
  fill?: boolean;
  hScale?: number;
  weight?: number;
  italic?: boolean;
  fillColor?: Color;
  strokeColor?: Color;
  textCodes: TextCode[];
}

export interface TextCode {
  text: string;
  x?: number;
  y?: number;
  deltaX?: number[];
  deltaY?: number[];
}

export interface PathObject extends BasePageObject {
  type: 'path';
  abbreviatedData?: string;
  stroke?: boolean;
  fill?: boolean;
  lineWidth?: number;
  fillColor?: Color;
  strokeColor?: Color;
}

export interface ImageObject extends BasePageObject {
  type: 'image';
  resourceID: string;
}

// PageBlock：OFD 标准的组合容器，可以嵌套其他对象。
export interface CompositeBlock {
  type: 'block';
  id?: string;
  boundary?: PageBox;
  ctm?: CTM;
  drawParam?: string;
  children: PageObject[];
}

export interface CTM {
  a: number;
  b: number;
  c: number;
  d: number;
  e: number;
  f: number;
}

// 简化的颜色模型：OFD CT_Color 可能是 RGB/CMYK/Pattern/Gradient，这里只取 RGB Value。
export interface Color {
  value: string;
  alpha?: number;
}

// 文档资源：字体、多媒体（图片）、绘制参数预设。
export interface OFDResources {
  fonts: Map<string, OFDFont>;
  multiMedias: Map<string, OFDMultiMedia>;
  drawParams: Map<string, OFDDrawParam>;
}

export interface OFDFont {
  id: string;
  fontName: string;
  familyName?: string;
  charset?: string;
  serif?: boolean;
  bold?: boolean;
  italic?: boolean;
  fixedWidth?: boolean;
  fontFile?: string;
}

export interface OFDMultiMedia {
  id: string;
  type: string;
  format?: string;
  mediaFile: string;
}

export interface OFDDrawParam {
  id: string;
  relative?: string;
  lineWidth?: number;
  join?: string;
  cap?: string;
  miterLimit?: number;
  dashOffset?: number;
  dashPattern?: number[];
  strokeColor?: Color;
  fillColor?: Color;
}
