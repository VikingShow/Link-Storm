# DevEco Code / DevEco CLI 工具链探索记录

日期：2026-06-14

## 1. 目标

验证用户提供的两个项目是否能帮助 Link Storm 的 HarmonyOS 原生开发：

```text
https://gitcode.com/openharmony-sig/deveco-code.git
https://gitcode.com/openharmony-sig/deveco-cli.git
```

## 2. 仓库用途判断

### 2.1 deveco-code

定位：面向 HarmonyOS 开发场景的 AI Agent 工具。

用途：

1. 代码编写。
2. 编译构建。
3. 设备运行。
4. 文档查阅。
5. 运行时调试。
6. ArkTS 问题修复。

结论：

当前我们已经在 Codex 内协作，不需要再启动另一个 AI Agent。`deveco-code` 可以作为后续独立终端开发工具，但不是当前流程必需项。

### 2.2 deveco-cli

定位：HarmonyOS 应用开发统一 CLI。

用途：

1. `build`：构建 HarmonyOS 工程。
2. `run`：安装并运行应用。
3. `device`：查看连接设备。
4. `emulator`：管理模拟器。
5. `docs`：本地 HarmonyOS 文档检索。
6. `init`：为 AI Agent 配置 Skill/MCP。

结论：

`deveco-cli` 对当前项目非常有用。它可以统一调用 DevEco Studio 内置的 `ohpm`、`hvigor`、`hdc`、模拟器和文档检索。

## 3. 本机环境检测

DevEco Studio：

```text
路径：C:\Program Files\Huawei\DevEco Studio
版本：6.1.1.280
```

内置工具：

```text
ohpm: 6.1.2.268
hvigor: 6.24.2
```

deveco-cli：

```text
源码仓库版本：0.4.0
npm 发布版：1.0.0
```

## 4. 已执行操作

### 4.1 克隆仓库

位置：

```text
C:\Users\SowrJam\Desktop\工作空间\_tools\deveco-code
C:\Users\SowrJam\Desktop\工作空间\_tools\deveco-cli
```

### 4.2 构建源码版 deveco-cli

命令：

```bash
npm install
npm run build
```

结果：

```text
构建成功
生成 dist/cli.js
```

### 4.3 安装 npm 发布版 deveco-cli

命令：

```bash
npm install @deveco/deveco-cli@latest --prefix C:\Users\SowrJam\Desktop\工作空间\_tools\deveco-cli-npm
```

结果：

```text
安装成功
版本：1.0.0
包含 docs.zip
```

## 5. 构建 Link Storm HarmonyOS 工程

工程原始位置：

```text
C:\Users\SowrJam\Desktop\工作空间\Link-Storm\apps\harmony-link-storm
```

问题：

```text
Hvigor 不接受项目路径包含中文 “工作空间”
```

临时解决：

```text
复制工程到 ASCII 路径：
C:\Users\SowrJam\Desktop\workspace_ascii_build2\harmony-link-storm
```

构建命令：

```bash
node C:\Users\SowrJam\Desktop\工作空间\_tools\deveco-cli\dist\cli.js build --modules entry
```

构建结果：

```text
构建成功
生成 HAP：
C:\Users\SowrJam\Desktop\workspace_ascii_build2\harmony-link-storm\entry\build\default\outputs\default\entry-default-unsigned.hap
```

产物大小：

```text
96225 bytes
```

## 6. 构建过程中修复的问题

### 6.1 缺少 hvigor 配置

错误：

```text
Hvigor config file hvigor/hvigor-config.json5 does not exist.
```

修复：

```text
新增 hvigor/hvigor-config.json5
更新根 hvigorfile.ts
更新 entry/hvigorfile.ts
```

### 6.2 modelVersion 不一致

错误：

```text
hvigor-config.json5 是 6.0.2
oh-package.json5 是 5.0.0
```

修复：

```text
根 oh-package.json5 modelVersion 改为 6.0.2
补充 devDependencies
```

### 6.3 ArkTS 不允许对象展开

错误：

```text
arkts-no-spread
It is possible to spread only arrays or classes derived from arrays
```

位置：

```text
entry/src/main/ets/repository/IdeaRepository.ets
```

修复：

```text
将 { ...idea, ...patch } 改为显式字段赋值
```

## 7. 当前剩余警告

构建成功但仍有警告：

1. `build-profile.json5` 建议显式配置 `targetSdkVersion`。
2. `entry/oh-package.json5` 的 version 提示 SemVer 规范问题。
3. `preferences.getPreferences/get/put/flush` 可能抛异常，需要更细的异常处理。
4. `getContext` 已废弃，需要后续替换为推荐写法。
5. 未配置签名，所以产物是 unsigned HAP。

这些不是当前构建阻塞项。

## 8. 文档检索验证

源码版 `deveco-cli` 没有 `docs.zip`，运行 `docs search` 会报：

```text
docs.zip not found
```

npm 发布版 `@deveco/deveco-cli@1.0.0` 包含 `docs.zip`，文档检索可用。

已验证命令：

```bash
node C:\Users\SowrJam\Desktop\工作空间\_tools\deveco-cli-npm\node_modules\@deveco\deveco-cli\dist\cli.js docs search Preferences relationalStore Canvas AVRecorder --limit 8
```

结果：

```text
可搜索到 Preferences、relationalStore、Canvas 等官方文档。
```

## 9. 设备与模拟器

设备列表：

```text
No active devices
```

已有模拟器：

```text
Huawei_Tablet  stopped  tablet  HarmonyOS 6.0.0(20)
Mate 70 Pro    stopped  phone   HarmonyOS 6.0.0(20)
```

模拟器镜像：

```text
HarmonyOS 6.0.0(20) phone/tablet 等镜像已下载
HarmonyOS 5.1.0(18) phone 镜像已下载
```

启动模拟器时被许可证阻止：

```text
Emulator license agreements are not accepted yet.
```

需要用户在交互终端执行：

```bash
devecocli emulator license accept
```

或使用本地 CLI：

```bash
node C:\Users\SowrJam\Desktop\工作空间\_tools\deveco-cli-npm\node_modules\@deveco\deveco-cli\dist\cli.js emulator license accept
```

接受后才能继续：

```bash
devecocli emulator start "Huawei_Tablet"
devecocli run --module entry
```

## 10. 后续建议

1. 将 HarmonyOS 工程放到纯 ASCII 路径，或后续把主仓库迁移到不含中文的路径。
2. 使用 npm 发布版 `@deveco/deveco-cli` 作为日常工具，因为它包含 `docs.zip`。
3. 用户手动接受模拟器许可证后，再继续验证 `run`。
4. 下一轮修复剩余 ArkTS 警告：
   - `targetSdkVersion`
   - `getContext` 废弃
   - Preferences 异常处理
   - 签名配置
