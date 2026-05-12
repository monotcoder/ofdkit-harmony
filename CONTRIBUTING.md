# 贡献指南

感谢你关注 `ofdkit-harmony`。

这个项目处于早期阶段，当前重点是先把 OFD 解析和渲染主链路跑通。欢迎围绕解析正确性、HarmonyOS API 适配、渲染能力和测试样本提交贡献。

## 如何贡献

1. Fork 仓库并创建功能分支。
2. 保持改动聚焦，避免混入无关格式化。
3. 提交前确认应用可以在目标 HarmonyOS NEXT 环境中编译运行。
4. 提交 Pull Request，并说明改动目的、测试方式和潜在影响。

## Commit 规范

使用 conventional commit 格式，描述使用中文，简洁明了：

```text
feat: 添加页面内容解析
fix: 修复OFD入口路径解析
docs: 更新使用说明
refactor: 拆分资源解析模块
chore: 调整工程配置
```

## 代码约定

- 使用 ArkTS 严格模式。
- SDK 核心代码放在 `entry/src/main/ets/ofdkit`。
- UI 页面代码不要侵入 SDK 核心。
- 不使用 `any` 类型。
- 鸿蒙 API 不确定时，请在 PR 中说明 API 来源、最低版本和兼容性影响。

## 许可证

提交贡献即表示你同意将贡献内容按 Apache License 2.0 授权给本项目。
