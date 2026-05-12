import { OFDZipAdapter } from '../parser/types';

// 功能开头：为 OFDParser 提供 ZIP 解压入口，OFD 本质上按 ZIP 包处理。
// 未来计划：确认 @ohos.zlib 的 decompressFile/decompressFiles 签名后，按文件名创建独立解压目录并清理旧缓存。
export class ZipUtils implements OFDZipAdapter {
  async extract(ofdPath: string, outputDir: string): Promise<string> {
    console.info(`[ofdkit] TODO: 确认 @ohos.zlib 解压 API：${ofdPath} -> ${outputDir}`);
    throw new Error('ZipUtils.extract 尚未接入 HarmonyOS ZIP 解压 API，请确认 @ohos.zlib 可用签名后实现');
  }
}
