import router from '@ohos.router';
import Want from '@ohos.app.ability.Want';
import { common } from '@kit.AbilityKit';
import fileUri from '@ohos.file.fileuri';
import { Idea, IdeaAsset, IdeaFolder, IdeaTag, ideaTypeLabel } from '../model/IdeaModels';
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

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as DetailParams;
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
          Text(this.idea ? ideaTypeLabel(this.idea.type) : 'Loading')
            .fontSize(12)
            .fontColor('#667085')
        }
        Blank()
        Button('返回')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => router.back())
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
        if (this.folders.length > 0) {
          Row({ space: 8 }) {
            ForEach(this.folders, (folder: IdeaFolder) => {
              Button(folder.name)
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
        } else {
          TextInput({ text: this.folderId, placeholder: 'folder id' })
            .onChange((value: string) => this.folderId = value)
          Button('刷新文件夹')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              await this.refreshFolders();
            })
        }
        TextArea({ text: this.plainText, placeholder: 'plain text' })
          .height(160)
          .onChange((value: string) => this.plainText = value)
        TextArea({ text: this.note, placeholder: 'note' })
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
              this.status = 'saved';
              await this.reload();
            })
          Button('删除')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontColor('#B42318')
            .onClick(async () => {
              await ideaRepository.delete(this.ideaId);
              router.back();
            })
        }

        Text(this.status)
          .fontColor('#667085')
          .fontSize(12)
      } else {
        Text(this.status || 'record not found')
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
      this.status = 'record not found';
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
  }

  private getAsset(): IdeaAsset | undefined {
    return this.idea?.asset;
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

  private async refreshFolders(): Promise<void> {
    this.folders = await ideaRepository.listFolders();
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

