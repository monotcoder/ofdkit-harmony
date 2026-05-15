// Signatures 签章解析扩展（DocumentExtension）。
//
// OFD 签章结构：
//   Document.xml: <Signatures>Signs/Signatures.xml</Signatures>
//   Signatures.xml: <Signatures><Signature ID Type BaseLoc/></Signatures>
//   Signs/Sign_x/Signature.xml: <Signature><SignedInfo><Provider Company.../><SignatureDateTime/>
//                                            <StampAnnot ID PageRef Boundary/>...</SignedInfo></Signature>
//
// 本扩展只解析签章的位置和元数据，渲染交给注册的 'signature' 渲染器：
// - 开源版自带占位 SignaturePlaceholderRenderer（红色虚线框 + "需 Pro 验签"）
// - Pro 版可注册新的 ObjectRendererExt 覆盖，绘制实际签章图像 + 验签结果

import { DocumentExtension, DocumentExtensionContext } from '../OFDParser';
import { CustomPageObject, Layer, OFDPage, PageBox } from '../types';
import { XmlNode, XmlParser } from '../../utils/XmlParser';
import { ParseHelpers } from '../ParseHelpers';

// 签章 payload：渲染器 cast `obj.payload as SignaturePayload` 后读取。
export interface SignaturePayload {
  signatureId: string;
  stampId: string;
  type: string;
  dateTime?: string;
  providerCompany?: string;
  providerName?: string;
  signedValuePath?: string;
}

export class SignatureExtension implements DocumentExtension {
  readonly name: string = 'signatures';

  async apply(context: DocumentExtensionContext): Promise<void> {
    const sigsLoc: string | undefined = XmlParser.childText(context.documentNode, 'Signatures');
    if (sigsLoc === undefined || sigsLoc.length === 0) {
      return;
    }
    const sigsXmlPath: string = context.fileAdapter.joinPath(
      context.extractDir,
      context.fileAdapter.joinPath(context.docBaseDir, sigsLoc)
    );
    const exists: boolean = await context.fileAdapter.exists(sigsXmlPath);
    if (!exists) {
      console.warn(`[ofdkit] Signatures 索引文件不存在：${sigsXmlPath}`);
      return;
    }
    const sigsXml: string = await context.fileAdapter.readText(sigsXmlPath);
    const sigsNode: XmlNode = XmlParser.parse(sigsXml);
    const sigsBaseDir: string = this.parentDir(sigsXmlPath);

    const sigEntries: XmlNode[] = XmlParser.findChildren(sigsNode, 'Signature');
    for (let i: number = 0; i < sigEntries.length; i++) {
      const sigEntry: XmlNode = sigEntries[i];
      const id: string | undefined = XmlParser.attr(sigEntry, 'ID');
      const baseLoc: string | undefined = XmlParser.attr(sigEntry, 'BaseLoc');
      const type: string = XmlParser.attr(sigEntry, 'Type') ?? 'Seal';
      if (id === undefined || baseLoc === undefined) {
        continue;
      }
      await this.loadSignature(context, sigsBaseDir, id, type, baseLoc);
    }
  }

  private async loadSignature(
    context: DocumentExtensionContext,
    sigsBaseDir: string,
    signatureId: string,
    type: string,
    baseLoc: string
  ): Promise<void> {
    const sigXmlPath: string = context.fileAdapter.joinPath(sigsBaseDir, baseLoc);
    const exists: boolean = await context.fileAdapter.exists(sigXmlPath);
    if (!exists) {
      console.warn(`[ofdkit] Signature 文件不存在：${sigXmlPath}`);
      return;
    }
    const sigXml: string = await context.fileAdapter.readText(sigXmlPath);
    const sigNode: XmlNode = XmlParser.parse(sigXml);
    const signedInfo: XmlNode | undefined = XmlParser.findChild(sigNode, 'SignedInfo');
    if (signedInfo === undefined) {
      return;
    }
    const sigBaseDir: string = this.parentDir(sigXmlPath);
    const providerNode: XmlNode | undefined = XmlParser.findChild(signedInfo, 'Provider');
    const dateTime: string | undefined = XmlParser.childText(signedInfo, 'SignatureDateTime');
    const signedValueRel: string | undefined = XmlParser.childText(sigNode, 'SignedValue');
    const signedValuePath: string | undefined = signedValueRel !== undefined
      ? context.fileAdapter.joinPath(sigBaseDir, signedValueRel)
      : undefined;

    XmlParser.findChildren(signedInfo, 'StampAnnot').forEach((stamp: XmlNode) => {
      const stampId: string | undefined = XmlParser.attr(stamp, 'ID');
      const pageRef: string | undefined = XmlParser.attr(stamp, 'PageRef');
      const boundaryAttr: string | undefined = XmlParser.attr(stamp, 'Boundary');
      if (stampId === undefined || pageRef === undefined || boundaryAttr === undefined) {
        return;
      }
      const page: OFDPage | undefined = context.pages.find((p: OFDPage) => p.id === pageRef);
      if (page === undefined) {
        console.warn(`[ofdkit] 签章引用了不存在的 PageRef=${pageRef}`);
        return;
      }
      let boundary: PageBox;
      try {
        boundary = ParseHelpers.box(boundaryAttr);
      } catch (error) {
        console.warn(`[ofdkit] 签章 Boundary 非法：${boundaryAttr}`);
        return;
      }
      const payload: SignaturePayload = {
        signatureId,
        stampId,
        type,
        dateTime,
        providerCompany: providerNode !== undefined ? XmlParser.attr(providerNode, 'Company') : undefined,
        providerName: providerNode !== undefined ? XmlParser.attr(providerNode, 'ProviderName') : undefined,
        signedValuePath
      };
      const obj: CustomPageObject = {
        type: 'custom',
        id: stampId,
        boundary,
        customType: 'signature',
        payload
      };
      this.appendToSignatureLayer(page, obj);
    });
  }

  private appendToSignatureLayer(page: OFDPage, obj: CustomPageObject): void {
    if (page.content === undefined) {
      page.content = { layers: [] };
    }
    let sigLayer: Layer | undefined = page.content.layers.find((l: Layer) => l.type === 'Signature');
    if (sigLayer === undefined) {
      sigLayer = { id: `sig_${page.id}`, type: 'Signature', objects: [] };
      page.content.layers.push(sigLayer);
    }
    sigLayer.objects.push(obj);
  }

  private parentDir(path: string): string {
    const idx: number = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(0, idx) : '';
  }
}
