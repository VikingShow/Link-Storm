import Want from '@ohos.app.ability.Want';
import { common } from '@kit.AbilityKit';
import fileUri from '@ohos.file.fileuri';
import { Idea, IdeaAiOutput, IdeaAsset, IdeaFolder, IdeaTag, ideaTypeLabel } from '../model/IdeaModels';
import { ideaRepository } from '../repository/IdeaRepository';
import { audioPlaybackService } from '../services/AudioPlaybackService';

interface DetailParams {
  id?: string;
}

@Entry
@Component
struct Detail {
  @State private ideaId: string = '';
  @State private idea: Idea | undefined = undefined;
  @State private title: string = '';
  @State private tags: string = '';
  @State private note: string = '';
  @State private plainText: string = '';
  @State private sourceTitle: string = '';
  @State private sourceUrl: string = '';
  @State private folderId: string = '';
  @State private folders: IdeaFolder[] = [];
  @State private tagsCatalog: IdeaTag[] = [];
  @State private assetLocalUri: string = '';
  @State private assetMimeType: string = '';
  @State private assetDurationMs: number = 0;
  @State private assetPreviewPath: string = '';
  @State private assetType: string = '';
  @State private playbackState: string = 'idle';
  @State private status: string = '';
  @State private attachmentStatus: string = '';
  @State private aiOutputs: IdeaAiOutput[] = [];
  @State private aiDraftType: string = 'summary';
  @State private aiDraftContent: string = '';
  @State private aiStatusMessage: string = '';

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as DetailParams;
    this.ideaId = params.id ?? '';
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    audioPlaybackService.setContext(context);
    await this.refreshFolders();
    await this.refreshTags();
    await this.reload();
  }

  aboutToDisappear(): void {
    void audioPlaybackService.release();
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('想法详情')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text(this.idea ? ideaTypeLabel(this.idea.type) : '加载中')
            .fontSize(12)
            .fontColor('#667085')
        }
        Blank()
        Button('返回')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => this.backToList())
      }
      .width('100%')

      if (this.idea) {
        Column({ space: 4 }) {
          Text('来源上下文')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
          Text(this.contextSummary())
            .fontSize(12)
            .fontColor('#667085')
          Row({ space: 8 }) {
            Button('打开来源')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .enabled(this.normalizeSourceUrl(this.sourceUrl || this.idea.context.url).length > 0)
              .onClick(async () => {
                await this.openSourceUrl();
              })
            if ((this.sourceUrl || this.idea.context.url).length > 0) {
              Text(this.sourceUrl || this.idea.context.url)
                .fontSize(12)
                .fontColor('#136F63')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          if (this.idea.context.manualNote.length > 0) {
            Text(this.idea.context.manualNote)
              .fontSize(12)
              .fontColor('#667085')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .padding(12)
        .width('100%')
        .backgroundColor('#FBFCFD')
        .border({ width: 1, color: '#D8DDE6' })
        .borderRadius(8)

        if (this.getAsset()?.previewPath && this.getAsset()?.type === 'handwriting') {
          Image(this.getAsset()!.previewPath)
            .width('100%')
            .height(220)
            .objectFit(ImageFit.Contain)
        }
        if (this.getAsset()?.type === 'handwriting') {
          Column({ space: 6 }) {
            Text(`手写笔画：${this.getAsset()?.strokes?.length ?? 0}`)
              .fontSize(12)
              .fontColor('#667085')
            if (this.getAsset()?.previewPath) {
              Row({ space: 8 }) {
                Text(this.getAsset()!.previewPath)
                  .fontSize(12)
                  .fontColor('#667085')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Button('打开预览')
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .onClick(async () => {
                    await this.openPreviewAttachment();
                  })
              }
            }
          }
        }
        if (this.isPlayableAudio()) {
          Row({ space: 8 }) {
            Button('播放')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                await this.playAudioAsset();
              })
            Button('暂停')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .enabled(this.playbackState === 'playing')
              .onClick(async () => {
                await this.pauseAudioAsset();
              })
            Button('停止')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .enabled(this.playbackState !== 'idle')
              .onClick(async () => {
                await this.stopAudioAsset();
              })
          }
          Text(`播放状态：${this.playbackState}`)
            .fontColor('#667085')
            .fontSize(12)
        }
        this.AssetSection()
        this.AiOutputSection()
        TextInput({ text: this.title, placeholder: '标题' })
          .onChange((value: string) => this.title = value)
        TextInput({ text: this.tags, placeholder: '标签，逗号分隔' })
          .onChange((value: string) => this.tags = value)
        if (this.tagsCatalog.length > 0) {
          Row({ space: 6 }) {
            ForEach(this.tagsCatalog, (tag: IdeaTag) => {
              Button(tag.name)
                .buttonStyle(ButtonStyleMode.NORMAL)
                .backgroundColor(this.hasTag(tag.name) ? '#E0F2EE' : '#FFFFFF')
                .fontColor(this.hasTag(tag.name) ? '#0B4F47' : '#697386')
                .onClick(() => this.toggleTag(tag.name))
            }, (tag: IdeaTag) => tag.id)
          }
        }
        TextInput({ text: this.sourceTitle, placeholder: '来源标题' })
          .onChange((value: string) => this.sourceTitle = value)
        TextInput({ text: this.sourceUrl, placeholder: '来源链接' })
          .onChange((value: string) => this.sourceUrl = value)
          Text('文件夹')
          .fontSize(12)
          .fontColor('#667085')
        this.DetailFolderPicker()
        TextArea({ text: this.plainText, placeholder: '正文' })
          .height(160)
          .onChange((value: string) => this.plainText = value)
        TextArea({ text: this.note, placeholder: '备注' })
          .height(120)
          .onChange((value: string) => this.note = value)

        Row({ space: 10 }) {
          Button(this.idea.isFavorite ? '取消收藏' : '收藏')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              const current = this.idea;
              if (!current) {
                return;
              }
              await ideaRepository.update(this.ideaId, { isFavorite: !current.isFavorite });
              await this.reload();
            })
          Button(this.idea.isArchived ? '取消归档' : '归档')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              const current = this.idea;
              if (!current) {
                return;
              }
              await ideaRepository.update(this.ideaId, { isArchived: !current.isArchived });
              await this.reload();
            })
          Button('保存')
            .backgroundColor('#136F63')
            .fontColor(Color.White)
            .onClick(async () => {
              await ideaRepository.update(this.ideaId, {
                title: this.title,
                plainText: this.plainText,
                note: this.note,
                tags: this.parseTags(),
                folderId: this.folderId || undefined,
                context: {
                  title: this.sourceTitle,
                  url: this.sourceUrl,
                  manualNote: this.note,
                  capturedAt: this.idea ? this.idea.context.capturedAt : new Date().toISOString()
                },
                asset: this.buildAssetPatch()
              });
              this.status = '已保存';
              await this.reload();
            })
          Button('删除')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontColor('#B42318')
            .onClick(async () => {
              await ideaRepository.delete(this.ideaId);
              this.backToList();
            })
          Button('仅删记录')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontColor('#B54708')
            .onClick(async () => {
              await ideaRepository.delete(this.ideaId, false);
              this.backToList();
            })
        }

        Text(this.status)
          .fontColor('#667085')
          .fontSize(12)
      } else {
        Text(this.status || '记录不存在')
      }
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  private async reload(): Promise<void> {
    if (!this.ideaId) {
      this.status = '缺少想法 ID';
      return;
    }
    const loaded = await ideaRepository.getById(this.ideaId);
    if (!loaded) {
      this.status = '记录不存在';
      this.idea = undefined;
      return;
    }
    this.idea = loaded;
    this.title = loaded.title;
    this.tags = loaded.tags.join(', ');
    this.note = loaded.note;
    this.plainText = loaded.plainText;
    this.sourceTitle = loaded.context.title;
    this.sourceUrl = loaded.context.url;
    this.folderId = loaded.folderId ?? '';
    this.assetLocalUri = loaded.asset?.localUri ?? '';
    this.assetMimeType = loaded.asset?.mimeType ?? '';
    this.assetDurationMs = loaded.asset?.durationMs ?? 0;
    this.assetPreviewPath = loaded.asset?.previewPath ?? '';
    this.assetType = loaded.asset?.type ?? '';
    this.playbackState = audioPlaybackService.getState();
    this.attachmentStatus = '';
    this.status = '';
    await this.reloadAiOutputs();
  }

  private getAsset(): IdeaAsset | undefined {
    return this.idea?.asset;
  }

  private backToList(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      this.status = `返回失败：${String(err)}`;
    }
  }

  private async openPreviewAttachment(): Promise<void> {
    const previewPath = this.getAsset()?.previewPath ?? '';
    if (previewPath.length > 0) {
      await this.openAttachment(previewPath);
    }
  }

  private async playAudioAsset(): Promise<void> {
    try {
      await audioPlaybackService.play(this.assetLocalUri);
      this.syncPlaybackState();
      this.status = '音频播放中';
    } catch (err) {
      this.syncPlaybackState();
      this.status = this.formatPlaybackError('播放失败', err);
    }
  }

  private async pauseAudioAsset(): Promise<void> {
    try {
      await audioPlaybackService.pause();
      this.syncPlaybackState();
      this.status = '音频已暂停';
    } catch (err) {
      this.syncPlaybackState();
      this.status = this.formatPlaybackError('暂停失败', err);
    }
  }

  private async stopAudioAsset(): Promise<void> {
    try {
      await audioPlaybackService.stop();
      this.syncPlaybackState();
      this.status = '音频已停止';
    } catch (err) {
      this.syncPlaybackState();
      this.status = this.formatPlaybackError('停止失败', err);
    }
  }

  private syncPlaybackState(): void {
    this.playbackState = audioPlaybackService.getState();
  }

  private formatPlaybackError(prefix: string, err: Object): string {
    const serviceError = audioPlaybackService.getLastError();
    const detail = serviceError.length > 0 ? serviceError : String(err);
    return `${prefix}: ${detail}`;
  }

  private parseTags(): string[] {
    return this.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
  }

  private hasTag(tag: string): boolean {
    return this.parseTags().includes(tag);
  }

  private toggleTag(tag: string): void {
    const current = new Set(this.parseTags());
    if (current.has(tag)) {
      current.delete(tag);
    } else {
      current.add(tag);
    }
    this.tags = Array.from(current.values()).join(', ');
  }

  @Builder
  private AiOutputSection() {
    Column({ space: 8 }) {
      Text('AI 整理预留')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('结果保存在独立记录中，不覆盖原始想法。')
        .fontSize(12)
        .fontColor('#667085')
      Row({ space: 8 }) {
        this.AiTypeButton('summary')
        this.AiTypeButton('action_items')
        this.AiTypeButton('questions')
        this.AiTypeButton('transcription')
        this.AiTypeButton('ocr')
        this.AiTypeButton('tags')
      }
      TextArea({ text: this.aiDraftContent, placeholder: `录入${this.aiOutputTypeLabel(this.aiDraftType)}结果，原始想法不会被覆盖` })
        .height(90)
        .onChange((value: string) => this.aiDraftContent = value)
      Row({ space: 8 }) {
        Button(`保存${this.aiOutputTypeLabel(this.aiDraftType)}`)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .enabled(this.aiDraftContent.trim().length > 0)
          .onClick(async () => {
            await this.saveAiDraft();
          })
        Button('刷新结果')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            await this.reloadAiOutputs();
          })
      }
      if (this.aiOutputs.length > 0) {
        ForEach(this.aiOutputs, (output: IdeaAiOutput) => {
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Text(this.aiOutputTypeLabel(output.outputType))
                .fontSize(12)
                .fontColor('#136F63')
                .fontWeight(FontWeight.Bold)
              Text(`来源：${output.sourceIdeaIds.join(', ')}`)
                .fontSize(11)
                .fontColor('#667085')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Button('删除')
                .buttonStyle(ButtonStyleMode.NORMAL)
                .fontColor('#B42318')
                .onClick(async () => {
                  await this.deleteAiOutput(output.id);
                })
            }
            Text(output.content)
              .fontSize(13)
              .fontColor('#1F2937')
          }
          .padding(10)
          .width('100%')
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#D8DDE6' })
          .borderRadius(8)
        }, (output: IdeaAiOutput) => output.id)
      }
      if (this.aiStatusMessage.length > 0) {
        Text(this.aiStatusMessage)
          .fontSize(12)
          .fontColor('#667085')
      }
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FBFCFD')
    .border({ width: 1, color: '#D8DDE6' })
    .borderRadius(8)
  }

  private async reloadAiOutputs(): Promise<void> {
    if (!this.ideaId) {
      this.aiOutputs = [];
      return;
    }
    this.aiOutputs = await ideaRepository.listAiOutputs(this.ideaId);
  }

  @Builder
  private AiTypeButton(type: string) {
    Button(`${this.aiOutputTypeLabel(type)} ${this.aiOutputCount(type)}`)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.aiDraftType === type ? '#E0F2EE' : '#FFFFFF')
      .fontColor(this.aiDraftType === type ? '#0B4F47' : '#697386')
      .onClick(() => this.aiDraftType = type)
  }

  private aiOutputCount(type: string): number {
    return this.aiOutputs.filter((output: IdeaAiOutput) => output.outputType === type).length;
  }

  private async saveAiDraft(): Promise<void> {
    const content = this.aiDraftContent.trim();
    if (content.length === 0) {
      return;
    }
    try {
      await ideaRepository.saveAiOutput(this.ideaId, this.aiDraftType, content, [this.ideaId]);
      this.aiDraftContent = '';
      this.aiStatusMessage = `${this.aiOutputTypeLabel(this.aiDraftType)}已保存`;
      await this.reloadAiOutputs();
      await this.reload();
    } catch (err) {
      this.aiStatusMessage = `保存${this.aiOutputTypeLabel(this.aiDraftType)}失败：${String(err)}`;
    }
  }

  private async deleteAiOutput(outputId: string): Promise<void> {
    try {
      await ideaRepository.deleteAiOutput(outputId);
      this.aiStatusMessage = 'AI 结果已删除';
      await this.reloadAiOutputs();
      await this.reload();
    } catch (err) {
      this.aiStatusMessage = `删除 AI 结果失败：${String(err)}`;
    }
  }

  private aiOutputTypeLabel(type: string): string {
    if (type === 'summary') {
      return '摘要';
    }
    if (type === 'transcription') {
      return '转写';
    }
    if (type === 'ocr') {
      return 'OCR';
    }
    if (type === 'action_items') {
      return '行动项';
    }
    if (type === 'questions') {
      return '问题';
    }
    if (type === 'tags') {
      return '自动标签';
    }
    return type;
  }

  @Builder
  private DetailFolderPicker() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button('无文件夹')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(this.folderId.length === 0 ? '#E0F2EE' : '#FFFFFF')
          .fontColor(this.folderId.length === 0 ? '#0B4F47' : '#697386')
          .onClick(() => this.folderId = '')
        ForEach(this.displayFolders(), (folder: IdeaFolder) => {
          Button(this.folderDisplayName(folder))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(this.folderId === folder.id ? '#E0F2EE' : '#FFFFFF')
            .fontColor(this.folderId === folder.id ? '#0B4F47' : '#697386')
            .onClick(() => this.folderId = folder.id)
        }, (folder: IdeaFolder) => folder.id)
      }
      Button('刷新文件夹')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(async () => {
          await this.refreshFolders();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private AssetSection() {
    Column({ space: 8 }) {
      Text('附件与上下文')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text(`类型：${this.assetType || '无'}`)
        .fontSize(12)
        .fontColor('#667085')
      TextInput({ text: this.assetLocalUri, placeholder: '附件本地路径' })
        .onChange((value: string) => this.assetLocalUri = value)
      TextInput({ text: this.assetMimeType, placeholder: 'MimeType' })
        .onChange((value: string) => this.assetMimeType = value)
      TextInput({ text: `${this.assetDurationMs}`, placeholder: '时长（毫秒）' })
        .onChange((value: string) => this.assetDurationMs = Number(value || '0'))
      TextInput({ text: this.assetPreviewPath, placeholder: '预览图路径' })
        .onChange((value: string) => this.assetPreviewPath = value)
      Row({ space: 8 }) {
        Button('选择附件')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            try {
              const asset = await ideaRepository.replaceIdeaAsset(this.ideaId);
              if (asset) {
                this.attachmentStatus = `已选择：${asset.localUri}`;
                await this.reload();
              } else {
                this.attachmentStatus = '已取消选择';
              }
            } catch (err) {
              this.attachmentStatus = `选择失败：${String(err)}`;
            }
          })
        Button('打开附件')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .enabled(this.assetLocalUri.length > 0)
          .onClick(async () => {
            await this.openAttachment(this.assetLocalUri);
          })
        Button('清除附件')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            try {
              await ideaRepository.clearIdeaAsset(this.ideaId);
              this.attachmentStatus = '已清除附件';
              await this.reload();
            } catch (err) {
              this.attachmentStatus = `清除失败：${String(err)}`;
            }
          })
      }
      Row({ space: 8 }) {
        Button('导出附件')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .enabled(this.assetLocalUri.length > 0)
          .onClick(async () => {
            await this.exportCurrentAttachment();
          })
        Button('导出预览图')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .enabled(this.assetPreviewPath.length > 0)
          .onClick(async () => {
            await this.exportPreviewImage();
          })
        Button('导出手写JSON')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .enabled((this.getAsset()?.strokes?.length ?? 0) > 0)
          .onClick(async () => {
            await this.exportHandwritingJson();
          })
      }
      if (this.attachmentStatus.length > 0) {
        Text(this.attachmentStatus)
          .fontSize(12)
          .fontColor('#667085')
      }
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FBFCFD')
    .border({ width: 1, color: '#D8DDE6' })
    .borderRadius(8)
  }

  private buildAssetPatch(): IdeaAsset | undefined {
    if (!this.assetLocalUri && !this.assetMimeType && !this.assetPreviewPath && !this.assetType) {
      return undefined;
    }
    const asset: IdeaAsset = {
      type: this.assetType || 'manual',
      localUri: this.assetLocalUri,
      mimeType: this.assetMimeType || undefined,
      durationMs: this.assetDurationMs > 0 ? this.assetDurationMs : undefined,
      previewPath: this.assetPreviewPath || undefined
    };
    return asset;
  }

  private async exportCurrentAttachment(): Promise<void> {
    const path = this.assetLocalUri;
    if (path.length === 0) {
      this.attachmentStatus = '没有可导出的附件';
      return;
    }
    try {
      const uri = await ideaRepository.exportAttachmentToPickedFile(path, this.exportFileNameForPath(path, 'attachment'), [this.fileSuffixChoice(path)]);
      this.attachmentStatus = `附件已导出：${uri}`;
    } catch (err) {
      this.attachmentStatus = `导出附件失败：${String(err)}`;
    }
  }

  private async exportPreviewImage(): Promise<void> {
    const path = this.assetPreviewPath;
    if (path.length === 0) {
      this.attachmentStatus = '没有可导出的预览图';
      return;
    }
    try {
      const uri = await ideaRepository.exportAttachmentToPickedFile(path, this.exportFileNameForPath(path, 'preview.png'), [this.fileSuffixChoice(path)]);
      this.attachmentStatus = `预览图已导出：${uri}`;
    } catch (err) {
      this.attachmentStatus = `导出预览图失败：${String(err)}`;
    }
  }

  private async exportHandwritingJson(): Promise<void> {
    const asset = this.getAsset();
    if (!asset?.strokes || asset.strokes.length === 0) {
      this.attachmentStatus = '没有可导出的手写笔迹';
      return;
    }
    const payload = JSON.stringify({
      schema: 'link-storm-handwriting',
      version: 1,
      ideaId: this.ideaId,
      exportedAt: new Date().toISOString(),
      strokes: asset.strokes
    }, null, 2);
    try {
      const uri = await ideaRepository.exportTextToPickedFile(payload, `link-storm-handwriting-${this.safeFileName(this.title || this.ideaId)}.json`, ['JSON|json']);
      this.attachmentStatus = `手写 JSON 已导出：${uri}`;
    } catch (err) {
      this.attachmentStatus = `导出手写 JSON 失败：${String(err)}`;
    }
  }

  private exportFileNameForPath(path: string, fallback: string): string {
    const normalized = path.trim();
    const slash = Math.max(normalized.lastIndexOf('/'), normalized.lastIndexOf('\\'));
    const name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    return this.safeFileName(name || fallback);
  }

  private fileSuffixChoice(path: string): string {
    const name = this.exportFileNameForPath(path, 'attachment');
    const dot = name.lastIndexOf('.');
    if (dot < 0 || dot === name.length - 1) {
      return 'File|*';
    }
    const suffix = name.substring(dot + 1);
    return `${suffix.toUpperCase()}|${suffix}`;
  }

  private safeFileName(value: string): string {
    return value.replace(/[\\/:*?"<>|]/g, '_');
  }

  private async refreshFolders(): Promise<void> {
    this.folders = await ideaRepository.listFolders();
  }

  private displayFolders(): IdeaFolder[] {
    const result: IdeaFolder[] = [];
    const roots = this.folders.filter((folder: IdeaFolder) => !folder.parentId);
    for (const root of roots) {
      result.push(root);
      for (const child of this.folders.filter((folder: IdeaFolder) => folder.parentId === root.id)) {
        result.push(child);
      }
    }
    for (const folder of this.folders) {
      if (!result.some((item: IdeaFolder) => item.id === folder.id)) {
        result.push(folder);
      }
    }
    return result;
  }

  private folderDisplayName(folder: IdeaFolder): string {
    if (!folder.parentId) {
      return folder.name;
    }
    const parent = this.folders.find((item: IdeaFolder) => item.id === folder.parentId);
    return parent ? `${parent.name} / ${folder.name}` : folder.name;
  }

  private async refreshTags(): Promise<void> {
    this.tagsCatalog = await ideaRepository.listTags();
  }

  private contextSummary(): string {
    if (!this.idea) {
      return '';
    }
    const parts: string[] = [];
    if (this.idea.context.title.length > 0) {
      parts.push(this.idea.context.title);
    }
    if (this.idea.context.url.length > 0) {
      parts.push(this.idea.context.url);
    }
    if (parts.length === 0) {
      return '无来源链接，已保存为手动上下文。';
    }
    return parts.join(' · ');
  }

  private async openSourceUrl(): Promise<void> {
    const normalized = this.normalizeSourceUrl(this.sourceUrl || this.idea?.context.url || '');
    if (!normalized) {
      this.status = '没有可打开的来源链接';
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want = new Want();
    want.action = 'ohos.want.action.viewData';
    want.entities = ['entity.system.browsable'];
    want.uri = normalized;
    try {
      await context.startAbility(want);
      this.status = '已打开来源链接';
    } catch (err) {
      this.status = `打开来源失败：${String(err)}`;
    }
  }

  private async openAttachment(path: string): Promise<void> {
    const normalized = this.normalizeAttachmentPath(path);
    if (!normalized) {
      this.attachmentStatus = '没有可打开的附件';
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want = new Want();
    want.action = 'ohos.want.action.viewData';
    want.entities = ['entity.system.browsable'];
    want.uri = fileUri.getUriFromPath(normalized);
    try {
      await context.startAbility(want);
      this.attachmentStatus = '已打开附件';
    } catch (err) {
      this.attachmentStatus = `打开附件失败：${String(err)}`;
    }
  }

  private normalizeAttachmentPath(value: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      return '';
    }
    if (trimmed.startsWith('file://')) {
      return new fileUri.FileUri(trimmed).path;
    }
    return trimmed;
  }

  private normalizeSourceUrl(value: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return `https://${trimmed}`;
  }

  private isPlayableAudio(): boolean {
    return this.assetType === 'audio' && this.assetLocalUri.length > 0;
  }
}

