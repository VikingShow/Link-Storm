import { common } from '@kit.AbilityKit';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import image from '@ohos.multimedia.image';
import fileIo from '@ohos.file.fs';
import { systemShare } from '@kit.ShareKit';
import { CaptureDraftState, HandwritingStroke, Idea, IdeaAsset, IdeaDraft, IdeaFolder, IdeaTag, IdeaType, ImportConflictStrategy, StrokePoint, ideaTypeLabel } from '../model/IdeaModels';
import { audioRecordService } from '../services/AudioRecordService';
import { PermissionService } from '../services/PermissionService';
import { floatingBallService } from '../services/FloatingBallService';
import { ideaRepository } from '../repository/IdeaRepository';
import { shareCaptureService } from '../services/ShareCaptureService';

const PHONE_BREAKPOINT = 680;
const TABLET_BREAKPOINT = 1100;
const STROKE_COLOR = '#111827';
const STROKE_WIDTH = 3;
const CANVAS_WIDTH = 900;
const CANVAS_HEIGHT = 240;
const PAGE_ROOT_ID = 'link-storm-page-root';

interface ScreenshotFallbackResult {
  path: string;
  ideaId: string;
}

interface ShareOptions {
  previewMode: systemShare.SharePreviewMode;
  selectionMode: systemShare.SelectionMode;
}

