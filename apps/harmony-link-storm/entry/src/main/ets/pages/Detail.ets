import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
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

  build() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('鎯虫硶璇︽儏')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text(this.idea ? ideaTypeLabel(this.idea.type) : 'Loading')
            .fontSize(12)
            .fontColor('#667085')
        }
        Blank()
        Button('杩斿洖')
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

        if (this.idea.asset?.previewPath && this.idea.asset.type === 'handwriting') {
          Image(this.idea.asset.previewPath)
            .width('100%')
            .height(220)
            .objectFit(ImageFit.Contain)
        }
        if (this.idea.asset?.type === 'handwriting') {
          Column({ space: 6 }) {
            Text(`鎵嬪啓绗旂敾锛?{this.idea.asset.strokes?.length ?? 0}`)
              .fontSize(12)
              .fontColor('#667085')
            if (this.idea.asset.previewPath) {
              Text(this.idea.asset.previewPath)
                .fontSize(12)
                .fontColor('#667085')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
        }
        if (this.isPlayableAudio()) {
          Row({ space: 8 }) {
            Button('鎾斁')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                try {
                  await audioPlaybackService.play(this.assetLocalUri);
                  this.playbackState = audioPlaybackService.getState();
                } catch (err) {
                  this.status = `鎾斁澶辫触锛?{String(err)}`;
                }
              })
            Button('鏆傚仠')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                try {
                  await audioPlaybackService.pause();
                  this.playbackState = audioPlaybackService.getState();
                } catch (err) {
                  this.status = `鏆傚仠澶辫触锛?{String(err)}`;
                }
              })
            Button('鍋滄')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                try {
                  await audioPlaybackService.stop();
                  this.playbackState = audioPlaybackService.getState();
                } catch (err) {
                  this.status = `鍋滄澶辫触锛?{String(err)}`;
                }
              })
          }
          Text(`鎾斁鐘舵€侊細${this.playbackState}`)
            .fontColor('#667085')
            .fontSize(12)
        }
        this.AssetSection()
        TextInput({ text: this.title, placeholder: '鏍囬' })
          .onChange((value: string) => this.title = value)
        TextInput({ text: this.tags, placeholder: '鏍囩锛岄€楀彿鍒嗛殧' })
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
        TextInput({ text: this.sourceTitle, placeholder: '鏉ユ簮鏍囬' })
          .onChange((value: string) => this.sourceTitle = value)
        TextInput({ text: this.sourceUrl, placeholder: '鏉ユ簮閾炬帴' })
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
          Button(this.idea.isFavorite ? '鍙栨秷鏀惰棌' : '鏀惰棌')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              const current = this.idea;
              if (!current) {
                return;
              }
              await ideaRepository.update(this.ideaId, { isFavorite: !current.isFavorite });
              await this.reload();
            })
          Button(this.idea.isArchived ? '鍙栨秷褰掓。' : '褰掓。')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              const current = this.idea;
              if (!current) {
                return;
              }
              await ideaRepository.update(this.ideaId, { isArchived: !current.isArchived });
              await this.reload();
            })
          Button('淇濆瓨')
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
          Button('鍒犻櫎')
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
      this.status = '缂哄皯鎯虫硶 ID';
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

  private isPlayableAudio(): boolean {
    return this.assetType === 'audio' && this.assetLocalUri.length > 0;
  }
}

