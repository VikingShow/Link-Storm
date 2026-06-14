import router from '@ohos.router';
import { common } from '@kit.AbilityKit';
import { HandwritingStroke, Idea, IdeaDraft, IdeaType, StrokePoint, ideaTypeLabel } from '../model/IdeaModels';
import { ideaRepository } from '../repository/IdeaRepository';

const PHONE_BREAKPOINT = 680;
const TABLET_BREAKPOINT = 1100;
const STROKE_COLOR = '#111827';
const STROKE_WIDTH = 3;
const CANVAS_WIDTH = 900;
const CANVAS_HEIGHT = 240;

@Entry
@Component
struct Index {
  @State private activeType: IdeaType = IdeaType.DOCUMENT;
  @State private deviceHint: string = '桌面/二合一尺寸：默认文档';
  @State private title: string = '';
  @State private tags: string = '';
  @State private sourceTitle: string = '';
  @State private sourceUrl: string = '';
  @State private note: string = '';
  @State private documentText: string = '';
  @State private audioStatus: string = '录音能力预留，后续接入 AVRecorder';
  @State private handwritingText: string = '手写能力预留，当前已接入 Canvas';
  @State private search: string = '';
  @State private typeFilter: string = 'all';
  @State private ideas: Idea[] = [];
  @State private importStatus: string = '';
  @State private exportStatus: string = '';
  @State private handwritingStrokes: HandwritingStroke[] = [];
  @State private currentStrokePoints: StrokePoint[] = [];

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private canvasWidth: number = CANVAS_WIDTH;
  private canvasHeight: number = CANVAS_HEIGHT;

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await ideaRepository.init(context);
    await this.reloadIdeas();
    this.applyDefaultMode(CANVAS_WIDTH);
  }

  build() {
    Column({ space: 16 }) {
      this.Header()
      Row({ space: 16 }) {
        this.CapturePanel()
        this.LibraryPanel()
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .layoutWeight(1)
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
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
            const uri = await ideaRepository.exportToFile();
            this.exportStatus = `已导出：${uri}`;
          } catch (err) {
            this.exportStatus = `导出失败：${String(err)}`;
          }
        })
      Button('导入文件')
        .buttonStyle(ButtonStyleMode.NORMAL)
        .onClick(async () => {
          try {
            const result = await ideaRepository.importFromFile();
            this.importStatus = `导入完成：新增${result.inserted}，更新${result.updated}，跳过${result.skipped}`;
            await this.reloadIdeas();
          } catch (err) {
            this.importStatus = `导入失败：${String(err)}`;
          }
        })
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
        .onChange((value: string) => this.title = value)

      TextInput({ placeholder: '标签，用逗号分隔', text: this.tags })
        .onChange((value: string) => this.tags = value)

      Row({ space: 10 }) {
        TextInput({ placeholder: '来源标题', text: this.sourceTitle })
          .onChange((value: string) => this.sourceTitle = value)
          .layoutWeight(1)
        TextInput({ placeholder: '来源链接', text: this.sourceUrl })
          .onChange((value: string) => this.sourceUrl = value)
          .layoutWeight(1)
      }

      this.ActiveCaptureEditor()

      TextArea({ placeholder: '备注：补充上下文或后续行动', text: this.note })
        .height(76)
        .onChange((value: string) => this.note = value)

      Row({ space: 10 }) {
        Button('保存想法')
          .backgroundColor('#136F63')
          .fontColor(Color.White)
          .onClick(async () => this.saveDraft())
        Button('清空')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => this.resetForm())
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
      .onClick(() => this.activeType = type)
  }

  @Builder
  private ActiveCaptureEditor() {
    if (this.activeType === IdeaType.AUDIO) {
      Column({ space: 8 }) {
        Text('语音捕捉')
          .fontWeight(FontWeight.Bold)
        Text(this.audioStatus)
          .fontColor('#697386')
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

        Stack() {
          Canvas(this.canvasContext)
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

      Row({ space: 8 }) {
        this.FilterButton('all', '全部')
        this.FilterButton(IdeaType.AUDIO, '语音')
        this.FilterButton(IdeaType.HANDWRITING, '手写')
        this.FilterButton(IdeaType.DOCUMENT, '文档')
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
          .onClick(() => {
            router.pushUrl({
              url: 'pages/Detail',
              params: { id: idea.id }
            });
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
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: '#D8DDE6' })
  }

  private applyDefaultMode(width: number): void {
    if (width < PHONE_BREAKPOINT) {
      this.deviceHint = '手机尺寸：默认语音';
      this.activeType = IdeaType.AUDIO;
    } else if (width >= PHONE_BREAKPOINT && width < TABLET_BREAKPOINT) {
      this.deviceHint = '平板尺寸：默认手写';
      this.activeType = IdeaType.HANDWRITING;
    } else {
      this.deviceHint = '桌面/二合一尺寸：默认文档';
      this.activeType = IdeaType.DOCUMENT;
    }
  }

  private async saveDraft(): Promise<void> {
    const draft: IdeaDraft = {
      title: this.title,
      type: this.activeType,
      plainText: this.activeType === IdeaType.DOCUMENT ? this.documentText : '',
      note: this.note,
      tags: this.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0),
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
        previewPath: ''
      } : undefined
    };

    await ideaRepository.save(draft);
    this.resetForm();
    await this.reloadIdeas();
  }

  private resetForm(): void {
    this.title = '';
    this.tags = '';
    this.sourceTitle = '';
    this.sourceUrl = '';
    this.note = '';
    this.documentText = '';
    this.audioStatus = '录音能力预留，后续接入 AVRecorder';
    this.handwritingText = '手写能力预留，当前已接入 Canvas';
    this.clearHandwriting();
  }

  private async reloadIdeas(): Promise<void> {
    this.ideas = await ideaRepository.list();
  }

  private filteredIdeas(): Idea[] {
    const query = this.search.trim().toLowerCase();
    return this.ideas.filter((idea: Idea) => {
      const typeOk = this.typeFilter === 'all' || idea.type === this.typeFilter;
      const text = [
        idea.title,
        idea.plainText,
        idea.note,
        idea.context.title,
        idea.context.url,
        idea.tags.join(' ')
      ].join(' ').toLowerCase();
      return typeOk && (!query || text.includes(query));
    });
  }

  private previewText(idea: Idea): string {
    if (idea.type === IdeaType.AUDIO) {
      return '语音记录入口已预留，后续保存音频文件。';
    }
    if (idea.type === IdeaType.HANDWRITING) {
      return idea.asset?.strokes?.length ? `手写笔画 ${idea.asset.strokes.length} 组` : '手写记录入口已预留，后续保存笔迹和预览图。';
    }
    return idea.plainText || idea.note || '没有正文。';
  }

  private clearHandwriting(): void {
    this.handwritingStrokes = [];
    this.currentStrokePoints = [];
    this.redrawHandwriting();
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
      return;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.currentStrokePoints.length > 0) {
        this.currentStrokePoints.push(canvasPoint);
      }
      this.currentStrokePoints = [];
      this.redrawHandwriting();
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
}
