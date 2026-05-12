import { OFDFileAdapter } from '../parser/types';

// 功能开头：定义 SDK 需要的最小文件能力，避免解析器直接依赖 UI 或页面能力。
// 未来计划：确认当前 HarmonyOS NEXT SDK 后，在这里接入 @ohos.file.fs 的 exists/readText 实现。
export class FileUtils implements OFDFileAdapter {
  async exists(path: string): Promise<boolean> {
    console.info(`[ofdkit] TODO: 确认 @ohos.file.fs 文件存在 API：${path}`);
    throw new Error('FileUtils.exists 尚未接入 HarmonyOS 文件 API，请确认 @ohos.file.fs 可用签名后实现');
  }

  async readText(path: string): Promise<string> {
    console.info(`[ofdkit] TODO: 确认 @ohos.file.fs 文本读取 API：${path}`);
    throw new Error('FileUtils.readText 尚未接入 HarmonyOS 文件 API，请确认 @ohos.file.fs 可用签名后实现');
  }

  joinPath(basePath: string, childPath: string): string {
    if (basePath.length === 0) {
      return childPath;
    }

    if (childPath.length === 0) {
      return basePath;
    }

    const normalizedBase: string = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
    const normalizedChild: string = childPath.startsWith('/') ? childPath.substring(1) : childPath;
    return `${normalizedBase}/${normalizedChild}`;
  }
}
