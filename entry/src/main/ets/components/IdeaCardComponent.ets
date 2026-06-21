import { LengthMetrics } from '@kit.ArkUI';
import { Idea, IdeaType, ideaTypeLabel } from '../model/IdeaModels';

function defaultIdea(): Idea {
  return {
    id: '', title: '', type: IdeaType.DOCUMENT, plainText: '', note: '', tags: [],
    context: { title: '', url: '', manualNote: '', capturedAt: '' },
    isFavorite: false, isArchived: false, syncStatus: '', aiStatus: '',
    createdAt: '', updatedAt: ''
  };
}

@Component
export struct IdeaCardComponent {
  @Prop idea: Idea = defaultIdea();
  @Prop isSelected: boolean = false;
  @Prop aiSearchText: string = '';
  onOpen: (id: string) => void = () => {};
  onToggleFavorite: (id: string) => void = () => {};
  onToggleArchive: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};
  onDeleteRecordOnly: (id: string) => void = () => {};
  onToggleSelect: (id: string) => void = () => {};
  onSyncStatus: (id: string, status: string) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(ideaTypeLabel(this.idea.type))
          .fontSize(12)
          .fontColor($r('app.color.chip_text_selected'))
          .backgroundColor($r('app.color.chip_bg_selected'))
          .borderRadius(12)
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        Text(this.relativeTime(this.idea.createdAt))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
        Blank()
        Text(this.idea.isFavorite ? '\u2665' : '\u2661')
          .fontSize(20)
          .fontColor(this.idea.isFavorite ? $r('app.color.danger') : $r('app.color.icon_secondary'))
          .onClick(() => this.onToggleFavorite(this.idea.id))
      }
      .width('100%')

      Text(this.idea.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.previewText())
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.contextSummary())
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.idea.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
          ForEach(this.idea.tags.slice(0, 5), (tag: string) => {
            Text(tag)
              .fontSize(12)
              .fontColor($r('app.color.chip_text_selected'))
              .backgroundColor($r('app.color.chip_bg_selected'))
              .borderRadius(10)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }, (tag: string, index: number) => `${tag}_${index}`)
          if (this.idea.tags.length > 5) {
            Text(`+${this.idea.tags.length - 5}`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.chip_bg_unselected'))
              .borderRadius(10)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
        }
      }

      Row({ space: 6 }) {
        Text(this.syncStatusLabel(this.idea.syncStatus))
          .fontSize(11)
          .fontColor(this.idea.syncStatus === 'conflict' ? $r('app.color.danger') : $r('app.color.chip_text_selected'))
          .backgroundColor(this.idea.syncStatus === 'conflict' ? $r('app.color.danger_bg') : $r('app.color.chip_bg_selected'))
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        Blank()
        Button($r('app.string.open_detail'))
          .fontSize(12)
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(14)
          .onClick(() => this.onOpen(this.idea.id))
        if (this.idea.isArchived) {
          Button($r('app.string.unarchive'))
            .fontSize(12)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_secondary'))
            .borderRadius(14)
            .onClick(() => this.onToggleArchive(this.idea.id))
        } else {
          Button($r('app.string.archive'))
            .fontSize(12)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.surface_secondary'))
            .fontColor($r('app.color.text_secondary'))
            .borderRadius(14)
            .onClick(() => this.onToggleArchive(this.idea.id))
        }
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .width('100%')
    .backgroundColor(this.isSelected ? $r('app.color.card_bg_selected') : $r('app.color.card_bg'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
    .border(this.isSelected ? { width: 2, color: $r('app.color.brand_primary') } : undefined)
    .onClick(() => this.onToggleSelect(this.idea.id))
    .stateStyles({
      pressed: {
        .shadow({ radius: 16, color: $r('app.color.card_shadow'), offsetY: 4 })
        .scale({ x: 0.98, y: 0.98 })
      },
      normal: {
        .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
        .scale({ x: 1, y: 1 })
      }
    })
    .animation({ duration: 200, curve: Curve.EaseOut })
  }

  private previewText(): string {
    if (this.idea.type === IdeaType.AUDIO) {
      return this.idea.asset?.localUri ? '\u{1F3B5} 语音文件' : '\u{1F3B5} 还没有录音文件';
    }
    if (this.idea.type === IdeaType.HANDWRITING) {
      return this.idea.asset?.strokes?.length ? `\u270D\ufe0F 手写笔画 ${this.idea.asset.strokes.length} 组` : '\u270D\ufe0F 还没有手写笔迹';
    }
    return this.idea.plainText || this.idea.note || '没有正文。';
  }

  private contextSummary(): string {
    const parts: string[] = [];
    if (this.idea.context.title.length > 0) {
      parts.push(this.idea.context.title);
    }
    if (this.idea.context.url.length > 0) {
      parts.push(this.idea.context.url);
    }
    if (parts.length === 0) {
      parts.push(this.idea.context.manualNote || '无来源上下文');
    }
    return `\u{1F517} ${parts.join(' \u00B7 ')}`;
  }

  private syncStatusLabel(status: string): string {
    if (status === 'pending_sync') return '待同步';
    if (status === 'synced') return '已同步';
    if (status === 'conflict') return '冲突';
    return '仅本机';
  }

  private relativeTime(isoString: string): string {
    const now = Date.now();
    const then = Date.parse(isoString);
    const diffMs = now - then;
    if (diffMs < 60000) return '刚刚';
    if (diffMs < 3600000) return `${Math.floor(diffMs / 60000)}分钟前`;
    if (diffMs < 86400000) return `${Math.floor(diffMs / 3600000)}小时前`;
    if (diffMs < 604800000) return `${Math.floor(diffMs / 86400000)}天前`;
    return new Date(isoString).toLocaleDateString();
  }
}
