import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { OFDDocument, OFDPage, OFDParser } from '../ofdkit';
import { FileUtils } from '../ofdkit/utils/FileUtils';

@Entry
@Component
struct Index {
  @State message: string = '请选择一个 OFD 文件';
  @State errorMessage: string = '';
  @State documentInfo: OFDDocument | undefined = undefined;

  build() {
    Column({ space: 16 }) {
      // 功能开头：页面只负责选择文件和展示基础解析结果，SDK 逻辑放在 ofdkit 目录。
      // 未来计划：加入加载状态、最近打开记录和解析失败详情展开。
      Button('选择 OFD 文件')
        .onClick(() => {
          this.pickOFDFile();
        })

      Text(this.message)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor(Color.Red)
      }

      if (this.documentInfo !== undefined) {
        Text(`版本号：${this.documentInfo.version}`)
          .fontSize(14)
        Text(`文档类型：${this.documentInfo.docType}`)
          .fontSize(14)
        Text(`总页数：${this.documentInfo.pages.length}`)
          .fontSize(14)

        ForEach(this.documentInfo.pages, (page: OFDPage) => {
          Text(`第 ${page.pageIndex + 1} 页：${page.physicalBox.width} × ${page.physicalBox.height} mm`)
            .fontSize(14)
        }, (page: OFDPage) => page.id)
      }
    }
    .height('100%')
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Start)
  }

  private async pickOFDFile(): Promise<void> {
    this.errorMessage = '';
    this.documentInfo = undefined;

    try {
      const context: common.UIAbilityContext = this.getAbilityContext();
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const selectedUris: Array<string> = await documentPicker.select({
        fileSuffixFilters: ['OFD 文档|.ofd'],
        maxSelectNumber: 1
      });

      if (selectedUris.length === 0) {
        this.message = '未选择文件';
        return;
      }

      const localPath: string = await this.copyPickedFileToCache(selectedUris[0], context.cacheDir);
      await this.parseOFDFile(localPath, context.cacheDir);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '选择 OFD 文件失败';
      this.errorMessage = message;
      console.error(`[ofdkit] ${message}`);
    }
  }

  private async parseOFDFile(ofdPath: string, cacheDir: string): Promise<void> {
    const parser: OFDParser = new OFDParser({
      workDir: `${cacheDir}/ofdkit/extract`
    });
    const document: OFDDocument = await parser.parse(ofdPath);
    this.documentInfo = document;
    this.message = `解析完成：${ofdPath}`;
  }

  private getAbilityContext(): common.UIAbilityContext {
    const context: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!context) {
      throw new Error('获取 UIAbilityContext 失败');
    }
    return context;
  }

  private async copyPickedFileToCache(uri: string, cacheDir: string): Promise<string> {
    const fileUtils: FileUtils = new FileUtils();
    const targetDir: string = `${cacheDir}/ofdkit/source`;
    await fileUtils.ensureDir(targetDir);

    const targetPath: string = `${targetDir}/picked_${Date.now()}.ofd`;
    try {
      await fileUtils.copyFile(uri, targetPath);
      console.info(`[ofdkit] 已复制选择文件：${uri} -> ${targetPath}`);
      return targetPath;
    } catch (error) {
      throw new Error('复制所选 OFD 文件到应用缓存失败');
    }
  }
}
