# 实现记录 2026-06-15 - Detail 来源链接

## 1. 本次变更
- `apps/harmony-link-storm/entry/src/main/ets/pages/Detail.ets`
- 详情页来源上下文区域新增“打开来源”动作
- 来源 URL 自动补全 `https://`

## 2. 验证结果
```bash
node C:\Users\SowrJam\workspace\_tools\deveco-cli-npm\node_modules\@deveco\deveco-cli\dist\cli.js build --modules entry
```

结果：
- `BUILD SUCCESSFUL`

## 3. 说明
- 这一步让详情页从“只展示来源文本”升级为“可直接回到外部来源”
- 保持单文件改动，便于后续继续按里程碑推进
