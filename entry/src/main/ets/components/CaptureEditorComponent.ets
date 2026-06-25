import { common } from '@kit.AbilityKit';
import { IdeaType, StrokePoint, HandwritingStroke } from '../model/IdeaModels';

const STROKE_WIDTH = 3;
const RECORD_BUTTON_SIZE = 64;
const SECONDARY_BUTTON_SIZE = 36;
const STROKE_COLOR_LIGHT = '#111827';
const STROKE_COLOR_DARK = '#F9FAFB';

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
  @Prop isCompact: boolean = true;
  @State private recordPulse: number = 0;
  @State private isDarkMode: boolean = false;
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
  private pulseTimer: number = -1;

  aboutToAppear(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.isDarkMode = context.config.colorMode === 1;
    } catch (_e) {
      this.isDarkMode = false;
    }
  }

  private canvasStrokeColor(): string {
    return this.isDarkMode ? STROKE_COLOR_DARK : STROKE_COLOR_LIGHT;
  }

  aboutToDisappear(): void {
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
    }
  }

  private canvasHeight(): number {
    return this.isCompact ? 200 : 280;
  }

  private editorHeight(): number {
    return this.isCompact ? 240 : 320;
  }

  private formatDuration(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const mm = minutes < 10 ? '0' + minutes.toString() : minutes.toString();
    const ss = seconds < 10 ? '0' + seconds.toString() : seconds.toString();
    return mm + ':' + ss;
  }

  private startPulseAnimation(): void {
    this.recordPulse = 0;
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
    }
    this.pulseTimer = setInterval(() => {
      this.recordPulse = (this.recordPulse + 1) % 2;
    }, 800);
  }

  private stopPulseAnimation(): void {
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
      this.pulseTimer = -1;
    }
    this.recordPulse = 0;
  }

  build() {
    Column({ space: 0 }) {
      Tabs({ barPosition: BarPosition.Start, index: this.activeTabIndex() }) {
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
      .height(this.editorHeight())
    }
  }

  private activeTabIndex(): number {
    if (this.activeType === IdeaType.AUDIO) return 1;
    if (this.activeType === IdeaType.HANDWRITING) return 2;
    return 0;
  }

  @Builder
  private DocumentEditor() {
    Column({ space: 8 }) {
      TextArea({ placeholder: $r('app.string.document_placeholder'), text: this.documentText })
        .height(this.isCompact ? 140 : 180)
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
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Row() {
          Column() {
            Stack() {
              if (this.audioRecorderState === 'recording') {
                Circle()
                  .width(RECORD_BUTTON_SIZE + 8)
                  .height(RECORD_BUTTON_SIZE + 8)
                  .fill(Color.Transparent)
                  .stroke($r('app.color.brand_primary'))
                  .strokeWidth(2)
                  .opacity(this.recordPulse === 0 ? 0.6 : 0.2)
              }
              Circle()
                .width(RECORD_BUTTON_SIZE)
                .height(RECORD_BUTTON_SIZE)
                .fill(this.audioRecorderState === 'idle' ? $r('app.color.brand_primary') :
                  this.audioRecorderState === 'recording' ? $r('app.color.brand_primary') :
                    Color.Transparent)
                .stroke(this.audioRecorderState === 'paused' ? $r('app.color.brand_primary') : Color.Transparent)
                .strokeWidth(this.audioRecorderState === 'paused' ? 2 : 0)
              Text(this.audioRecorderState === 'recording' ? '\u275A\u275A' :
                this.audioRecorderState === 'paused' ? '\u25B6' : '\uD83C\uDFA4')
                .fontSize(this.audioRecorderState === 'idle' ? 28 : 20)
                .fontColor(this.audioRecorderState === 'paused' ? $r('app.color.brand_primary') : Color.White)
            }
            .width(RECORD_BUTTON_SIZE + 8)
            .height(RECORD_BUTTON_SIZE + 8)
            .onClick(() => {
              if (this.audioRecorderState === 'idle') {
                this.onAudioStart();
                this.startPulseAnimation();
              } else if (this.audioRecorderState === 'recording') {
                this.onAudioPause();
                this.stopPulseAnimation();
              } else if (this.audioRecorderState === 'paused') {
                this.onAudioResume();
                this.startPulseAnimation();
              }
            })
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        if (this.audioRecorderState === 'idle') {
          Text($r('app.string.tap_to_record'))
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        } else {
          Row({ space: 8 }) {
            Text(this.formatDuration(this.audioDurationMs))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(this.audioRecorderState === 'paused' ? '(暂停中)' : '')
              .fontSize(13)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      if (this.audioRecorderState === 'recording' || this.audioRecorderState === 'paused') {
        Row({ space: 24 }) {
          Row() {
            Column() {
              Circle()
                .width(SECONDARY_BUTTON_SIZE)
                .height(SECONDARY_BUTTON_SIZE)
                .fill($r('app.color.brand_primary'))
              Text('\u2713')
                .fontSize(16)
                .fontColor(Color.White)
            }
            .width(SECONDARY_BUTTON_SIZE)
            .height(SECONDARY_BUTTON_SIZE)
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderRadius(SECONDARY_BUTTON_SIZE / 2)
            .backgroundColor($r('app.color.brand_primary'))
            .onClick(() => {
              this.stopPulseAnimation();
              this.onAudioStop();
            })
            Text($r('app.string.save_record'))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(VerticalAlign.Center)

          Row() {
            Column() {
              Circle()
                .width(SECONDARY_BUTTON_SIZE)
                .height(SECONDARY_BUTTON_SIZE)
                .fill($r('app.color.danger_bg'))
              Text('\u2715')
                .fontSize(16)
                .fontColor($r('app.color.danger'))
            }
            .width(SECONDARY_BUTTON_SIZE)
            .height(SECONDARY_BUTTON_SIZE)
            .alignItems(HorizontalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .borderRadius(SECONDARY_BUTTON_SIZE / 2)
            .backgroundColor($r('app.color.danger_bg'))
            .onClick(() => {
              this.stopPulseAnimation();
              this.onAudioCancel();
            })
            Text($r('app.string.cancel_record'))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }

      if (this.audioPath.length > 0 && this.audioRecorderState === 'idle') {
        Row() {
          Text('\uD83C\uDFB5')
            .fontSize(16)
          Text(this.formatDuration(this.audioDurationMs))
            .fontSize(14)
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
          .height(this.canvasHeight())
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
      .height(this.canvasHeight())
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
      this.handwritingStrokes = this.handwritingStrokes.concat([{ color: '', width: STROKE_WIDTH, points: this.currentStrokePoints }]);
      this.redrawHandwriting();
      this.onPersistDraft();
      return;
    }
    if (event.type === TouchType.Move) {
      if (this.currentStrokePoints.length === 0) {
        this.currentStrokePoints = [canvasPoint];
        this.handwritingStrokes = this.handwritingStrokes.concat([{ color: '', width: STROKE_WIDTH, points: this.currentStrokePoints }]);
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
    ctx.clearRect(0, 0, 900, this.canvasHeight());
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = this.canvasStrokeColor();
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
