import Want from '@ohos.app.ability.Want';
import { LengthMetrics } from '@kit.ArkUI';
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
  @State private sourceSectionExpanded: boolean = true;
  @State private categorySectionExpanded: boolean = false;

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
    Navigation() {
      Scroll() {
        Column({ space: 16 }) {
          if (this.idea) {
            this.MainEditArea();
            this.SourceAttachmentSection();
            this.CategoryInfoSection();
            this.BottomActions();
          } else {
            Column() {
              Text(this.status || '记录不存在')
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }
        }
        .padding(16)
        .constraintSize({ maxWidth: 720 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .title($r('app.string.detail_title'))
    .titleMode(NavigationTitleMode.Mini)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_page'))
  }

  @Builder
  private MainEditArea() {
    Column({ space: 12 }) {
      TextInput({ text: this.title, placeholder: $r('app.string.title_placeholder') })
        .onChange((value: string) => this.title = value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)

      TextInput({ text: this.tags, placeholder: $r('app.string.tags_placeholder') })
        .onChange((value: string) => this.tags = value)

      if (this.tagsCatalog.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
          ForEach(this.tagsCatalog, (tag: IdeaTag) => {
            Text(tag.name)
              .fontSize(13)
              .fontColor(this.hasTag(tag.name) ? $r('app.color.chip_text_selected') : $r('app.color.chip_text_unselected'))
              .backgroundColor(this.hasTag(tag.name) ? $r('app.color.chip_bg_selected') : $r('app.color.chip_bg_unselected'))
              .borderRadius(14)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .onClick(() => this.toggleTag(tag.name))
          }, (tag: IdeaTag) => tag.id)
        }
      }

      TextArea({ text: this.plainText, placeholder: $r('app.string.plain_text_placeholder') })
        .height(160)
        .onChange((value: string) => this.plainText = value)

      TextArea({ text: this.note, placeholder: $r('app.string.note_placeholder') })
        .height(100)
        .onChange((value: string) => this.note = value)
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
  }

  @Builder
  private SourceAttachmentSection() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.section_source_attachments'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.sourceSectionExpanded ? '\u25B2' : '\u25BC')
          .fontSize(12)
          .fontColor($r('app.color.icon_secondary'))
          .onClick(() => this.getUIContext()?.animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
            this.sourceSectionExpanded = !this.sourceSectionExpanded;
          }))
      }
      .width('100%')

      if (this.sourceSectionExpanded) {
        Column({ space: 8 }) {
          Text(this.contextSummary())
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          Row({ space: 8 }) {
            Button($r('app.string.open_source'))
              .fontSize(13)
              .height(32)
              .padding({ left: 12, right: 12 })
              .backgroundColor($r('app.color.brand_primary'))
              .fontColor(Color.White)
              .borderRadius(16)
              .enabled(this.normalizeSourceUrl(this.sourceUrl || this.idea?.context.url || '').length > 0)
              .onClick(() => { void this.openSourceUrl(); })
            if ((this.sourceUrl || this.idea?.context.url || '').length > 0) {
              Text(this.sourceUrl || this.idea?.context.url)
                .fontSize(12)
                .fontColor($r('app.color.brand_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }

          Row() {
            Text(this.idea ? ideaTypeLabel(this.idea.type) : '')
              .fontSize(12)
              .fontColor($r('app.color.chip_text_selected'))
              .backgroundColor($r('app.color.chip_bg_selected'))
              .borderRadius(12)
              .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          }

          if (this.getAsset()?.previewPath && this.getAsset()?.type === 'handwriting') {
            Image(this.getAsset()!.previewPath)
              .width('100%')
              .height(220)
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
          }

          if (this.getAsset()?.type === 'handwriting') {
            Text(`\u270D\uFE0F 手写笔画：${this.getAsset()?.strokes?.length ?? 0}`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }

          if (this.isPlayableAudio()) {
            Row({ space: 8 }) {
              Button($r('app.string.play_audio'))
                .fontSize(13)
                .height(32)
                .padding({ left: 12, right: 12 })
                .backgroundColor($r('app.color.brand_primary'))
                .fontColor(Color.White)
                .borderRadius(16)
                .onClick(() => { void this.playAudioAsset(); })
              Button($r('app.string.pause_audio'))
                .fontSize(13)
                .height(32)
                .padding({ left: 12, right: 12 })
                .backgroundColor($r('app.color.surface_secondary'))
                .fontColor($r('app.color.text_primary'))
                .borderRadius(16)
                .enabled(this.playbackState === 'playing')
                .onClick(() => { void this.pauseAudioAsset(); })
              Button($r('app.string.stop_audio'))
                .fontSize(13)
                .height(32)
                .padding({ left: 12, right: 12 })
                .backgroundColor($r('app.color.surface_secondary'))
                .fontColor($r('app.color.text_primary'))
                .borderRadius(16)
                .enabled(this.playbackState !== 'idle')
                .onClick(() => { void this.stopAudioAsset(); })
            }
          }

          Row({ space: 8 }) {
            Button($r('app.string.replace_attachment'))
              .fontSize(12)
              .height(28)
              .padding({ left: 10, right: 10 })
              .backgroundColor($r('app.color.surface_secondary'))
              .fontColor($r('app.color.brand_primary'))
              .borderRadius(14)
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
            if (this.assetLocalUri.length > 0) {
              Button($r('app.string.remove_attachment'))
                .fontSize(12)
                .height(28)
                .padding({ left: 10, right: 10 })
                .backgroundColor($r('app.color.danger_bg'))
                .fontColor($r('app.color.danger'))
                .borderRadius(14)
                .onClick(async () => {
                  try {
                    await ideaRepository.clearIdeaAsset(this.ideaId);
                    this.attachmentStatus = '已移除附件';
                    await this.reload();
                  } catch (err) {
                    this.attachmentStatus = `移除失败：${String(err)}`;
                  }
                })
            }
          }

          if (this.attachmentStatus.length > 0) {
            Text(this.attachmentStatus)
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseOut }))
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
  }

  @Builder
  private CategoryInfoSection() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.section_category_info'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.categorySectionExpanded ? '\u25B2' : '\u25BC')
          .fontSize(12)
          .fontColor($r('app.color.icon_secondary'))
          .onClick(() => this.getUIContext()?.animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
            this.categorySectionExpanded = !this.categorySectionExpanded;
          }))
      }
      .width('100%')

      if (this.categorySectionExpanded) {
        Column({ space: 8 }) {
          if (this.folders.length > 0) {
            Row({ space: 6 }) {
              Text($r('app.string.no_folder'))
                .fontSize(13)
                .fontColor(this.folderId.length === 0 ? $r('app.color.chip_text_selected') : $r('app.color.chip_text_unselected'))
                .backgroundColor(this.folderId.length === 0 ? $r('app.color.chip_bg_selected') : $r('app.color.chip_bg_unselected'))
                .borderRadius(14)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => this.folderId = '')
              Scroll() {
                Row({ space: 6 }) {
                  ForEach(this.displayFolders(), (folder: IdeaFolder) => {
                    Text(this.folderDisplayName(folder))
                      .fontSize(13)
                      .fontColor(this.folderId === folder.id ? $r('app.color.chip_text_selected') : $r('app.color.chip_text_unselected'))
                      .backgroundColor(this.folderId === folder.id ? $r('app.color.chip_bg_selected') : $r('app.color.chip_bg_unselected'))
                      .borderRadius(14)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .onClick(() => this.folderId = folder.id)
                  }, (folder: IdeaFolder) => folder.id)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .layoutWeight(1)
            }
          }

          if (this.idea) {
            Column({ space: 4 }) {
              Row({ space: 6 }) {
                Text($r('app.string.created_at'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.idea.createdAt)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
              Row({ space: 6 }) {
                Text($r('app.string.updated_at'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.idea.updatedAt)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')
          }
        }
        .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseOut }))
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
  }

  @Builder
  private BottomActions() {
    Row({ space: 10 }) {
      Button($r('app.string.save_changes'))
        .fontSize(16)
        .height(44)
        .backgroundColor($r('app.color.brand_primary'))
        .fontColor(Color.White)
        .borderRadius(22)
        .layoutWeight(1)
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
          this.showToast('已保存');
          await this.reload();
        })

      if (this.idea) {
        Button(this.idea.isFavorite ? '\u2665' : '\u2661')
          .fontSize(20)
          .width(44)
          .height(44)
          .backgroundColor(this.idea.isFavorite ? $r('app.color.danger_bg') : $r('app.color.surface_secondary'))
          .fontColor(this.idea.isFavorite ? $r('app.color.danger') : $r('app.color.icon_secondary'))
          .borderRadius(22)
          .onClick(async () => {
            await ideaRepository.update(this.ideaId, { isFavorite: !this.idea?.isFavorite });
            await this.reload();
          })

        Button(this.idea.isArchived ? '\u{1F4C2}' : '\u{1F4C1}')
          .fontSize(18)
          .width(44)
          .height(44)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.icon_secondary'))
          .borderRadius(22)
          .onClick(async () => {
            await ideaRepository.update(this.ideaId, { isArchived: !this.idea?.isArchived });
            await this.reload();
          })

        Button('\u{1F5D1}')
          .fontSize(18)
          .width(44)
          .height(44)
          .backgroundColor($r('app.color.danger_bg'))
          .fontColor($r('app.color.danger'))
          .borderRadius(22)
          .onClick(() => {
            this.confirmDelete();
          })
      }
    }
    .width('100%')
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message, duration: 2000 });
  }

  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.delete_confirm_title'),
      message: $r('app.string.delete_confirm_message'),
      primaryButton: {
        value: $r('app.string.confirm'),
        action: async () => {
          await ideaRepository.delete(this.ideaId);
          this.backToList();
        }
      },
      secondaryButton: {
        value: $r('app.string.cancel'),
        action: () => {}
      }
    });
  }

  private async reload(): Promise<void> {
    if (!this.ideaId) { this.status = '缺少想法 ID'; return; }
    const loaded = await ideaRepository.getById(this.ideaId);
    if (!loaded) { this.status = '记录不存在'; this.idea = undefined; return; }
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

  private backToList(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      this.status = `返回失败：${String(err)}`;
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
    } catch (err) {
      this.syncPlaybackState();
      this.status = this.formatPlaybackError('暂停失败', err);
    }
  }

  private async stopAudioAsset(): Promise<void> {
    try {
      await audioPlaybackService.stop();
      this.syncPlaybackState();
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
    return `${prefix}: ${serviceError.length > 0 ? serviceError : String(err)}`;
  }

  private parseTags(): string[] {
    return this.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
  }

  private hasTag(tag: string): boolean {
    return this.parseTags().includes(tag);
  }

  private toggleTag(tag: string): void {
    const current = new Set(this.parseTags());
    if (current.has(tag)) { current.delete(tag); } else { current.add(tag); }
    this.tags = Array.from(current.values()).join(', ');
  }

  private buildAssetPatch(): IdeaAsset | undefined {
    if (!this.assetLocalUri && !this.assetMimeType && !this.assetPreviewPath && !this.assetType) return undefined;
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
      if (!result.some((item: IdeaFolder) => item.id === folder.id)) result.push(folder);
    }
    return result;
  }

  private folderDisplayName(folder: IdeaFolder): string {
    if (!folder.parentId) return folder.name;
    const parent = this.folders.find((item: IdeaFolder) => item.id === folder.parentId);
    return parent ? `${parent.name} / ${folder.name}` : folder.name;
  }

  private async refreshTags(): Promise<void> {
    this.tagsCatalog = await ideaRepository.listTags();
  }

  private contextSummary(): string {
    if (!this.idea) return '';
    const parts: string[] = [];
    if (this.idea.context.title.length > 0) parts.push(this.idea.context.title);
    if (this.idea.context.url.length > 0) parts.push(this.idea.context.url);
    if (parts.length === 0) return '无来源链接，已保存为手动上下文。';
    return parts.join(' \u00B7 ');
  }

  private async openSourceUrl(): Promise<void> {
    const normalized = this.normalizeSourceUrl(this.sourceUrl || this.idea?.context.url || '');
    if (!normalized) { this.status = '没有可打开的来源链接'; return; }
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
    if (!normalized) { this.attachmentStatus = '没有可打开的附件'; return; }
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
    if (!trimmed) return '';
    if (trimmed.startsWith('file://')) return new fileUri.FileUri(trimmed).path;
    return trimmed;
  }

  private normalizeSourceUrl(value: string): string {
    const trimmed = value.trim();
    if (!trimmed) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    return `https://${trimmed}`;
  }

  private isPlayableAudio(): boolean {
    return this.assetType === 'audio' && this.assetLocalUri.length > 0;
  }
}
