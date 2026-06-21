import { IdeaType, StrokePoint, HandwritingStroke } from '../model/IdeaModels';

const STROKE_COLOR = '#111827';
const STROKE_WIDTH = 3;
const CANVAS_HEIGHT = 240;

@Component
export struct CaptureEditorComponent {
  @Link activeType: IdeaType;
  @Link documentText: string;
  @Link audioStatus: string;
  @Link audioPath: string;
  @Link audioDurationMs: number;
  @Link audioRecorderState: string;
  @Link handwritingText: string;
  @Link handwritingStrokes: HandwritingStroke[];
  @Link currentStrokePoints: StrokePoint[];
  @Prop note: string = '';
  onPersistDraft: () => void = () => {};
  onAudioStart: () => void = () => {};
  onAudioPause: () => void = () => {};
  onAudioResume: () => void = () => {};
  onAudioStop: () => void = () => {};
  onAudioCancel: () => void = () => {};
  onHandwritingUndo: () => void = () => {};
  onHandwritingClear: () => void = () => {};
  onHandwritingSavePreview: () => void = () => {};

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private handwritingCanvasId: string = 'handwriting-canvas';

  build() {
    Column({ space: 0 }) {
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          this.DocumentEditor();
        }
        .tabBar($r('app.string.type_document'))

        TabContent() {
          this.AudioEditor();
        }
        .tabBar($r('app.string.type_audio'))

        TabContent() {
          this.HandwritingEditor();
        }
        .tabBar($r('app.string.type_handwriting'))
      }
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        const types: IdeaType[] = [IdeaType.DOCUMENT, IdeaType.AUDIO, IdeaType.HANDWRITING];
        this.activeType = types[index];
        this.onPersistDraft();
      })
      .height(280)
    }
  }

  @Builder
  private DocumentEditor() {
    Column({ space: 8 }) {
      TextArea({ placeholder: $r('app.string.document_placeholder'), text: this.documentText })
        .height(160)
        .onChange((value: string) => {
          this.documentText = value;
          this.onPersistDraft();
        })
      Row() {
        Text(this.documentStatsText())
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
        Blank()
        Text($r('app.string.auto_save_draft'))
          .fontSize(12)
          .fontColor($r('app.color.brand_primary'))
      }
      .width('100%')
    }
    .padding(12)
  }

  @Builder
  private AudioEditor() {
    Column({ space: 10 }) {
      Text(this.audioStatus)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      if (this.audioRecorderState === 'recording') {
        Progress({ value: 0, total: 100, type: ProgressType.Linear })
          .color($r('app.color.brand_primary'))
          .width('100%')
      }

      Row({ space: 8 }) {
        Button($r('app.string.start_record'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(18)
          .enabled(this.audioRecorderState === 'idle')
          .onClick(() => this.onAudioStart())
        Button($r('app.string.pause_record'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(18)
          .enabled(this.audioRecorderState === 'recording')
          .onClick(() => this.onAudioPause())
        Button($r('app.string.resume_record'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(18)
          .enabled(this.audioRecorderState === 'paused')
          .onClick(() => this.onAudioResume())
        Button($r('app.string.stop_record'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(18)
          .enabled(this.audioRecorderState === 'recording' || this.audioRecorderState === 'paused')
          .onClick(() => this.onAudioStop())
        Button($r('app.string.cancel_record'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.danger'))
          .borderRadius(18)
          .enabled(this.audioRecorderState === 'recording' || this.audioRecorderState === 'paused')
          .onClick(() => this.onAudioCancel())
      }
      .width('100%')

      if (this.audioPath.length > 0) {
        Row() {
          Text('\u{1F3B5}')
            .fontSize(16)
          Text(Math.round(this.audioDurationMs / 1000).toString() + 's')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 4 })
        }
        .width('100%')
      }
    }
    .padding(12)
    .width('100%')
  }

  @Builder
  private HandwritingEditor() {
    Column({ space: 8 }) {
      Text(this.handwritingText)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))

      Row({ space: 8 }) {
        Button($r('app.string.undo_stroke'))
          .fontSize(13)
          .height(32)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(16)
          .enabled(this.handwritingStrokes.length > 0)
          .onClick(() => this.onHandwritingUndo())
        Button($r('app.string.clear_canvas'))
          .fontSize(13)
          .height(32)
          .backgroundColor($r('app.color.surface_secondary'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(16)
          .enabled(this.handwritingStrokes.length > 0 || this.currentStrokePoints.length > 0)
          .onClick(() => this.onHandwritingClear())
        Button($r('app.string.save_preview'))
          .fontSize(13)
          .height(32)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(16)
          .enabled(this.handwritingStrokes.length > 0)
          .onClick(() => this.onHandwritingSavePreview())
      }

      Stack() {
        Canvas(this.canvasContext)
          .id(this.handwritingCanvasId)
          .width('100%')
          .height(CANVAS_HEIGHT)
          .backgroundColor($r('app.color.surface_primary'))
          .borderRadius(8)
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
  }

  private documentStatsText(): string {
    const text = this.documentText;
    const trimmed = text.trim();
    const characters = text.length;
    const words = trimmed.length === 0 ? 0 : trimmed.split(/\s+/).filter((word: string) => word.length > 0).length;
    const lines = text.length === 0 ? 0 : text.split('\n').length;
    return '\u5B57\u6570 ' + characters.toString() + '\uFF0C\u8BCD\u6570 ' + words.toString() + '\uFF0C\u884C\u6570 ' + lines.toString();
  }

  private handleCanvasTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const point: TouchObject = event.touches[0];
    const x = point.windowX;
    const y = point.windowY;
    const canvasPoint: StrokePoint = { x, y, t: Date.now(), pressure: 1 };

    if (event.type === TouchType.Down) {
      this.currentStrokePoints = [canvasPoint];
      this.handwritingStrokes = this.handwritingStrokes.concat([{ color: STROKE_COLOR, width: STROKE_WIDTH, points: this.currentStrokePoints }]);
      this.redrawHandwriting();
      this.onPersistDraft();
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
      this.onPersistDraft();
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.currentStrokePoints.length > 0) {
        this.currentStrokePoints.push(canvasPoint);
      }
      this.currentStrokePoints = [];
      this.redrawHandwriting();
      this.onPersistDraft();
    }
  }

  private redrawHandwriting(): void {
    const ctx = this.canvasContext;
    ctx.clearRect(0, 0, 900, CANVAS_HEIGHT);
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
