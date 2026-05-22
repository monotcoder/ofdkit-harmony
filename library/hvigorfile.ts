import { harTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

// ohpm publish 要求包内必须有 LICENSE / README.md / CHANGELOG.md，
// 但单一来源应该在根目录。这里在 build 前从根目录复制到 library/，
// 避免手动同步遗漏导致版本号或内容不一致。
// 复制产物在 .gitignore 中已忽略。
const syncFiles = ['LICENSE', 'README.md', 'CHANGELOG.md'];
const rootDir = path.resolve(__dirname, '..');
for (const f of syncFiles) {
  const src = path.join(rootDir, f);
  const dst = path.join(__dirname, f);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dst);
  }
}

export default {
  system: harTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
