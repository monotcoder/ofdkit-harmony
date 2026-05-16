// 文档全文搜索栏：TextInput + 上一个/下一个匹配 + 关闭。
// 显示 "第 N / 共 M 个"。回车键也触发搜索。
//
// 状态由父组件（@State query / matchIndex / totalMatches）拥有，本组件只暴露 callback。

@Component
export struct OFDSearchBar {
  @Prop query: string = '';
  @Prop activeIndex: number = -1;   // 0-based；-1 表示无命中
  @Prop totalMatches: number = 0;
  // 当用户输入或提交搜索词时触发
  onQuerySubmit?: (q: string) => void;
  onPrev?: () => void;
  onNext?: () => void;
  onClose?: () => void;

  @State private inputValue: string = '';

  aboutToAppear(): void {
    this.inputValue = this.query;
  }

  build() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '搜索...', text: this.inputValue })
        .layoutWeight(1)
        .height(36)
        .fontSize(14)
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .onChange((value: string) => {
          this.inputValue = value;
        })
        .onSubmit(() => {
          if (this.onQuerySubmit !== undefined) {
            this.onQuerySubmit(this.inputValue);
          }
        })

      Text(this.totalMatches > 0 ? `${this.activeIndex + 1}/${this.totalMatches}` : '0')
        .fontSize(12)
        .fontColor(this.totalMatches > 0 ? '#333333' : '#999999')
        .width(48)
        .textAlign(TextAlign.Center)

      Button() {
        Text('↑').fontSize(16).fontColor('#FFFFFF')
      }
      .width(32)
      .height(32)
      .backgroundColor(this.totalMatches > 0 ? '#2196F3' : '#CCCCCC')
      .enabled(this.totalMatches > 0)
      .onClick(() => {
        if (this.onPrev !== undefined) this.onPrev();
      })

      Button() {
        Text('↓').fontSize(16).fontColor('#FFFFFF')
      }
      .width(32)
      .height(32)
      .backgroundColor(this.totalMatches > 0 ? '#2196F3' : '#CCCCCC')
      .enabled(this.totalMatches > 0)
      .onClick(() => {
        if (this.onNext !== undefined) this.onNext();
      })

      Button() {
        Text('✕').fontSize(14).fontColor('#666666')
      }
      .width(32)
      .height(32)
      .backgroundColor('#EEEEEE')
      .onClick(() => {
        if (this.onClose !== undefined) this.onClose();
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#F5F5F5')
  }
}
