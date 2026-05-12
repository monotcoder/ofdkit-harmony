import { OFDDocument, OFDPage, OFDParser } from '../ofdkit';

@Entry
@Component
struct Index {
  @State message: string = '请选择一个 OFD 文件';
  @State errorMessage: string = '';
  @State documentInfo: OFDDocument | undefined = undefined;

  build() {
    Column({ space: 16 }) {
      // 功能开头：页面只负责选择文件和展示基础解析结果，SDK 逻辑放在 ofdkit 目录。
      // 未来计划：确认 @ohos.file.picker 后，把 TODO 按钮替换为真实的 DocumentViewPicker 调用。
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
      // 待确认 API 方案：
      // 1. @ohos.file.picker.DocumentViewPicker + select({ fileSuffixFilters: ['.ofd'] })
      // 2. @ohos.file.picker.DocumentSelectOptions，选择后拿到 uri 再复制到应用沙箱
      // 3. 如果 picker 返回 uri 不能直接解压，需要先通过 fs.open/read/write 复制为本地 .ofd 文件
      throw new Error('文件选择器尚未接入：请确认 @ohos.file.picker 的可用签名后实现');
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '选择 OFD 文件失败';
      this.errorMessage = message;
      console.error(`[ofdkit] ${message}`);
    }
  }

  private async parseOFDFile(ofdPath: string): Promise<void> {
    const parser: OFDParser = new OFDParser();
    const document: OFDDocument = await parser.parse(ofdPath);
    this.documentInfo = document;
    this.message = `解析完成：${ofdPath}`;
  }
}
