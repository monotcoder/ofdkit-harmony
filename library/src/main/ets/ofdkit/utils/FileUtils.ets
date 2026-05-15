import { fileIo } from '@kit.CoreFileKit';
import { OFDFileAdapter } from '../parser/types';

// 功能开头：定义 SDK 需要的最小文件能力，避免解析器直接依赖 UI 或页面能力。
// 未来计划：补充二进制读取、递归清理、URI 到沙箱复制的进度回调和统一错误码。
export class FileUtils implements OFDFileAdapter {
  async exists(path: string): Promise<boolean> {
    try {
      return await fileIo.access(path, fileIo.AccessModeType.EXIST);
    } catch (error) {
      console.error(`[ofdkit] 文件访问失败：${path}`);
      return false;
    }
  }

  async readText(path: string): Promise<string> {
    try {
      return await fileIo.readText(path);
    } catch (error) {
      throw new Error(`读取文本文件失败：${path}`);
    }
  }

  async copyFile(srcPath: string, destPath: string): Promise<void> {
    let sourceFile: fileIo.File | undefined = undefined;
    let targetFile: fileIo.File | undefined = undefined;

    try {
      sourceFile = await fileIo.open(srcPath, fileIo.OpenMode.READ_ONLY);
      targetFile = await fileIo.open(
        destPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC
      );
      await fileIo.copyFile(sourceFile.fd, targetFile.fd);
    } catch (error) {
      throw new Error(`复制文件失败：${srcPath} -> ${destPath}`);
    } finally {
      if (sourceFile !== undefined) {
        await fileIo.close(sourceFile);
      }
      if (targetFile !== undefined) {
        await fileIo.close(targetFile);
      }
    }
  }

  async ensureDir(path: string): Promise<void> {
    try {
      const exists: boolean = await this.exists(path);
      if (!exists) {
        await fileIo.mkdir(path, true);
      }
    } catch (error) {
      throw new Error(`创建目录失败：${path}`);
    }
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

  // 大小写不敏感查找：递归从最长存在的祖先开始，向下逐段在目录列表里找大小写不一致但语义相同的条目。
  // 不存在则返回 undefined。直接命中时不递归，开销近似 exists()。
  async resolveCaseInsensitive(path: string): Promise<string | undefined> {
    if (await this.exists(path)) {
      return path;
    }
    const slashIdx: number = path.lastIndexOf('/');
    if (slashIdx <= 0) {
      return undefined;
    }
    const parent: string = path.substring(0, slashIdx);
    const last: string = path.substring(slashIdx + 1);
    if (last.length === 0) {
      return undefined;
    }
    const resolvedParent: string | undefined = await this.resolveCaseInsensitive(parent);
    if (resolvedParent === undefined) {
      return undefined;
    }
    let entries: string[];
    try {
      entries = await fileIo.listFile(resolvedParent);
    } catch (error) {
      return undefined;
    }
    const lastLower: string = last.toLowerCase();
    for (let i: number = 0; i < entries.length; i++) {
      if (entries[i].toLowerCase() === lastLower) {
        return this.joinPath(resolvedParent, entries[i]);
      }
    }
    return undefined;
  }
}
