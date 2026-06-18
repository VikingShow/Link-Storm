# 华为/HarmonyOS 能力调研与本机环境记录

日期：2026-06-11

## 1. 本机开发环境

当前机器已确认：

```text
Node.js: 可用
npm: 可用
Java: 可用
hvigor: 未发现
ohpm: 未发现
DevEco Studio CLI: 未发现
```

结论：

1. 当前环境可以运行 Node/浏览器本地原型。
2. 当前环境不能直接编译或验证 HarmonyOS ArkTS 工程。
3. 第一阶段先实现可运行的本地原型与核心数据结构。
4. 后续在 DevEco Studio 环境中迁移为 HarmonyOS 工程。

## 2. 官方能力映射

### 2.1 语音录制

目标：手机端快速录音保存想法。

HarmonyOS 可用方向：

1. AudioCapturer：用于采集 PCM 音频数据。
2. AVRecorder/媒体录制能力：用于更接近文件录制的场景。
3. 麦克风权限按需申请。

产品落地：

1. 第一版必须支持录音保存。
2. 语音转文字不作为第一阶段必须能力。
3. 录音文件存应用沙箱目录，数据库只存路径和元数据。

### 2.2 手写与画布

目标：平板端打开写字板，保存手写笔迹。

HarmonyOS 可用方向：

1. ArkUI Canvas/ArkGraphics 2D 绘制。
2. Pointer/touch 事件记录轨迹。
3. 后续可接入手写笔相关能力。

产品落地：

1. 保存笔迹矢量 JSON。
2. 保存预览图片。
3. 第一版不强依赖手写识别。

### 2.3 文档编辑

目标：PC/二合一端打开文档编辑面板。

HarmonyOS 可用方向：

1. TextInput/TextArea。
2. 自适应布局。
3. 本地关系型数据库和文件存储。

产品落地：

1. 第一版做纯文本/Markdown 风格编辑。
2. 不做复杂富文本。

### 2.4 本地存储

目标：纯本地保存想法库。

HarmonyOS 可用方向：

1. Preferences：轻量配置。
2. relationalStore：结构化本地数据。
3. 应用沙箱文件：音频、图片、手写 JSON、导出包。

产品落地：

1. 想法元数据存关系型数据库。
2. 大文件存应用文件目录。
3. 导出包由元数据和附件组成。

### 2.5 分享与上下文

目标：用户在其他应用看到文章/视频时，把链接或文本传入 Link Storm。

HarmonyOS 可用方向：

1. Share Kit 或系统分享能力接收文本、链接、图片等内容。
2. Want 参数传递。
3. 获取不到链接时，允许用户手动补充或截图。

产品落地：

1. 分享入口比悬浮球直接读取链接更可靠。
2. 悬浮球只作为捕捉入口，不承诺直接读取其他应用内容。

### 2.6 截图与悬浮入口

目标：获取不到链接时截图兜底；跨应用快速捕捉。

HarmonyOS 可用方向：

1. 全局闪控球/全局悬浮窗方向。
2. screenshot/AVScreenCaptureRecorder 方向。
3. 相关能力可能涉及受限权限、用户授权和上架审核。

产品落地：

1. 悬浮入口作为增强能力，不阻塞第一阶段。
2. 截图必须用户确认。
3. 不能无授权读取其他应用画面。

### 2.7 跨设备同步

目标：本地优先，同时支持未来设备间同步。

HarmonyOS 可用方向：

1. 分布式数据对象。
2. 关系型数据库跨设备同步。
3. 可信设备与系统账号关系。

产品落地：

1. 第一阶段不做自动同步。
2. 第一阶段必须做导出/导入。
3. 数据模型预留 device_id、version、sync_status。
4. 后续验证 HarmonyOS 同应用跨设备同步。

## 3. 参考文档

1. AudioCapturer 录音：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/using-audiocapturer-for-recording
2. relationalStore：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-rdb-store
3. Preferences：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-preferences
4. 应用文件访问：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-file-access
5. Share Kit：https://developer.huawei.com/consumer/en/doc/harmonyos-guides/share-introduction
6. 全局闪控球：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/floatingball-guide
7. 受限权限说明：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions
8. 屏幕截图 API：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-screenshot
9. 分布式数据对象：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-sync-of-distributed-data-object
10. 关系型数据库跨设备同步：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-sync-of-rdb-store
