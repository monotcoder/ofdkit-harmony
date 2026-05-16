// ofdkit-harmony 包入口：转发 ofdkit/index.ets 的所有公开 API。
// 调用方：import { OFDParser, OFDPageView, installDefaultExtensions, ... } from 'ofdkit-harmony';

export * from './src/main/ets/ofdkit';
export { FileUtils } from './src/main/ets/ofdkit/utils/FileUtils';
export { ZipUtils } from './src/main/ets/ofdkit/utils/ZipUtils';
export { OFDPageView } from './src/main/ets/ofdkit/components/OFDPageView';
export { OFDThumbnailStrip } from './src/main/ets/ofdkit/components/OFDThumbnailStrip';
export { OFDSearchBar } from './src/main/ets/ofdkit/components/OFDSearchBar';
export { OFDDocumentScroll } from './src/main/ets/ofdkit/components/OFDDocumentScroll';
export { XmlNode, XmlParser } from './src/main/ets/ofdkit/utils/XmlParser';
export { ParseHelpers } from './src/main/ets/ofdkit/parser/ParseHelpers';
