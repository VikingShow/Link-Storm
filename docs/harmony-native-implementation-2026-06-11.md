# HarmonyOS 原生 ArkTS 实现记录

日期：2026-06-11

## 1. 目标

在现有 Web 原型基础上，新增 DevEco Studio 可打开的 HarmonyOS/ArkTS 原生工程骨架。

工程位置：

```text
apps/harmony-link-storm
```

## 2. 当前实现范围

已创建 Stage 模型工程结构：

```text
apps/harmony-link-storm
  AppScope/
  entry/
    src/main/module.json5
    src/main/ets/entryability/EntryAbility.ets
    src/main/ets/pages/Index.ets
    src/main/ets/model/IdeaModels.ets
    src/main/ets/repository/IdeaRepository.ets
```

已实现：

1. EntryAbility。
2. ArkUI 首页。
3. 手机/平板/桌面宽度默认模式逻辑。
4. 三种捕捉模式 UI：
   - 语音：入口预留。
   - 手写：入口预留。
   - 文档：可填写正文。
5. 本地 Preferences 仓储。
6. 想法模型。
7. 保存想法。
8. 想法列表。
9. 搜索。
10. 类型筛选。
11. 收藏、归档、删除。
12. 导出 JSON 预览。

## 3. 为什么先用 Preferences

第一版原生工程先用 Preferences，而不是直接使用 relationalStore。

原因：

1. 当前机器无法编译验证 HarmonyOS 工程。
2. Preferences API 更轻，适合先验证 ArkUI 页面和本地保存闭环。
3. 数据模型已按后续迁移到 relationalStore 设计。

后续迁移方向：

```text
Preferences
-> relationalStore
-> 文件目录存音频/手写/截图附件
```

## 4. 需要在 DevEco Studio 验证的点

当前环境缺少：

```text
hvigor
ohpm
DevEco Studio CLI
```

因此本机未能执行 HarmonyOS 编译。

请在 DevEco Studio 中验证：

1. 工程能否正常打开。
2. SDK/API 版本是否匹配。
3. `@kit.*` import 是否与本地 SDK 一致。
4. `preferences.getPreferences` 签名是否需要根据 SDK 调整。
5. `ButtonStyleMode`、`onAreaChange` 等 ArkUI API 是否与 SDK 版本一致。
6. `AppScope/resources/base/media/app_icon.svg` 是否可作为图标资源使用；如不支持，需要替换为 png。

## 5. DevEco Studio 打开步骤

1. 打开 DevEco Studio。
2. 选择 Open Project。
3. 选择目录：

```text
C:\Users\SowrJam\Desktop\工作空间\Link-Storm\apps\harmony-link-storm
```

4. 等待 DevEco 同步工程。
5. 选择 `entry` 模块。
6. 运行到模拟器或真机。

## 6. 后续原生实现顺序

建议按以下顺序继续：

### 6.1 替换本地存储

```text
Preferences -> relationalStore
```

表：

```text
ideas
idea_assets
idea_contexts
tags
folders
```

### 6.2 接入真实录音

目标：

```text
语音模式点击开始录音
-> 保存音频到应用文件目录
-> idea_assets 记录 localUri、mimeType、duration
```

可用方向：

```text
AVRecorder
AudioCapturer
```

### 6.3 接入真实手写

目标：

```text
Canvas 绘制
-> 保存 strokes JSON
-> 生成预览图
-> idea_assets 记录文件路径
```

### 6.4 导出/导入

目标：

```text
JSON 导出文件
ZIP 导出包
导入备份包
```

### 6.5 系统分享入口

目标：

```text
从浏览器/内容 App 分享链接到 Link Storm
-> 创建带上下文的想法
```

### 6.6 悬浮入口和截图

这两项涉及更高权限，建议放在基础闭环稳定后实现。

## 7. 与 Web 原型的关系

Web 原型位置：

```text
apps/local-capture
```

原生工程位置：

```text
apps/harmony-link-storm
```

两者共享同一产品模型：

```text
Idea
IdeaContext
IdeaAsset
tags
syncStatus
aiStatus
```

Web 原型用于快速验证交互；HarmonyOS 工程用于正式原生实现。
