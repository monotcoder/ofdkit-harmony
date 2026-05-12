import { zlib } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { OFDZipAdapter } from '../parser/types';

// 功能开头：为 OFDParser 提供 ZIP 解压入口，OFD 本质上按 ZIP 包处理。
// 未来计划：补充解压前缓存清理、路径穿越防护和大文件解压进度反馈。
export class ZipUtils implements OFDZipAdapter {
  async extract(ofdPath: string, outputDir: string): Promise<string> {
    const extractDir: string = this.createExtractDir(outputDir, ofdPath);

    try {
      await fileIo.mkdir(extractDir, true);
      await zlib.decompressFile(ofdPath, extractDir);
      return extractDir;
    } catch (error) {
      throw new Error(`OFD 解压失败：${ofdPath}`);
    }
  }

  private createExtractDir(outputDir: string, ofdPath: string): string {
    const fileName: string = this.fileNameWithoutExtension(ofdPath);
    const safeName: string = fileName.replace(/[^a-zA-Z0-9_-]/g, '_');
    const normalizedBase: string = outputDir.endsWith('/') ? outputDir.substring(0, outputDir.length - 1) : outputDir;
    return `${normalizedBase}/${safeName}_${Date.now()}`;
  }

  private fileNameWithoutExtension(path: string): string {
    const slashIndex: number = path.lastIndexOf('/');
    const fileName: string = slashIndex >= 0 ? path.substring(slashIndex + 1) : path;
    const dotIndex: number = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }
}
