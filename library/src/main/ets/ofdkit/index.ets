export { OFDParser, DocumentExtension, DocumentExtensionContext } from './parser/OFDParser';
export { DocumentParser } from './parser/DocumentParser';
export { ContentParser, ObjectParserExt } from './parser/ContentParser';
export { ResourceParser } from './parser/ResourceParser';
export { OFDRenderer, RenderResources, RenderContext, ObjectRendererExt, SelectionRect } from './renderer/OFDRenderer';
export { OFDThumbnailStrip } from './components/OFDThumbnailStrip';
export { installDefaultExtensions } from './defaults';

// 默认随包扩展（开源版自带的解析与占位渲染）
export { AnnotationExtension } from './parser/extensions/AnnotationExtension';
export { SignatureExtension, SignaturePayload } from './parser/extensions/SignatureExtension';
export { SignaturePlaceholderRenderer } from './renderer/extensions/SignaturePlaceholderRenderer';

export {
  OFDDocument,
  OFDPage,
  OFDPageRef,
  PageBox,
  OFDPackageEntry,
  OFDFileAdapter,
  OFDZipAdapter,
  OFDParserOptions,
  PageContent,
  ParsedPage,
  Layer,
  PageObject,
  TextObject,
  PathObject,
  ImageObject,
  CompositeBlock,
  CustomPageObject,
  TextCode,
  TemplateRef,
  Color,
  CTM,
  OFDResources,
  OFDFont,
  OFDMultiMedia,
  OFDDrawParam
} from './parser/types';
