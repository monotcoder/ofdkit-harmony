// 默认扩展安装：把开源版自带的注释/签章解析与占位渲染注册到 OFDParser/OFDRenderer。
// 调用方在 app 启动时调一次。Pro 仓库可在调用本函数后再注册自己的渲染器覆盖（按 customType 同名替换）。

import { OFDParser } from './parser/OFDParser';
import { OFDRenderer } from './renderer/OFDRenderer';
import { AnnotationExtension } from './parser/extensions/AnnotationExtension';
import { SignatureExtension } from './parser/extensions/SignatureExtension';
import { SignaturePlaceholderRenderer } from './renderer/extensions/SignaturePlaceholderRenderer';

export function installDefaultExtensions(): void {
  OFDParser.clearDocumentExtensions();
  OFDParser.registerDocumentExtension(new AnnotationExtension());
  OFDParser.registerDocumentExtension(new SignatureExtension());

  OFDRenderer.clearRenderers();
  OFDRenderer.registerRenderer(new SignaturePlaceholderRenderer());
}
