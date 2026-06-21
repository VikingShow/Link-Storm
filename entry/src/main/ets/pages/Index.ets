import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import image from '@ohos.multimedia.image';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import { systemShare } from '@kit.ShareKit';
import { CaptureDraftState, HandwritingStroke, Idea, IdeaAiOutput, IdeaBackupPreview, IdeaDraft, IdeaFolder, IdeaTag, IdeaType, ImportConflictStrategy, StrokePoint, ideaTypeLabel } from '../model/IdeaModels';
import { audioRecordService } from '../services/AudioRecordService';
import { PermissionService } from '../services/PermissionService';
import { floatingBallService } from '../services/FloatingBallService';
import { ideaRepository } from '../repository/IdeaRepository';
import { shareCaptureService } from '../services/ShareCaptureService';
import { IdeaCardComponent } from '../components/IdeaCardComponent';
import { CaptureEditorComponent } from '../components/CaptureEditorComponent';
import { FolderManagerComponent } from '../components/FolderManagerComponent';
import { TagManagerComponent } from '../components/TagManagerComponent';

class ImportSelectOption {
  value: string = '';
  constructor(value: string) {
    this.value = value;
  }
}

class ExportSelectOption {
  value: string = '';
  index: number = 0;
  constructor(value: string, index: number) {
    this.value = value;
    this.index = index;
  }
}

interface ShareOptions {
  previewMode: systemShare.SharePreviewMode;
  selectionMode: systemShare.SelectionMode;
}

interface IdeaPatch {
  isFavorite?: boolean;
  isArchived?: boolean;
  syncStatus?: string;
}

const PHONE_BREAKPOINT = 680;
const TABLET_BREAKPOINT = 1100;
const CANVAS_WIDTH = 900;
const PAGE_ROOT_ID = 'link-storm-page-root';