@Entry
@Component
struct Index {
  @State private activeType: IdeaType = IdeaType.DOCUMENT;
  @State private layoutMode: string = 'desktop';
  @State private deviceHint: string = '桌面/二合一尺寸：默认文档';
  @State private title: string = '';
  @State private tags: string = '';
  @State private sourceTitle: string = '';
  @State private sourceUrl: string = '';
  @State private folderId: string = '';
  @State private note: string = '';
  @State private documentText: string = '';
  @State private audioStatus: string = '录音已就绪，可开始采集';
  @State private audioPath: string = '';
  @State private audioDurationMs: number = 0;
  @State private handwritingText: string = '手写板已就绪，可直接书写';
  @State private handwritingPreviewPath: string = '';
  @State private search: string = '';
  @State private typeFilter: string = 'all';
  @State private tagFilter: string = '';
  @State private folderFilter: string = 'all';
  @State private statusFilter: string = 'all';
  @State private selectedIds: string[] = [];
  @State private ideas: Idea[] = [];
  @State private importStatus: string = '';
  @State private importStrategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER;
  @State private exportStatus: string = '';
  @State private screenshotStatus: string = '';
  @State private floatingBallStatus: string = '悬浮球已关闭';
  @State private handwritingStrokes: HandwritingStroke[] = [];
  @State private currentStrokePoints: StrokePoint[] = [];
  @State private folders: IdeaFolder[] = [];
  @State private tagsCatalog: IdeaTag[] = [];
  @State private batchFolderId: string = '';
  @State private batchTagsInput: string = '';
  @State private shareCaptureSummary: string = '';
  @State private audioRecorderState: string = 'idle';
  private handwritingCanvasId: string = 'handwriting-canvas';

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private canvasWidth: number = CANVAS_WIDTH;
  private canvasHeight: number = CANVAS_HEIGHT;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await ideaRepository.init(context);
    } catch (err) {
      this.exportStatus = `本地数据库初始化失败：${String(err)}`;
      return;
    }
    audioRecordService.setContext(context);
    await this.restoreCaptureDraft();
    await this.reloadIdeas();
    await this.reloadFolders();
    await this.reloadTags();
    this.applyShareCapture();
    this.applyDefaultMode(CANVAS_WIDTH);
  }

  aboutToDisappear(): void {
    void this.persistCaptureDraft();
  }

  build() {
    Column({ space: 16 }) {
      this.Header()
      Column({ space: 16 }) {
        if (this.layoutMode === 'compact') {
          Column({ space: 16 }) {
            this.CapturePanel()
            this.LibraryPanel()
          }
          .width('100%')
        } else {
          Row({ space: 16 }) {
            this.CapturePanel()
            this.LibraryPanel()
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
      }
      .layoutWeight(1)
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
    .id(PAGE_ROOT_ID)
    .onAreaChange((_oldArea, newArea) => {
      this.applyDefaultMode(Number(newArea.width));
    })
  }

  @Builder
  private Header() {
    Row() {
      Column() {
        Text('Link Storm')
          .fontColor('#136F63')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
        Text('本地灵感捕捉')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button('导出文件')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(async () => {
          try {
            const summary = await ideaRepository.exportSummary();
            const uri = await ideaRepository.exportToFile();
            this.exportStatus = `已导出：${uri}（${summary}）`;
          } catch (err) {
            this.exportStatus = `导出失败：${String(err)}`;
          }
        })
      Button('分享')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(async () => {
          try {
            await this.shareIdeas();
            this.exportStatus = '已打开系统分享面板';
          } catch (err) {
            this.exportStatus = `分享失败：${String(err)}`;
          }
        })
      Button('截图兜底')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(async () => {
          try {
            const result = await this.captureScreenshotFallback();
            this.screenshotStatus = `已保存截图：${result.path}`;
            this.exportStatus = `截图已入库：${result.ideaId}`;
            await this.reloadIdeas();
          } catch (err) {
            this.screenshotStatus = `截图失败：${String(err)}`;
          }
        })
      Button('导入文件')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(async () => {
          try {
            const result = await ideaRepository.importFromFile(this.importStrategy);
            const conflictHint = result.conflicts.length > 0 ? `，冲突${result.conflicts.length}` : '';
            this.importStatus = `导入完成：新增${result.inserted}，更新${result.updated}，跳过${result.skipped}${conflictHint}`;
            if (result.conflicts.length > 0) {
              this.importStatus = `${this.importStatus}，冲突ID：${result.conflicts.slice(0, 5).join(', ')}`;
            }
            await this.reloadIdeas();
          } catch (err) {
            this.importStatus = `导入失败：${String(err)}`;
          }
        })
      Row({ space: 8 }) {
        Button('保守导入')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(this.importStrategy === ImportConflictStrategy.KEEP_NEWER ? '#136F63' : '#FFFFFF')
          .fontColor(this.importStrategy === ImportConflictStrategy.KEEP_NEWER ? '#FFFFFF' : '#697386')
          .onClick(() => this.importStrategy = ImportConflictStrategy.KEEP_NEWER)
        Button('强制覆盖')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(this.importStrategy === ImportConflictStrategy.FORCE_OVERWRITE ? '#136F63' : '#FFFFFF')
          .fontColor(this.importStrategy === ImportConflictStrategy.FORCE_OVERWRITE ? '#FFFFFF' : '#697386')
          .onClick(() => this.importStrategy = ImportConflictStrategy.FORCE_OVERWRITE)
      }
      Row({ space: 8 }) {
        Button(this.floatingBallEnabled() ? '关闭悬浮球' : '启用悬浮球')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(this.floatingBallEnabled() ? '#136F63' : '#FFFFFF')
          .fontColor(this.floatingBallEnabled() ? '#FFFFFF' : '#697386')
          .onClick(async () => {
            try {
              if (floatingBallService.isEnabled()) {
                await floatingBallService.disable();
                this.floatingBallStatus = '悬浮球已关闭';
              } else {
                const bundleName = await floatingBallService.enable();
                this.floatingBallStatus = `悬浮球已启用：${bundleName}`;
              }
            } catch (err) {
              this.floatingBallStatus = `悬浮球不可用：${String(err)}`;
            }
          })
        Text(this.floatingBallStatus)
          .fontSize(12)
          .fontColor('#697386')
          .layoutWeight(1)
      }
      Row({ space: 8 }) {
        Button('ZIP备份')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            try {
              const archivePath = await ideaRepository.exportBackupZip();
              this.exportStatus = `ZIP备份已生成：${archivePath}`;
            } catch (err) {
              this.exportStatus = `ZIP备份失败：${String(err)}`;
            }
          })
        Button('ZIP导入')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            try {
              const result = await ideaRepository.importBackupZip(this.importStrategy);
              const conflictHint = result.conflicts.length > 0 ? `，冲突 ${result.conflicts.length}` : '';
              this.importStatus = `ZIP导入完成：新增 ${result.inserted}，更新 ${result.updated}，跳过 ${result.skipped}${conflictHint}`;
              await this.reloadIdeas();
            } catch (err) {
              this.importStatus = `ZIP导入失败：${String(err)}`;
            }
          })
      }
    }
    .width('100%')
  }

  @Builder
  private CapturePanel() {
    Column({ space: 12 }) {
      Row() {
        Column() {
          Text(this.deviceHint)
            .fontColor('#136F63')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
          Text('快速记录')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
        this.ModeButton(IdeaType.AUDIO, '语音')
        this.ModeButton(IdeaType.HANDWRITING, '手写')
        this.ModeButton(IdeaType.DOCUMENT, '文档')
      }
      .width('100%')

      TextInput({ placeholder: '标题，可留空自动生成', text: this.title })
        .onChange((value: string) => {
          this.title = value;
          void this.persistCaptureDraft();
        })

      TextInput({ placeholder: '标签，用逗号分隔', text: this.tags })
        .onChange((value: string) => {
          this.tags = value;
          void this.persistCaptureDraft();
        })

      Row({ space: 10 }) {
        TextInput({ placeholder: '文件夹 ID', text: this.folderId })
          .onChange((value: string) => {
            this.folderId = value;
            void this.persistCaptureDraft();
          })
          .layoutWeight(1)
        Button('清空文件夹')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => {
            this.folderId = '';
            void this.persistCaptureDraft();
          })
      }

      Row({ space: 10 }) {
        TextInput({ placeholder: '来源标题', text: this.sourceTitle })
          .onChange((value: string) => {
            this.sourceTitle = value;
            void this.persistCaptureDraft();
          })
          .layoutWeight(1)
        TextInput({ placeholder: '来源链接', text: this.sourceUrl })
          .onChange((value: string) => {
            this.sourceUrl = value;
            void this.persistCaptureDraft();
          })
          .layoutWeight(1)
      }

      this.ActiveCaptureEditor()

      TextArea({ placeholder: '备注：补充上下文或后续行动', text: this.note })
        .height(76)
        .onChange((value: string) => {
          this.note = value;
          void this.persistCaptureDraft();
        })

      Row({ space: 10 }) {
        Button('保存想法')
          .backgroundColor('#136F63')
          .fontColor(Color.White)
          .onClick(async () => this.saveDraft())
        Button('清空')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            this.resetForm();
            await ideaRepository.clearCaptureDraft();
          })
      }
      .width('100%')

      if (this.exportStatus.length > 0) {
        Text(this.exportStatus)
          .fontColor('#697386')
          .fontSize(12)
      }
      if (this.importStatus.length > 0) {
        Text(this.importStatus)
          .fontColor('#697386')
          .fontSize(12)
      }
      if (this.screenshotStatus.length > 0) {
        Text(this.screenshotStatus)
          .fontColor('#697386')
          .fontSize(12)
      }

      this.FolderManagerPanel()
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#D8DDE6' })
    .layoutWeight(1)
  }

  @Builder
  private ModeButton(type: IdeaType, label: string) {
    Button(label)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.activeType === type ? '#E0F2EE' : '#FFFFFF')
      .fontColor(this.activeType === type ? '#0B4F47' : '#697386')
      .onClick(() => {
        this.activeType = type;
        void this.persistCaptureDraft();
      })
  }

  @Builder
  private ActiveCaptureEditor() {
    if (this.activeType === IdeaType.AUDIO) {
      Column({ space: 8 }) {
        Text('语音捕捉')
          .fontWeight(FontWeight.Bold)
          Text(this.audioStatus)
          .fontColor('#697386')
        Row({ space: 8 }) {
          Button('开始录音')
            .backgroundColor('#136F63')
            .fontColor(Color.White)
            .enabled(this.audioRecorderState === 'idle')
            .onClick(async () => {
              await this.startAudioCapture();
            })
          Button('暂停')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.audioRecorderState === 'recording')
            .onClick(async () => {
              await this.pauseAudioCapture();
            })
          Button('继续')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.audioRecorderState === 'paused')
            .onClick(async () => {
              await this.resumeAudioCapture();
            })
          Button('完成')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.audioRecorderState === 'recording' || this.audioRecorderState === 'paused')
            .onClick(async () => {
              await this.stopAudioCapture();
            })
          Button('取消')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.audioRecorderState === 'recording' || this.audioRecorderState === 'paused')
            .onClick(async () => {
              await this.cancelAudioCapture();
            })
        }
        if (this.audioPath.length > 0) {
          Text(this.audioPath)
            .fontSize(12)
            .fontColor('#697386')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .padding(12)
      .width('100%')
      .backgroundColor('#FBFCFD')
      .border({ width: 1, color: '#D8DDE6' })
      .borderRadius(8)
    } else if (this.activeType === IdeaType.HANDWRITING) {
      Column({ space: 8 }) {
        Text('手写捕捉')
          .fontWeight(FontWeight.Bold)
        Text(this.handwritingText)
          .fontColor('#697386')

        Row({ space: 8 }) {
          Button('撤销')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.handwritingStrokes.length > 0)
            .onClick(() => this.undoHandwritingStroke())
          Button('清空')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.handwritingStrokes.length > 0 || this.currentStrokePoints.length > 0)
            .onClick(() => this.clearHandwriting())
          Button('保存预览')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .enabled(this.handwritingStrokes.length > 0)
            .onClick(async () => {
              try {
                await this.persistHandwritingPreview();
              } catch {
                // persistHandwritingPreview already updates handwritingText with the failure.
              }
            })
        }

        Stack() {
            Canvas(this.canvasContext)
              .id(this.handwritingCanvasId)
              .width('100%')
              .height(CANVAS_HEIGHT)
              .backgroundColor('#FFFFFF')
            .onReady(() => {
              this.redrawHandwriting();
            })
            .onTouch((event: TouchEvent) => {
              this.handleCanvasTouch(event);
            })
        }
        .width('100%')
        .height(CANVAS_HEIGHT)
      }
      .padding(12)
      .width('100%')
      .backgroundColor('#FBFCFD')
      .border({ width: 1, color: '#D8DDE6' })
      .borderRadius(8)
    } else {
      TextArea({ placeholder: '写下你的想法、清单、问题或行动计划', text: this.documentText })
        .height(180)
        .onChange((value: string) => this.documentText = value)
    }
  }

  @Builder
  private LibraryPanel() {
    Column({ space: 12 }) {
      Row() {
        Column() {
          Text('本地想法库')
            .fontColor('#136F63')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
          Text('全部记录')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        if (this.hasActiveFilters()) {
          Button('清除筛选')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => this.resetFilters())
        }
        Text(`${this.filteredIdeas().length} 条`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B4F47')
          .backgroundColor('#E0F2EE')
          .borderRadius(12)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      }
      .width('100%')

      TextInput({ placeholder: '搜索标题、标签、正文、来源', text: this.search })
        .onChange((value: string) => this.search = value)

      Text(this.filterSummary())
        .fontSize(12)
        .fontColor('#667085')

      Row({ space: 8 }) {
        this.FilterButton('all', '全部')
        this.FilterButton(IdeaType.AUDIO, '语音')
        this.FilterButton(IdeaType.HANDWRITING, '手写')
        this.FilterButton(IdeaType.DOCUMENT, '文档')
      }
      Row({ space: 8 }) {
        this.StatusButton('all', '全部状态')
        this.StatusButton('favorite', '收藏')
        this.StatusButton('archived', '归档')
        this.StatusButton('active', '未归档')
      }

      if (this.folders.length > 0) {
        Column({ space: 8 }) {
          Text('文件夹')
            .fontSize(12)
            .fontColor('#667085')
          Row({ space: 6 }) {
            this.FolderFilterButton('all', '全部文件夹')
            ForEach(this.folders, (folder: IdeaFolder) => {
              this.FolderFilterButton(folder.id, folder.name)
            }, (folder: IdeaFolder) => folder.id)
          }
        }
      }

      if (this.commonTags().length > 0) {
        Column({ space: 8 }) {
          Text('常用标签')
            .fontSize(12)
            .fontColor('#667085')
          Row({ space: 6 }) {
            this.TagButton('', '全部标签')
            ForEach(this.commonTags(), (tag: string) => {
              this.TagButton(tag, tag)
            }, (tag: string) => tag)
          }
        }
      }

      if (this.tagsCatalog.length > 0) {
        Column({ space: 8 }) {
          Row() {
            Text('标签库')
              .fontSize(12)
              .fontColor('#667085')
            Blank()
            Button('新建标签')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                await ideaRepository.createTag(`标签 ${this.tagsCatalog.length + 1}`);
                await this.reloadTags();
              })
          }
          Row({ space: 6 }) {
            ForEach(this.tagsCatalog, (tag: IdeaTag) => {
              Button(tag.name)
                .buttonStyle(ButtonStyleMode.NORMAL)
                .backgroundColor(this.tagFilter === tag.name ? tag.color : '#FFFFFF')
                .fontColor(this.tagFilter === tag.name ? '#FFFFFF' : '#697386')
                .onClick(() => this.tagFilter = tag.name)
            }, (tag: IdeaTag) => tag.id)
          }
        }
      }

      if (this.selectedIds.length > 0) {
        Row({ space: 8 }) {
          Text(`已选 ${this.selectedIds.length} 条`)
            .fontSize(12)
            .fontColor('#667085')
          Button('全选可见')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => this.selectVisible())
          Button('清除选择')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(() => this.clearSelection())
          Button('批量收藏')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              await this.batchUpdate({ isFavorite: true });
            })
          Button('批量归档')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              await this.batchUpdate({ isArchived: true });
            })
          Button('批量删除')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontColor('#B42318')
            .onClick(async () => {
              await this.batchDelete();
            })
        }

        Column({ space: 8 }) {
          Text('批量整理')
            .fontSize(12)
            .fontColor('#667085')
          Row({ space: 8 }) {
            if (this.folders.length > 0) {
              ForEach(this.folders, (folder: IdeaFolder) => {
                Button(folder.name)
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .backgroundColor(this.batchFolderId === folder.id ? '#E0F2EE' : '#FFFFFF')
                  .fontColor(this.batchFolderId === folder.id ? '#0B4F47' : '#697386')
                  .onClick(() => this.batchFolderId = folder.id)
              }, (folder: IdeaFolder) => folder.id)
            }
            Button('清空归属')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(() => this.batchFolderId = '')
            Button('移动')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                await ideaRepository.assignFolder(this.selectedIds, this.batchFolderId || undefined);
                await this.reloadIdeas();
                this.batchFolderId = '';
              })
          }
          Row({ space: 8 }) {
            if (this.tagsCatalog.length > 0) {
              ForEach(this.tagsCatalog, (tag: IdeaTag) => {
                Button(tag.name)
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .backgroundColor(this.batchTagsInput.includes(tag.name) ? '#E0F2EE' : '#FFFFFF')
                  .fontColor(this.batchTagsInput.includes(tag.name) ? '#0B4F47' : '#697386')
                  .onClick(() => this.toggleBatchTag(tag.name))
              }, (tag: IdeaTag) => tag.id)
            }
            TextInput({ placeholder: '标签，逗号分隔', text: this.batchTagsInput })
              .onChange((value: string) => this.batchTagsInput = value)
            Button('添加标签')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                await ideaRepository.assignTags(this.selectedIds, this.batchTagsInput.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0));
                await this.reloadIdeas();
                this.batchTagsInput = '';
              })
            Button('移除标签')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                await ideaRepository.removeTags(this.selectedIds, this.batchTagsInput.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0));
                await this.reloadIdeas();
                this.batchTagsInput = '';
              })
          }
        }
      }

      List({ space: 10 }) {
        ForEach(this.filteredIdeas(), (idea: Idea) => {
          ListItem() {
            this.IdeaCard(idea)
          }
        }, (idea: Idea) => idea.id)
      }
      .height('100%')
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({ width: 1, color: '#D8DDE6' })
    .layoutWeight(1)
  }

  @Builder
  private FilterButton(value: string, label: string) {
    Button(label)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.typeFilter === value ? '#E0F2EE' : '#FFFFFF')
      .fontColor(this.typeFilter === value ? '#0B4F47' : '#697386')
      .onClick(() => this.typeFilter = value)
  }

  @Builder
  private TagButton(value: string, label: string) {
    Button(label)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.tagFilter === value ? '#136F63' : '#FFFFFF')
      .fontColor(this.tagFilter === value ? '#FFFFFF' : '#697386')
      .onClick(() => this.tagFilter = value)
  }

  @Builder
  private FolderFilterButton(value: string, label: string) {
    Button(label)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.folderFilter === value ? '#E0F2EE' : '#FFFFFF')
      .fontColor(this.folderFilter === value ? '#0B4F47' : '#697386')
      .onClick(() => this.folderFilter = value)
  }

  @Builder
  private StatusButton(value: string, label: string) {
    Button(label)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(this.statusFilter === value ? '#E0F2EE' : '#FFFFFF')
      .fontColor(this.statusFilter === value ? '#0B4F47' : '#697386')
      .onClick(() => this.statusFilter = value)
  }

  @Builder
  private IdeaCard(idea: Idea) {
    Column({ space: 8 }) {
      Row() {
        Text(ideaTypeLabel(idea.type))
          .fontSize(12)
          .fontColor('#0B4F47')
          .backgroundColor('#E0F2EE')
          .borderRadius(12)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        Text(new Date(idea.createdAt).toLocaleString())
          .fontSize(12)
          .fontColor('#697386')
        Blank()
        Button(this.isSelected(idea.id) ? '已选' : '选择')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(this.isSelected(idea.id) ? '#136F63' : '#FFFFFF')
          .fontColor(this.isSelected(idea.id) ? '#FFFFFF' : '#697386')
          .onClick(() => this.toggleSelected(idea.id))
      }

      Text(idea.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Text(this.previewText(idea))
        .fontSize(14)
        .fontColor('#697386')
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.contextSummary(idea))
        .fontSize(12)
        .fontColor('#667085')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (idea.tags.length > 0) {
        Row({ space: 6 }) {
          ForEach(idea.tags, (tag: string) => {
            Text(tag)
              .fontSize(12)
              .fontColor('#0B4F47')
              .backgroundColor('#E0F2EE')
              .borderRadius(10)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }, (tag: string) => tag)
        }
      }

      Row({ space: 8 }) {
        Button('打开')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            try {
              await this.getUIContext().getRouter().pushUrl({
                url: 'pages/Detail',
                params: { id: idea.id }
              });
            } catch (err) {
              this.exportStatus = `打开详情失败：${String(err)}`;
            }
          })
        Button(idea.isFavorite ? '取消收藏' : '收藏')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            await ideaRepository.update(idea.id, { isFavorite: !idea.isFavorite });
            await this.reloadIdeas();
          })
        Button(idea.isArchived ? '取消归档' : '归档')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            await ideaRepository.update(idea.id, { isArchived: !idea.isArchived });
            await this.reloadIdeas();
          })
        Button('删除')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontColor('#B42318')
          .onClick(async () => {
            await ideaRepository.delete(idea.id);
            await this.reloadIdeas();
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .width('100%')
    .backgroundColor(this.isSelected(idea.id) ? '#F0FBF7' : '#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: this.isSelected(idea.id) ? '#136F63' : '#D8DDE6' })
  }

  private applyDefaultMode(width: number): void {
    if (width < PHONE_BREAKPOINT) {
      this.deviceHint = '手机尺寸：默认语音';
      this.activeType = IdeaType.AUDIO;
      this.layoutMode = 'compact';
    } else if (width >= PHONE_BREAKPOINT && width < TABLET_BREAKPOINT) {
      this.deviceHint = '平板尺寸：默认手写';
      this.activeType = IdeaType.HANDWRITING;
      this.layoutMode = 'compact';
    } else {
      this.deviceHint = '桌面/二合一尺寸：默认文档';
      this.activeType = IdeaType.DOCUMENT;
      this.layoutMode = 'desktop';
    }
  }

  private floatingBallEnabled(): boolean {
    return floatingBallService.isEnabled();
  }

  private async saveDraft(): Promise<void> {
    let handwritingPreviewPath = this.handwritingPreviewPath;
    if (this.activeType === IdeaType.HANDWRITING) {
      const previousPreviewPath = handwritingPreviewPath;
      handwritingPreviewPath = await this.saveHandwritingPreview();
      this.handwritingPreviewPath = handwritingPreviewPath;
      if (previousPreviewPath.length > 0 && previousPreviewPath !== handwritingPreviewPath) {
        this.removeManagedHandwritingPreview(previousPreviewPath);
      }
    }
    const draft: IdeaDraft = {
      title: this.title,
      type: this.activeType,
      plainText: this.activeType === IdeaType.DOCUMENT ? this.documentText : '',
      note: this.note,
      tags: this.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0),
      folderId: this.folderId || undefined,
      context: {
        title: this.sourceTitle,
        url: this.sourceUrl,
        manualNote: this.note,
        capturedAt: new Date().toISOString()
      },
      asset: this.activeType === IdeaType.HANDWRITING ? {
        type: 'handwriting',
        localUri: '',
        strokes: this.handwritingStrokes,
        previewPath: handwritingPreviewPath || undefined
      } : this.activeType === IdeaType.AUDIO ? {
        type: 'audio',
        localUri: this.audioPath,
        mimeType: 'audio/mp4',
        durationMs: this.audioDurationMs
      } : undefined
    };

    await ideaRepository.save(draft);
    this.resetForm(true);
    await ideaRepository.clearCaptureDraft();
    shareCaptureService.clearShareState();
    this.shareCaptureSummary = '';
    await this.reloadIdeas();
  }

  private resetForm(preserveHandwritingPreview: boolean = false): void {
    this.title = '';
    this.tags = '';
    this.sourceTitle = '';
    this.sourceUrl = '';
    this.folderId = '';
    this.note = '';
    this.documentText = '';
    this.audioStatus = '录音已就绪，可开始采集';
    this.audioPath = '';
    this.audioDurationMs = 0;
    this.audioRecorderState = 'idle';
    this.handwritingText = '手写板已就绪，可直接书写';
    this.clearHandwriting(preserveHandwritingPreview);
  }

  private async restoreCaptureDraft(): Promise<void> {
    const draft = await ideaRepository.loadCaptureDraft();
    if (!draft) {
      return;
    }
    this.activeType = draft.activeType;
    this.title = draft.title;
    this.tags = draft.tags;
    this.sourceTitle = draft.sourceTitle;
    this.sourceUrl = draft.sourceUrl;
    this.folderId = draft.folderId ?? '';
    this.note = draft.note;
    this.documentText = draft.documentText;
    this.audioStatus = draft.audioStatus;
    this.audioPath = draft.audioPath;
    this.audioDurationMs = draft.audioDurationMs;
    this.audioRecorderState = 'idle';
    this.handwritingText = draft.handwritingText;
    this.handwritingStrokes = draft.handwritingStrokes ?? [];
    this.currentStrokePoints = draft.currentStrokePoints ?? [];
    this.handwritingPreviewPath = draft.handwritingPreviewPath ?? '';
    this.redrawHandwriting();
  }

  private async persistCaptureDraft(): Promise<void> {
    const draft: CaptureDraftState = {
      activeType: this.activeType,
      title: this.title,
      tags: this.tags,
      sourceTitle: this.sourceTitle,
      sourceUrl: this.sourceUrl,
      folderId: this.folderId || undefined,
      note: this.note,
      documentText: this.documentText,
      audioStatus: this.audioStatus,
      audioPath: this.audioPath,
      audioDurationMs: this.audioDurationMs,
      audioRecorderState: this.audioRecorderState,
      handwritingText: this.handwritingText,
      handwritingStrokes: this.handwritingStrokes,
      currentStrokePoints: this.currentStrokePoints,
      handwritingPreviewPath: this.handwritingPreviewPath || undefined,
      savedAt: new Date().toISOString()
    };
    await ideaRepository.saveCaptureDraft(draft);
  }

  private async reloadIdeas(): Promise<void> {
    this.ideas = await ideaRepository.list();
  }

  private async reloadFolders(): Promise<void> {
    this.folders = await ideaRepository.listFolders();
  }

  private async reloadTags(): Promise<void> {
    this.tagsCatalog = await ideaRepository.listTags();
  }

  private filteredIdeas(): Idea[] {
    const query = this.search.trim().toLowerCase();
    return this.ideas.filter((idea: Idea) => {
      const typeOk = this.typeFilter === 'all' || idea.type === this.typeFilter;
      const tagOk = !this.tagFilter || idea.tags.includes(this.tagFilter);
      const folderOk = this.folderFilter === 'all' || idea.folderId === this.folderFilter;
      const statusOk = this.statusFilter === 'all'
        || (this.statusFilter === 'favorite' && idea.isFavorite)
        || (this.statusFilter === 'archived' && idea.isArchived)
        || (this.statusFilter === 'active' && !idea.isArchived);
      const text = [
        idea.title,
        idea.plainText,
        idea.note,
        idea.context.title,
        idea.context.url,
        idea.tags.join(' ')
      ].join(' ').toLowerCase();
      return typeOk && tagOk && folderOk && statusOk && (!query || text.includes(query));
    });
  }

  private hasActiveFilters(): boolean {
    return this.search.trim().length > 0 || this.typeFilter !== 'all' || this.tagFilter.length > 0 || this.folderFilter !== 'all' || this.statusFilter !== 'all';
  }

  private resetFilters(): void {
    this.search = '';
    this.typeFilter = 'all';
    this.tagFilter = '';
    this.folderFilter = 'all';
    this.statusFilter = 'all';
  }

  private isSelected(id: string): boolean {
    return this.selectedIds.includes(id);
  }

  private toggleSelected(id: string): void {
    if (this.isSelected(id)) {
      this.selectedIds = this.selectedIds.filter((item: string) => item !== id);
      return;
    }
    this.selectedIds = this.selectedIds.concat([id]);
  }

  private selectVisible(): void {
    const visibleIds = this.filteredIdeas().map((idea: Idea) => idea.id);
    const next = new Set(this.selectedIds);
    for (const id of visibleIds) {
      next.add(id);
    }
    this.selectedIds = Array.from(next.values());
  }

  private clearSelection(): void {
    this.selectedIds = [];
  }

  private toggleBatchTag(tag: string): void {
    const current = new Set(this.batchTagsInput.split(',').map((item: string) => item.trim()).filter((item: string) => item.length > 0));
    if (current.has(tag)) {
      current.delete(tag);
    } else {
      current.add(tag);
    }
    this.batchTagsInput = Array.from(current.values()).join(', ');
  }

  private async batchUpdate(patch: Partial<Idea>): Promise<void> {
    for (const id of this.selectedIds) {
      await ideaRepository.update(id, patch);
    }
    this.clearSelection();
    await this.reloadIdeas();
  }

  private async batchDelete(): Promise<void> {
    for (const id of this.selectedIds) {
      await ideaRepository.delete(id);
    }
    this.clearSelection();
    await this.reloadIdeas();
  }

  private commonTags(): string[] {
    return this.tagsCatalog.slice(0, 8).map((tag: IdeaTag) => tag.name);
  }

  @Builder
  private FolderManagerPanel() {
    Column({ space: 8 }) {
      Row() {
        Text('文件夹管理')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('新建文件夹')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(async () => {
            await ideaRepository.createFolder(`文件夹 ${this.folders.length + 1}`);
            await this.reloadFolders();
          })
      }
      if (this.folders.length > 0) {
        ForEach(this.folders, (folder: IdeaFolder) => {
          Row() {
            Column({ space: 2 }) {
              Text(folder.name)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
              Text(folder.id)
                .fontSize(11)
                .fontColor('#667085')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            Button('选中')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(() => this.folderId = folder.id)
            Button('改名')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(async () => {
                await ideaRepository.updateFolder(folder.id, { name: `${folder.name}*` });
                await this.reloadFolders();
              })
            Button('删除')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .fontColor('#B42318')
              .onClick(async () => {
                await ideaRepository.deleteFolder(folder.id);
                if (this.folderFilter === folder.id) {
                  this.folderFilter = 'all';
                }
                if (this.folderId === folder.id) {
                  this.folderId = '';
                }
                await this.reloadFolders();
                await this.reloadIdeas();
              })
          }
          .width('100%')
        }, (folder: IdeaFolder) => folder.id)
      } else {
        Text('暂无文件夹，先创建一个。')
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

  private async shareIdeas(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const items = this.selectedIds.length > 0
      ? this.ideas.filter((idea: Idea) => this.selectedIds.includes(idea.id))
      : this.filteredIdeas();
    const content = this.buildShareText(items);
    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: content,
      title: 'Link Storm',
      description: `分享${items.length}条本地想法`
    });
    const controller = new systemShare.ShareController(shareData);
    const options: ShareOptions = {
      previewMode: systemShare.SharePreviewMode.DEFAULT,
      selectionMode: systemShare.SelectionMode.SINGLE
    };
    await controller.show(context, options);
  }

  private async captureScreenshotFallback(): Promise<ScreenshotFallbackResult> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const pixelMap = await componentSnapshot.get(PAGE_ROOT_ID);
    const screenshotPath = `${context.filesDir}/screenshot-${Date.now()}.png`;
    const packer = image.createImagePacker();
    const data = await packer.packing(pixelMap, {
      format: 'image/png',
      quality: 100
    });
    const file = fileIo.openSync(screenshotPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(file.fd, data);
    } finally {
      this.closeFileQuietly(file);
      await this.releasePixelMapQuietly(pixelMap);
    }

    const asset: IdeaAsset = {
      type: 'screenshot',
      localUri: screenshotPath,
      mimeType: 'image/png',
      previewPath: screenshotPath
    };
    const idea = await ideaRepository.save({
      title: this.title || `截图兜底 ${new Date().toLocaleString()}`,
      type: IdeaType.DOCUMENT,
      plainText: this.documentText || '',
      note: this.note || '页面截图兜底',
      tags: this.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0),
      folderId: this.folderId || undefined,
      context: {
        title: this.sourceTitle || '当前页面截图',
        url: this.sourceUrl,
        manualNote: this.note || '页面截图兜底',
        capturedAt: new Date().toISOString()
      },
      asset: asset
    });

    const result: ScreenshotFallbackResult = {
      path: screenshotPath,
      ideaId: idea.id
    };
    return result;
  }

  private buildShareText(items: Idea[]): string {
    if (items.length === 0) {
      return 'Link Storm 当前没有可分享的记录。';
    }
    const lines: string[] = [
      'Link Storm 分享',
      `共 ${items.length} 条记录`,
      ''
    ];
    for (const idea of items.slice(0, 20)) {
      lines.push(`- ${idea.title}`);
      if (idea.tags.length > 0) {
        lines.push(`  标签: ${idea.tags.join(', ')}`);
      }
      if (idea.context.title.length > 0 || idea.context.url.length > 0) {
        lines.push(`  来源: ${idea.context.title}${idea.context.url ? ` ${idea.context.url}` : ''}`);
      }
    }
    return lines.join('\n');
  }

  private previewText(idea: Idea): string {
    if (idea.type === IdeaType.AUDIO) {
      return idea.asset?.localUri ? `语音文件：${idea.asset.localUri}` : '还没有录音文件。';
    }
    if (idea.type === IdeaType.HANDWRITING) {
      return idea.asset?.strokes?.length ? `手写笔画 ${idea.asset.strokes.length} 组` : '还没有手写笔迹或预览图。';
    }
    return idea.plainText || idea.note || '没有正文。';
  }

  private contextSummary(idea: Idea): string {
    const parts: string[] = [];
    if (idea.context.title.length > 0) {
      parts.push(idea.context.title);
    }
    if (idea.context.url.length > 0) {
      parts.push(idea.context.url);
    }
    if (parts.length === 0) {
      parts.push(idea.context.manualNote || '无来源上下文');
    }
    return `来源：${parts.join(' · ')}`;
  }

  private filterSummary(): string {
    const parts: string[] = [];
    if (this.search.trim().length > 0) {
      parts.push(`搜索 "${this.search.trim()}"`);
    }
    if (this.typeFilter !== 'all') {
      parts.push(`类型 ${ideaTypeLabel(this.typeFilter as IdeaType)}`);
    }
    if (this.tagFilter.length > 0) {
      parts.push(`标签 ${this.tagFilter}`);
    }
    if (this.folderFilter !== 'all') {
      parts.push(`文件夹 ${this.folderFilter}`);
    }
    if (this.statusFilter !== 'all') {
      parts.push(`状态 ${this.statusFilter}`);
    }
    return parts.length > 0 ? `当前筛选：${parts.join('，')}` : '当前显示全部记录。';
  }

  private clearHandwriting(preservePreview: boolean = false): void {
    this.handwritingStrokes = [];
    this.currentStrokePoints = [];
    if (!preservePreview) {
      this.removeManagedHandwritingPreview();
      this.handwritingPreviewPath = '';
    }
    this.redrawHandwriting();
  }

  private undoHandwritingStroke(): void {
    if (this.currentStrokePoints.length > 0) {
      this.currentStrokePoints = [];
    } else if (this.handwritingStrokes.length > 0) {
      this.handwritingStrokes = this.handwritingStrokes.slice(0, this.handwritingStrokes.length - 1);
    }
    this.redrawHandwriting();
    void this.persistCaptureDraft();
  }

  private async persistHandwritingPreview(): Promise<void> {
    const previousPreviewPath = this.handwritingPreviewPath;
    try {
      const previewPath = await this.saveHandwritingPreview();
      this.handwritingPreviewPath = previewPath;
      this.handwritingText = `手写预览：${previewPath}`;
      if (previousPreviewPath.length > 0 && previousPreviewPath !== previewPath) {
        this.removeManagedHandwritingPreview(previousPreviewPath);
      }
      void this.persistCaptureDraft();
    } catch (err) {
      this.handwritingText = `手写预览保存失败：${String(err)}`;
      throw err as Error;
    }
  }

  private async saveHandwritingPreview(): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const previewDir = `${context.filesDir}/idea-attachments`;
    fileIo.mkdirSync(previewDir);
    const previewPath = `${previewDir}/handwriting-${Date.now()}.png`;
    const pixelMap = await componentSnapshot.get(this.handwritingCanvasId);
    const packer = image.createImagePacker();
    const data = await packer.packing(pixelMap, {
      format: 'image/png',
      quality: 100
    });
    const file = fileIo.openSync(previewPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(file.fd, data);
    } finally {
      this.closeFileQuietly(file);
      await this.releasePixelMapQuietly(pixelMap);
    }
    return previewPath;
  }

  private closeFileQuietly(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch {
      // Preserve the original screenshot or preview save failure.
    }
  }

  private async releasePixelMapQuietly(pixelMap: image.PixelMap): Promise<void> {
    try {
      await pixelMap.release();
    } catch {
      // Preserve the original screenshot or preview save failure.
    }
  }

  private removeManagedHandwritingPreview(pathToRemove?: string): void {
    const targetPath = pathToRemove ?? this.handwritingPreviewPath;
    if (targetPath.length === 0) {
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (targetPath.startsWith(context.filesDir) && fileIo.accessSync(targetPath)) {
        fileIo.unlinkSync(targetPath);
      }
    } catch {
      // ignore cleanup failures
    }
  }

  private handleCanvasTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }

    const point: TouchObject = event.touches[0];
    const x = point.windowX;
    const y = point.windowY;
    const canvasPoint: StrokePoint = {
      x,
      y,
      t: Date.now(),
      pressure: 1
    };

    if (event.type === TouchType.Down) {
      this.currentStrokePoints = [canvasPoint];
      this.handwritingStrokes = this.handwritingStrokes.concat([{ color: STROKE_COLOR, width: STROKE_WIDTH, points: this.currentStrokePoints }]);
      this.redrawHandwriting();
      void this.persistCaptureDraft();
      return;
    }

    if (event.type === TouchType.Move) {
      if (this.currentStrokePoints.length === 0) {
        this.currentStrokePoints = [canvasPoint];
        this.handwritingStrokes = this.handwritingStrokes.concat([{ color: STROKE_COLOR, width: STROKE_WIDTH, points: this.currentStrokePoints }]);
      } else {
        this.currentStrokePoints.push(canvasPoint);
      }
      this.redrawHandwriting();
      void this.persistCaptureDraft();
      return;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.currentStrokePoints.length > 0) {
        this.currentStrokePoints.push(canvasPoint);
      }
      this.currentStrokePoints = [];
      this.redrawHandwriting();
      void this.persistCaptureDraft();
    }
  }

  private redrawHandwriting(): void {
    const ctx = this.canvasContext;
    ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = STROKE_COLOR;
    ctx.lineWidth = STROKE_WIDTH;

    for (const stroke of this.handwritingStrokes) {
      if (stroke.points.length === 0) {
        continue;
      }
      ctx.beginPath();
      ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
      for (let i = 1; i < stroke.points.length; i++) {
        ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      ctx.stroke();
    }
  }

  private async startAudioCapture(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const permissionService = PermissionService.getInstance(context);
    const granted = await permissionService.requestMicrophone();
    if (!granted) {
      this.audioStatus = '未获得麦克风权限';
      this.syncAudioRecorderState();
      await this.persistCaptureDraft();
      return;
    }
    this.audioStatus = '正在启动录音...';
    try {
      await audioRecordService.start();
      this.audioRecorderState = 'recording';
      this.audioStatus = '录音中';
    } catch (err) {
      this.syncAudioRecorderState();
      this.audioStatus = this.formatAudioError('录音启动失败', err);
    }
    await this.persistCaptureDraft();
  }

  private async pauseAudioCapture(): Promise<void> {
    try {
      await audioRecordService.pause();
      this.audioRecorderState = 'paused';
      this.audioStatus = '录音已暂停';
    } catch (err) {
      this.syncAudioRecorderState();
      this.audioStatus = this.formatAudioError('暂停录音失败', err);
    }
    await this.persistCaptureDraft();
  }

  private async resumeAudioCapture(): Promise<void> {
    try {
      await audioRecordService.resume();
      this.audioRecorderState = 'recording';
      this.audioStatus = '录音中';
    } catch (err) {
      this.syncAudioRecorderState();
      this.audioStatus = this.formatAudioError('继续录音失败', err);
    }
    await this.persistCaptureDraft();
  }

  private async stopAudioCapture(): Promise<void> {
    try {
      const result = await audioRecordService.stop();
      this.audioPath = result.path;
      this.audioDurationMs = result.durationMs;
      this.audioRecorderState = 'idle';
      this.audioStatus = `录音完成 ${Math.round(result.durationMs / 1000)} 秒`;
    } catch (err) {
      this.syncAudioRecorderState();
      this.audioStatus = this.formatAudioError('保存录音失败', err);
    }
    await this.persistCaptureDraft();
  }

  private async cancelAudioCapture(): Promise<void> {
    try {
      await audioRecordService.cancel();
      this.audioRecorderState = 'idle';
      this.audioPath = '';
      this.audioDurationMs = 0;
      this.audioStatus = '录音已取消';
    } catch (err) {
      this.syncAudioRecorderState();
      this.audioStatus = this.formatAudioError('取消录音失败', err);
    }
    await this.persistCaptureDraft();
  }

  private syncAudioRecorderState(): void {
    this.audioRecorderState = audioRecordService.getState();
  }

  private formatAudioError(prefix: string, err: Object): string {
    const serviceError = audioRecordService.getLastError();
    const detail = serviceError.length > 0 ? serviceError : String(err);
    return `${prefix}: ${detail}`;
  }

  private applyShareCapture(): void {
    const shareState = shareCaptureService.getShareState();
    if (shareState.capturedAt.length === 0) {
      return;
    }
    if (shareState.title.length > 0 && this.title.length === 0) {
      this.title = shareState.title;
    }
    if (shareState.sharedText.length > 0 && this.documentText.length === 0) {
      this.documentText = shareState.sharedText;
    }
    if (shareState.url.length > 0 && this.sourceUrl.length === 0) {
      this.sourceUrl = shareState.url;
    }
    if (shareState.sourceApp.length > 0 && this.sourceTitle.length === 0) {
      this.sourceTitle = shareState.sourceApp;
    }
    if (shareState.attachments.length > 0 && this.note.length === 0) {
      this.note = `分享附件：${shareState.attachments.join(', ')}`;
    }
    this.shareCaptureSummary = `分享已接收：${shareState.contextType}`;
  }

}
