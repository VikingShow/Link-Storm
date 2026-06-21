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
  onOpen: (id: string) => void = () => {};
  onToggleFavorite: (id: string) => void = () => {};
  onToggleArchive: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};
  onToggleSelect: (id: string) => void = () => {};

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

      Text(this.idea.title || this.previewText())
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.idea.title && this.previewText().length > 0) {
        Text(this.previewText())
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.idea.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
          ForEach(this.idea.tags.slice(0, 2), (tag: string) => {
            Text(tag)
              .fontSize(12)
              .fontColor($r('app.color.chip_text_selected'))
              .backgroundColor($r('app.color.chip_bg_selected'))
              .borderRadius(10)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }, (tag: string, index: number) => tag + '_' + index.toString())
          if (this.idea.tags.length > 2) {
            Text('+' + (this.idea.tags.length - 2).toString())
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.chip_bg_unselected'))
              .borderRadius(10)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .width('100%')
    .backgroundColor(this.isSelected ? $r('app.color.card_bg_selected') : $r('app.color.card_bg'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
    .border(this.isSelected ? { width: 2, color: $r('app.color.brand_primary') } : undefined)
    .onClick(() => this.onOpen(this.idea.id))
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => this.onToggleSelect(this.idea.id))
    )
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
      return this.idea.asset?.localUri ? '语音' : '语音待录';
    }
    if (this.idea.type === IdeaType.HANDWRITING) {
      return this.idea.asset?.strokes?.length ? '手写 ' + this.idea.asset.strokes.length.toString() + ' 笔' : '手写待书';
    }
    return this.idea.plainText || this.idea.note || '';
  }

  private relativeTime(isoString: string): string {
    const now = Date.now();
    const then = Date.parse(isoString);
    const diffMs = now - then;
    if (diffMs < 60000) return '刚刚';
    if (diffMs < 3600000) return Math.floor(diffMs / 60000).toString() + '分钟前';
    if (diffMs < 86400000) return Math.floor(diffMs / 3600000).toString() + '小时前';
    if (diffMs < 604800000) return Math.floor(diffMs / 86400000).toString() + '天前';
    return new Date(isoString).toLocaleDateString();
  }
}