@Entry
@Component
struct Index {
  @State private activeType: IdeaType = IdeaType.DOCUMENT;
  @State private layoutMode: string = 'desktop';
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
  @State private selectedIds: string[] = [];
  @State private ideas: Idea[] = [];
  @State private importStrategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER;
  @State private floatingBallStatus: string = '悬浮球已关闭';
  @State private handwritingStrokes: HandwritingStroke[] = [];
  @State private currentStrokePoints: StrokePoint[] = [];
  @State private folders: IdeaFolder[] = [];
  @State private tagsCatalog: IdeaTag[] = [];
  @State private folderNameInput: string = '';
  @State private folderParentInput: string = '';
  @State private editingFolderId: string = '';
  @State private tagNameInput: string = '';
  @State private editingTagId: string = '';
  @State private shareCaptureSummary: string = '';
  @State private sharedAttachmentUris: string[] = [];
  @State private audioRecorderState: string = 'idle';
  @State private refreshing: boolean = false;
  @State private currentTabIndex: number = 0;
  @State private filterExpanded: boolean = false;
  @State private noteExpanded: boolean = false;
  @State private favoriteFilter: boolean = false;
  @State private archivedFilter: boolean = false;
  @State private exportSelectedIndex: number = -1;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await ideaRepository.init(context);
    } catch (err) {
      this.showToast('本地数据库初始化失败：' + String(err));
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
    Column() {
      Navigation() {
        Tabs({ barPosition: this.layoutMode === 'compact' ? BarPosition.End : BarPosition.Start, index: this.currentTabIndex }) {
          TabContent() {
            this.CaptureTab();
          }
          .tabBar($r('app.string.tab_capture'))

          TabContent() {
            this.LibraryTab();
          }
          .tabBar($r('app.string.tab_library'))

          TabContent() {
            this.SettingsTab();
          }
          .tabBar($r('app.string.tab_settings'))
        }
        .barMode(BarMode.Fixed)
        .width('100%')
        .height('100%')
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
      }
      .title('Link Storm')
      .titleMode(NavigationTitleMode.Mini)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_page'))
    .id(PAGE_ROOT_ID)
    .onAreaChange((_oldArea, newArea) => {
      this.applyDefaultMode(Number(newArea.width));
    })
  }

  @Builder
  private CaptureTab() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 2 }) {
            Text(this.deviceHint())
              .fontSize(13)
              .fontColor($r('app.color.brand_primary'))
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.capture_title'))
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Column({ space: 12 }) {
          CaptureEditorComponent({
            activeType: $activeType,
            documentText: $documentText,
            audioStatus: $audioStatus,
            audioPath: $audioPath,
            audioDurationMs: $audioDurationMs,
            audioRecorderState: $audioRecorderState,
            handwritingText: $handwritingText,
            handwritingStrokes: $handwritingStrokes,
            currentStrokePoints: $currentStrokePoints,
            note: this.note,
            onPersistDraft: () => { void this.persistCaptureDraft(); },
            onAudioStart: () => { void this.startAudioCapture(); },
            onAudioPause: () => { void this.pauseAudioCapture(); },
            onAudioResume: () => { void this.resumeAudioCapture(); },
            onAudioStop: () => { void this.stopAudioCapture(); },
            onAudioCancel: () => { void this.cancelAudioCapture(); },
            onHandwritingUndo: () => this.undoHandwritingStroke(),
            onHandwritingClear: () => this.clearHandwriting(),
            onHandwritingSavePreview: () => { void this.persistHandwritingPreview(); },
          })

          if (this.shareCaptureSummary.length > 0) {
            Text(this.shareCaptureSummary)
              .fontSize(13)
              .fontColor($r('app.color.brand_primary'))
              .width('100%')
          }

          Column({ space: 0 }) {
            Row() {
              Text(this.noteExpanded ? '收起备注' : '添加备注')
                .fontSize(14)
                .fontColor($r('app.color.brand_primary'))
                .fontWeight(FontWeight.Medium)
              Text(this.noteExpanded ? ' ▲' : ' ▼')
                .fontSize(12)
                .fontColor($r('app.color.brand_primary'))
            }
            .onClick(() => {
              this.noteExpanded = !this.noteExpanded;
            })
            .width('100%')
            .padding({ top: 8, bottom: 8 })

            if (this.noteExpanded) {
              TextArea({ placeholder: $r('app.string.note_placeholder'), text: this.note })
                .height(76)
                .onChange((value: string) => {
                  this.note = value;
                  void this.persistCaptureDraft();
                })
                .margin({ top: 4 })
            }
          }
          .width('100%')

          Button($r('app.string.save_idea'))
            .fontSize(16)
            .height(44)
            .backgroundColor($r('app.color.brand_primary'))
            .fontColor(Color.White)
            .borderRadius(22)
            .width('100%')
            .onClick(() => { void this.saveDraft(); })
        }
        .padding(16)
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(12)
        .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  @Builder
  private LibraryTab() {
    Column({ space: 12 }) {
      Search({ value: this.search, placeholder: $r('app.string.search_placeholder') })
        .onChange((value: string) => this.search = value)
        .width('100%')

      Text(this.filterSummary())
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')

      Scroll() {
        Row({ space: 6 }) {
          this.ChipFilter('all', $r('app.string.all_types'), this.typeFilter, (v: string) => this.typeFilter = v)
          this.ChipFilter(IdeaType.AUDIO, $r('app.string.type_audio'), this.typeFilter, (v: string) => this.typeFilter = v)
          this.ChipFilter(IdeaType.HANDWRITING, $r('app.string.type_handwriting'), this.typeFilter, (v: string) => this.typeFilter = v)
          this.ChipFilter(IdeaType.DOCUMENT, $r('app.string.type_document'), this.typeFilter, (v: string) => this.typeFilter = v)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Row() {
        Text(this.filterExpanded ? '收起筛选' : '筛选')
          .fontSize(13)
          .fontColor($r('app.color.brand_primary'))
          .fontWeight(FontWeight.Medium)
        Text(this.filterExpanded ? ' ▲' : ' ▼')
          .fontSize(11)
          .fontColor($r('app.color.brand_primary'))
      }
      .onClick(() => {
        this.filterExpanded = !this.filterExpanded;
      })
      .width('100%')
      .padding({ top: 4, bottom: 4 })

      if (this.filterExpanded) {
        Column({ space: 8 }) {
          Row({ space: 12 }) {
            Row({ space: 6 }) {
              Text('收藏')
                .fontSize(13)
                .fontColor(this.favoriteFilter ? $r('app.color.chip_text_selected') : $r('app.color.chip_text_unselected'))
                .backgroundColor(this.favoriteFilter ? $r('app.color.chip_bg_selected') : $r('app.color.chip_bg_unselected'))
                .borderRadius(14)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => this.favoriteFilter = !this.favoriteFilter)
              Text('归档')
                .fontSize(13)
                .fontColor(this.archivedFilter ? $r('app.color.chip_text_selected') : $r('app.color.chip_text_unselected'))
                .backgroundColor(this.archivedFilter ? $r('app.color.chip_bg_selected') : $r('app.color.chip_bg_unselected'))
                .borderRadius(14)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => this.archivedFilter = !this.archivedFilter)
            }

            if (this.folders.length > 0) {
              Select(this.folderSelectOptions())
                .selected(this.folderFilter === 'all' ? 0 : this.folderSelectIndex())
                .value('文件夹')
                .font({ size: 13 })
                .onSelect((index: number) => {
                  const folderId = this.folderIdFromSelectIndex(index);
                  this.folderFilter = folderId;
                })
            }

            if (this.commonTags().length > 0) {
              Select(this.tagSelectOptions())
                .selected(this.tagFilter.length === 0 ? 0 : this.tagSelectIndex())
                .value('标签')
                .font({ size: 13 })
                .onSelect((index: number) => {
                  const tagName = this.tagNameFromSelectIndex(index);
                  this.tagFilter = tagName;
                })
            }
          }
          .width('100%')
        }
        .width('100%')
      }

      Row() {
        if (this.hasActiveFilters()) {
          Button($r('app.string.clear_filters'))
            .fontSize(12)
            .height(28)
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_secondary'))
            .borderRadius(14)
            .padding({ left: 12, right: 12 })
            .onClick(() => this.resetFilters())
        }
        Blank()
        Text(this.filteredIdeas().length.toString() + ' 条')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.chip_text_selected'))
          .backgroundColor($r('app.color.chip_bg_selected'))
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      }
      .width('100%')

      if (this.selectedIds.length > 0) {
        this.BatchActionBar();
      }

      Refresh({ refreshing: $$this.refreshing }) {
        List({ space: 10 }) {
          ForEach(this.filteredIdeas(), (idea: Idea) => {
            ListItem() {
              IdeaCardComponent({
                idea: idea,
                isSelected: this.isSelected(idea.id),
                onOpen: (id: string) => { void this.openDetail(id); },
                onToggleFavorite: (id: string) => { void this.toggleFavorite(id); },
                onToggleArchive: (id: string) => { void this.toggleArchive(id); },
                onDelete: (id: string) => { this.confirmDelete(id, true); },
                onToggleSelect: (id: string) => this.toggleSelected(id),
              })
            }
            .swipeAction({ end: this.DeleteSwipeAction(idea.id) })
          }, (idea: Idea) => idea.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .lanes(this.layoutMode === 'desktop' ? { minLength: 320, maxLength: 480 } : { minLength: 0, maxLength: 0 })
      }
      .onRefreshing(async () => {
        await this.reloadIdeas();
        this.refreshing = false;
      })
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }

  @Builder
  private ChipFilter(value: string, label: string | Resource, currentValue: string, onChange: (v: string) => void) {
    Text(label)
      .fontSize(13)
      .fontColor(currentValue === value ? $r('app.color.chip_text_selected') : $r('app.color.chip_text_unselected'))
      .backgroundColor(currentValue === value ? $r('app.color.chip_bg_selected') : $r('app.color.chip_bg_unselected'))
      .borderRadius(14)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .onClick(() => onChange(value))
  }

  @Builder
  private DeleteSwipeAction(ideaId: string) {
    Row() {
      Button($r('app.string.delete'))
        .fontSize(13)
        .height('100%')
        .width(70)
        .backgroundColor($r('app.color.danger'))
        .fontColor(Color.White)
        .borderRadius(0)
        .onClick(() => {
          this.confirmDelete(ideaId, true);
        })
    }
  }

  @Builder
  private BatchActionBar() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('已选 ' + this.selectedIds.length.toString() + ' 条')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Button($r('app.string.select_all_visible'))
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(14)
          .onClick(() => this.selectVisible())
        Button($r('app.string.clear_selection'))
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(14)
          .onClick(() => this.clearSelection())
        Button($r('app.string.batch_favorite'))
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(14)
          .onClick(() => { void this.batchUpdate({ isFavorite: true }); })
        Button($r('app.string.batch_archive'))
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(14)
          .onClick(() => { void this.batchUpdate({ isArchived: true }); })
        Button($r('app.string.batch_delete'))
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.danger_bg'))
          .fontColor($r('app.color.danger'))
          .borderRadius(14)
          .onClick(() => { this.confirmBatchDelete(); })
      }
      .width('100%')
    }
    .padding(12)
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(12)
    .shadow({ radius: 12, color: $r('app.color.card_shadow'), offsetY: -2 })
  }

  @Builder
  private SettingsTab() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Text($r('app.string.settings_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          this.PermissionRow()
        }
        .padding(16)
        .width('100%')
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(12)
        .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })

        Column({ space: 10 }) {
          Text('导出与备份')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          Row({ space: 8 }) {
            Select([
              new ExportSelectOption('导出 JSON', 0),
              new ExportSelectOption('导出 Markdown', 1),
              new ExportSelectOption('导出纯文本', 2),
              new ExportSelectOption('ZIP 完整备份', 3),
              new ExportSelectOption('分享...', 4),
            ])
              .selected(this.exportSelectedIndex)
              .value('选择操作')
              .font({ size: 13 })
              .onSelect((index: number) => {
                this.exportSelectedIndex = index;
                void this.handleExportSelect(index);
              })
          }
        }
        .padding(16)
        .width('100%')
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(12)
        .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })

        Column({ space: 10 }) {
          Text($r('app.string.import_file'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Row({ space: 8 }) {
            Button($r('app.string.import_file'))
              .fontSize(13)
              .height(36)
              .backgroundColor($r('app.color.brand_primary'))
              .fontColor(Color.White)
              .borderRadius(18)
              .onClick(async () => {
                try {
                  const result = await ideaRepository.importFromFile(this.importStrategy);
                  const conflictHint = result.conflicts.length > 0 ? '，冲突' + result.conflicts.length.toString() : '';
                  this.showToast('导入完成：新增' + result.inserted.toString() + '，更新' + result.updated.toString() + '，跳过' + result.skipped.toString() + conflictHint);
                  await this.reloadIdeas();
                } catch (err) {
                  this.showToast('导入失败：' + String(err));
                }
              })
            Select([new ImportSelectOption('保守导入'), new ImportSelectOption('强制覆盖')])
              .selected(this.importStrategy === ImportConflictStrategy.KEEP_NEWER ? 0 : 1)
              .value('冲突策略')
              .font({ size: 13 })
              .onSelect((index: number) => {
                this.importStrategy = index === 0 ? ImportConflictStrategy.KEEP_NEWER : ImportConflictStrategy.FORCE_OVERWRITE;
              })
          }
        }
        .padding(16)
        .width('100%')
        .backgroundColor($r('app.color.surface_primary'))
        .borderRadius(12)
        .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })

        FolderManagerComponent({
          folders: $folders,
          folderNameInput: $folderNameInput,
          folderParentInput: $folderParentInput,
          editingFolderId: $editingFolderId,
          folderId: $folderId,
          onReload: () => { void this.reloadIdeas(); },
        })

        TagManagerComponent({
          tagsCatalog: $tagsCatalog,
          tagNameInput: $tagNameInput,
          editingTagId: $editingTagId,
          tagFilter: $tagFilter,
          onReload: () => { void this.reloadIdeas(); },
        })
      }
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  @Builder
  private PermissionRow() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text($r('app.string.retry_mic'))
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button($r('app.string.retry_mic'))
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.brand_primary'))
          .borderRadius(14)
          .onClick(async () => { await this.retryMicrophonePermission(); })
      }
      .width('100%')

      Row({ space: 8 }) {
        Text($r('app.string.floating_ball_toggle'))
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.floatingBallEnabled() })
          .onChange(async (isOn: boolean) => {
            try {
              if (isOn) {
                const bundleName = await floatingBallService.enable();
                this.floatingBallStatus = '悬浮球已启用：' + bundleName;
              } else {
                await floatingBallService.disable();
                this.floatingBallStatus = '悬浮球已关闭';
              }
            } catch (err) {
              this.floatingBallStatus = '悬浮球不可用：' + String(err);
            }
          })
          .selectedColor($r('app.color.brand_primary'))
      }
      .width('100%')

      Text('麦克风：' + this.audioStatus + ' | 悬浮球：' + this.floatingBallStatus)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private confirmDelete(ideaId: string, deleteAssets: boolean): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.delete_confirm_title'),
      message: $r('app.string.delete_confirm_message'),
      primaryButton: {
        value: $r('app.string.confirm'),
        action: async () => {
          await ideaRepository.delete(ideaId, deleteAssets);
          await this.reloadIdeas();
          this.showToast('想法已删除');
        }
      },
      secondaryButton: {
        value: $r('app.string.cancel'),
        action: () => {}
      }
    });
  }

  private confirmBatchDelete(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.delete_confirm_title'),
      message: '确定要删除选中的 ' + this.selectedIds.length.toString() + ' 条记录吗？此操作不可撤销。',
      primaryButton: {
        value: $r('app.string.confirm'),
        action: async () => {
          await this.batchDelete();
          this.showToast('批量删除完成');
        }
      },
      secondaryButton: {
        value: $r('app.string.cancel'),
        action: () => {}
      }
    });
  }

  private deviceHint(): string {
    if (this.layoutMode === 'compact') {
      return '手机模式';
    }
    return '桌面模式';
  }

  private applyDefaultMode(width: number): void {
    if (width < PHONE_BREAKPOINT) {
      this.activeType = IdeaType.AUDIO;
      this.layoutMode = 'compact';
    } else if (width >= PHONE_BREAKPOINT && width < TABLET_BREAKPOINT) {
      this.activeType = IdeaType.HANDWRITING;
      this.layoutMode = 'compact';
    } else {
      this.activeType = IdeaType.DOCUMENT;
      this.layoutMode = 'desktop';
    }
  }

  private floatingBallEnabled(): boolean {
    return floatingBallService.isEnabled();
  }

  private async retryMicrophonePermission(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const permissionService = PermissionService.getInstance(context);
    const granted = await permissionService.requestMicrophone();
    this.audioStatus = granted ? '麦克风权限已就绪' : '未获得麦克风权限，可继续使用文档、手写、分享和截图兜底';
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
    const savedIdea = await ideaRepository.save(draft);
    await this.importSharedAttachmentIfNeeded(savedIdea);
    const saveStatus = this.shareCaptureSummary.length > 0 ? this.shareCaptureSummary : '想法已保存：' + savedIdea.id;
    this.resetForm(true);
    await ideaRepository.clearCaptureDraft();
    shareCaptureService.clearShareState();
    this.shareCaptureSummary = saveStatus;
    this.sharedAttachmentUris = [];
    await this.reloadIdeas();
    this.showToast('想法已保存');
    this.currentTabIndex = 1;
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
    this.sharedAttachmentUris = [];
    this.clearHandwriting(preserveHandwritingPreview);
    this.noteExpanded = false;
  }

  private async restoreCaptureDraft(): Promise<void> {
    const draft = await ideaRepository.loadCaptureDraft();
    if (!draft) return;
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
      const folderOk = this.folderFilter === 'all' || this.folderMatchesFilter(idea.folderId, this.folderFilter);
      const favOk = !this.favoriteFilter || idea.isFavorite;
      const archOk = !this.archivedFilter || idea.isArchived;
      const text = [
        idea.title, idea.plainText, idea.note,
        idea.context.title, idea.context.url, idea.context.manualNote,
        idea.tags.join(' '), this.folderNameForSearch(idea.folderId)
      ].join(' ').toLowerCase();
      return typeOk && tagOk && folderOk && favOk && archOk && (!query || text.includes(query));
    });
  }

  private folderNameForSearch(folderId: string | undefined): string {
    if (!folderId) return '';
    const folder = this.folders.find((item: IdeaFolder) => item.id === folderId);
    return folder ? this.folderDisplayName(folder) : '';
  }

  private folderMatchesFilter(folderId: string | undefined, filterId: string): boolean {
    if (!folderId) return false;
    if (folderId === filterId) return true;
    const folder = this.folders.find((item: IdeaFolder) => item.id === folderId);
    return folder?.parentId === filterId;
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
    if (!folder.parentId) return folder.name;
    const parent = this.folders.find((item: IdeaFolder) => item.id === folder.parentId);
    return parent ? parent.name + ' / ' + folder.name : folder.name;
  }

  private folderSelectOptions(): ImportSelectOption[] {
    const options: ImportSelectOption[] = [new ImportSelectOption('全部文件夹')];
    for (const folder of this.displayFolders()) {
      options.push(new ImportSelectOption(this.folderDisplayName(folder)));
    }
    return options;
  }

  private folderSelectIndex(): number {
    if (this.folderFilter === 'all') return 0;
    const displayFolders = this.displayFolders();
    for (let i = 0; i < displayFolders.length; i++) {
      if (displayFolders[i].id === this.folderFilter) return i + 1;
    }
    return 0;
  }

  private folderIdFromSelectIndex(index: number): string {
    if (index === 0) return 'all';
    const displayFolders = this.displayFolders();
    if (index - 1 < displayFolders.length) return displayFolders[index - 1].id;
    return 'all';
  }

  private tagSelectOptions(): ImportSelectOption[] {
    const options: ImportSelectOption[] = [new ImportSelectOption('全部标签')];
    for (const tag of this.commonTags()) {
      options.push(new ImportSelectOption(tag));
    }
    return options;
  }

  private tagSelectIndex(): number {
    if (this.tagFilter.length === 0) return 0;
    const tags = this.commonTags();
    for (let i = 0; i < tags.length; i++) {
      if (tags[i] === this.tagFilter) return i + 1;
    }
    return 0;
  }

  private tagNameFromSelectIndex(index: number): string {
    if (index === 0) return '';
    const tags = this.commonTags();
    if (index - 1 < tags.length) return tags[index - 1];
    return '';
  }

  private hasActiveFilters(): boolean {
    return this.search.trim().length > 0 || this.typeFilter !== 'all' || this.tagFilter.length > 0 || this.folderFilter !== 'all' || this.favoriteFilter || this.archivedFilter;
  }

  private resetFilters(): void {
    this.search = '';
    this.typeFilter = 'all';
    this.tagFilter = '';
    this.folderFilter = 'all';
    this.favoriteFilter = false;
    this.archivedFilter = false;
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
    for (const id of visibleIds) { next.add(id); }
    this.selectedIds = Array.from(next.values());
  }

  private clearSelection(): void {
    this.selectedIds = [];
  }

  private async toggleFavorite(id: string): Promise<void> {
    const idea = this.ideas.find((item: Idea) => item.id === id);
    if (!idea) return;
    await ideaRepository.update(id, { isFavorite: !idea.isFavorite });
    await this.reloadIdeas();
  }

  private async toggleArchive(id: string): Promise<void> {
    const idea = this.ideas.find((item: Idea) => item.id === id);
    if (!idea) return;
    await ideaRepository.update(id, { isArchived: !idea.isArchived });
    await this.reloadIdeas();
  }

  private async openDetail(id: string): Promise<void> {
    try {
      await this.getUIContext().getRouter().pushUrl({
        url: 'pages/Detail',
        params: { id: id }
      });
    } catch (err) {
      this.showToast('打开详情失败：' + String(err));
    }
  }

  private async batchUpdate(patch: IdeaPatch): Promise<void> {
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

  private filterSummary(): string {
    const parts: string[] = [];
    if (this.search.trim().length > 0) parts.push('搜索 "' + this.search.trim() + '"');
    if (this.typeFilter !== 'all') parts.push('类型 ' + ideaTypeLabel(this.typeFilter as IdeaType));
    if (this.tagFilter.length > 0) parts.push('标签 ' + this.tagFilter);
    if (this.folderFilter !== 'all') parts.push('文件夹 ' + this.folderFilter);
    if (this.favoriteFilter) parts.push('收藏');
    if (this.archivedFilter) parts.push('归档');
    return parts.length > 0 ? '当前筛选：' + parts.join('，') : '当前显示全部记录。';
  }

  private clearHandwriting(preservePreview: boolean = false): void {
    this.handwritingStrokes = [];
    this.currentStrokePoints = [];
    if (!preservePreview) {
      this.removeManagedHandwritingPreview();
      this.handwritingPreviewPath = '';
    }
  }

  private undoHandwritingStroke(): void {
    if (this.currentStrokePoints.length > 0) {
      this.currentStrokePoints = [];
    } else if (this.handwritingStrokes.length > 0) {
      this.handwritingStrokes = this.handwritingStrokes.slice(0, this.handwritingStrokes.length - 1);
    }
    void this.persistCaptureDraft();
  }

  private async persistHandwritingPreview(): Promise<void> {
    const previousPreviewPath = this.handwritingPreviewPath;
    try {
      const previewPath = await this.saveHandwritingPreview();
      this.handwritingPreviewPath = previewPath;
      this.handwritingText = '手写预览：' + previewPath;
      if (previousPreviewPath.length > 0 && previousPreviewPath !== previewPath) {
        this.removeManagedHandwritingPreview(previousPreviewPath);
      }
      void this.persistCaptureDraft();
    } catch (err) {
      this.handwritingText = '手写预览保存失败：' + String(err);
      throw err as Error;
    }
  }

  private async saveHandwritingPreview(): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const previewDir = context.filesDir + '/idea-attachments';
    this.ensureDirectoryQuietly(previewDir);
    const previewPath = previewDir + '/handwriting-' + Date.now().toString() + '.png';
    await this.saveComponentSnapshot('handwriting-canvas', previewPath);
    return previewPath;
  }

  private async saveComponentSnapshot(componentId: string, path: string): Promise<void> {
    const pixelMap = await this.captureComponentSnapshotGuarded(componentId);
    try {
      const data = await this.packPixelMapToPngGuarded(pixelMap);
      this.writeBinaryFile(path, data);
    } finally {
      await this.releasePixelMapQuietly(pixelMap);
    }
  }

  private async captureComponentSnapshotGuarded(componentId: string): Promise<image.PixelMap> {
    return await this.getUIContext().getComponentSnapshot().get(componentId);
  }

  private async packPixelMapToPngGuarded(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const packer = image.createImagePacker();
    return await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
  }

  private writeBinaryFile(path: string, data: ArrayBuffer): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(file.fd, data);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private ensureDirectoryQuietly(path: string): void {
    try { fileIo.mkdirSync(path); } catch { /* ignore */ }
  }

  private async releasePixelMapQuietly(pixelMap: image.PixelMap): Promise<void> {
    try { await pixelMap.release(); } catch { /* ignore */ }
  }

  private removeManagedHandwritingPreview(pathToRemove?: string): void {
    const targetPath = pathToRemove ?? this.handwritingPreviewPath;
    if (targetPath.length === 0) return;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (targetPath.startsWith(context.filesDir) && fileIo.accessSync(targetPath)) {
        fileIo.unlinkSync(targetPath);
      }
    } catch { /* ignore */ }
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
      this.audioStatus = '录音完成 ' + Math.round(result.durationMs / 1000).toString() + ' 秒';
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
    return prefix + ': ' + detail;
  }

  private applyShareCapture(): void {
    const shareState = shareCaptureService.getShareState();
    if (shareState.capturedAt.length === 0) return;
    if (shareState.title.length > 0 && this.title.length === 0) this.title = shareState.title;
    if (shareState.sharedText.length > 0 && this.documentText.length === 0) this.documentText = shareState.sharedText;
    if (shareState.url.length > 0 && this.sourceUrl.length === 0) this.sourceUrl = shareState.url;
    if (shareState.sourceApp.length > 0 && this.sourceTitle.length === 0) this.sourceTitle = shareState.sourceApp;
    if (shareState.attachments.length > 0 && this.note.length === 0) this.note = '分享附件：' + shareState.attachments.join(', ');
    this.sharedAttachmentUris = shareState.attachments;
    const attachmentHint = shareState.attachments.length > 0 ? '，附件 ' + shareState.attachments.length.toString() + ' 个' : '';
    this.shareCaptureSummary = '分享已接收：' + shareState.contextType + attachmentHint;
  }

  private async importSharedAttachmentIfNeeded(idea: Idea): Promise<void> {
    if (idea.asset || this.sharedAttachmentUris.length === 0) return;
    const attachmentUri = this.firstLocalSharedAttachment();
    if (attachmentUri.length === 0) {
      this.shareCaptureSummary = '分享记录已保存，远程链接附件已作为来源保留';
      return;
    }
    try {
      const asset = await ideaRepository.importSharedAttachment(idea.id, attachmentUri);
      if (asset) {
        this.shareCaptureSummary = '分享附件已入库：' + asset.localUri;
      }
    } catch (err) {
      this.shareCaptureSummary = '分享记录已保存，附件入库失败：' + String(err);
    }
  }

  private firstLocalSharedAttachment(): string {
    for (const uri of this.sharedAttachmentUris) {
      if (uri.startsWith('file://') || uri.startsWith('/') || uri.startsWith('content://')) return uri;
    }
    return '';
  }

  private async shareIdeasAsPlainText(): Promise<void> {
    const items = this.shareTargetIdeas();
    await this.shareTextContent(this.buildShareText(items), 'Link Storm', '分享' + items.length.toString() + '条本地想法');
  }

  private async shareIdeasAsMarkdown(): Promise<void> {
    const items = this.shareTargetIdeas();
    await this.shareTextContent(this.buildMarkdownExport(items), 'Link Storm Markdown', 'Markdown 导出 ' + items.length.toString() + ' 条本地想法');
  }

  private async shareBackupArchive(path: string): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.ZIP_ARCHIVE,
      uri: fileUri.getUriFromPath(path),
      title: 'Link Storm ZIP 备份',
      description: 'Link Storm 本地想法备份包'
    });
    const controller = new systemShare.ShareController(shareData);
    const options: ShareOptions = { previewMode: systemShare.SharePreviewMode.DEFAULT, selectionMode: systemShare.SelectionMode.SINGLE };
    await controller.show(context, options);
  }

  private backupPreviewSummary(preview: IdeaBackupPreview): string {
    return '备份预览：来源 ' + preview.sourceDevice + '，想法 ' + preview.ideaCount.toString() + '，文件夹 ' + preview.folderCount.toString() + '，标签 ' + preview.tagCount.toString() + '，AI ' + preview.aiOutputCount.toString() + '，附件 ' + preview.attachmentCount.toString();
  }

  private async exportIdeasAsPlainTextFile(): Promise<string> {
    return ideaRepository.exportPlainTextToFile(this.buildPlainTextExport(this.shareTargetIdeas()));
  }

  private async exportIdeasAsMarkdownFile(): Promise<string> {
    return ideaRepository.exportMarkdownToFile(this.buildMarkdownExport(this.shareTargetIdeas()));
  }

  private async shareTextContent(content: string, title: string, description: string): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: content,
      title: title,
      description: description
    });
    const controller = new systemShare.ShareController(shareData);
    const options: ShareOptions = { previewMode: systemShare.SharePreviewMode.DEFAULT, selectionMode: systemShare.SelectionMode.SINGLE };
    await controller.show(context, options);
  }

  private shareTargetIdeas(): Idea[] {
    if (this.selectedIds.length > 0) return this.ideas.filter((idea: Idea) => this.selectedIds.includes(idea.id));
    return this.filteredIdeas();
  }

  private async handleExportSelect(index: number): Promise<void> {
    try {
      if (index === 0) {
        const summary = await ideaRepository.exportSummary();
        const uri = await ideaRepository.exportToFile();
        this.showToast('已导出：' + uri + '（' + summary + '）');
      } else if (index === 1) {
        const uri = await this.exportIdeasAsMarkdownFile();
        this.showToast('Markdown 已导出：' + uri);
      } else if (index === 2) {
        const uri = await this.exportIdeasAsPlainTextFile();
        this.showToast('TXT 已导出：' + uri);
      } else if (index === 3) {
        const archivePath = await ideaRepository.exportBackupZip({});
        this.showToast('ZIP备份已生成：' + archivePath);
      } else if (index === 4) {
        await this.shareIdeasAsPlainText();
        this.showToast('已打开系统分享面板');
      }
    } catch (err) {
      this.showToast('操作失败：' + String(err));
    }
    this.exportSelectedIndex = -1;
  }

  private buildShareText(items: Idea[]): string {
    if (items.length === 0) return 'Link Storm 当前没有可分享的记录。';
    const lines: string[] = ['Link Storm 分享', '共 ' + items.length.toString() + ' 条记录', ''];
    for (const idea of items.slice(0, 20)) {
      lines.push('- ' + idea.title);
      if (idea.tags.length > 0) lines.push('  标签: ' + idea.tags.join(', '));
      if (idea.context.title.length > 0 || idea.context.url.length > 0) lines.push('  来源: ' + idea.context.title + (idea.context.url ? ' ' + idea.context.url : ''));
    }
    return lines.join('\n');
  }

  private buildPlainTextExport(items: Idea[]): string {
    if (items.length === 0) return 'Link Storm\n\n当前没有可导出的记录。\n';
    const lines: string[] = ['Link Storm 导出', '导出时间：' + new Date().toLocaleString(), '记录数量：' + items.length.toString(), ''];
    for (const idea of items) {
      lines.push(idea.title);
      lines.push('类型：' + ideaTypeLabel(idea.type));
      lines.push('创建时间：' + new Date(idea.createdAt).toLocaleString());
      if (idea.tags.length > 0) lines.push('标签：' + idea.tags.join('、'));
      if (idea.context.title.length > 0) lines.push('来源标题：' + idea.context.title);
      if (idea.context.url.length > 0) lines.push('来源链接：' + idea.context.url);
      lines.push('');
      lines.push(idea.plainText || idea.note || '没有正文。');
      lines.push('---');
    }
    return lines.join('\n');
  }

  private buildMarkdownExport(items: Idea[]): string {
    if (items.length === 0) return '# Link Storm\n\n当前没有可导出的记录。\n';
    const lines: string[] = ['# Link Storm 导出', '', '导出时间：' + new Date().toLocaleString(), '记录数量：' + items.length.toString(), ''];
    for (const idea of items) {
      lines.push('## ' + this.escapeMarkdown(idea.title));
      lines.push('- 类型：' + ideaTypeLabel(idea.type));
      lines.push('- 创建时间：' + new Date(idea.createdAt).toLocaleString());
      if (idea.tags.length > 0) lines.push('- 标签：' + idea.tags.map((tag: string) => this.escapeMarkdown(tag)).join('、'));
      if (idea.context.url.length > 0) lines.push('- 来源链接：' + idea.context.url);
      lines.push('');
      lines.push(idea.plainText || idea.note || '没有正文。');
      lines.push('');
    }
    return lines.join('\n');
  }

  private escapeMarkdown(value: string): string {
    return value.replace(/([\\`*_{}\[\]()#+\-.!|>])/g, '\\$1');
  }
}
