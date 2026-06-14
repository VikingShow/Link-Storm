import { common } from '@kit.AbilityKit';
import media from '@ohos.multimedia.media';
import fileIo from '@ohos.file.fs';

export interface AudioRecordResult {
  path: string;
  mimeType: string;
  durationMs: number;
}

type RecorderState = 'idle' | 'recording' | 'paused';

export class AudioRecordService {
  private static instance: AudioRecordService | undefined;
  private context: common.UIAbilityContext | undefined;
  private state: RecorderState = 'idle';
  private startedAt = 0;
  private elapsedBeforePause = 0;
  private currentPath = '';
  private avRecorder: media.AVRecorder | undefined;
  private fileHandle: fileIo.File | undefined;

  static getInstance(context?: common.UIAbilityContext): AudioRecordService {
    if (!AudioRecordService.instance) {
      AudioRecordService.instance = new AudioRecordService();
    }
    if (context) {
      AudioRecordService.instance.context = context;
    }
    return AudioRecordService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  isRecording(): boolean {
    return this.state === 'recording';
  }

  isPaused(): boolean {
    return this.state === 'paused';
  }

  getState(): RecorderState {
    return this.state;
  }

  async start(): Promise<void> {
    const context = this.ensureContext();
    if (this.state === 'recording' || this.state === 'paused') {
      return;
    }
    this.currentPath = `${context.filesDir}/voice-${Date.now()}.m4a`;
    this.fileHandle = fileIo.openSync(
      this.currentPath,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE
    );
    try {
      this.avRecorder = await media.createAVRecorder();
      const profile: media.AVRecorderProfile = {
        audioBitrate: 112000,
        audioChannels: 2,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4
      };
      const config: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: profile,
        url: `fd://${this.fileHandle.fd.toString()}`
      };
      await this.avRecorder.prepare(config);
      await this.avRecorder.start();
      this.startedAt = Date.now();
      this.elapsedBeforePause = 0;
      this.state = 'recording';
    } catch {
      this.cleanupRecorder();
      throw new Error('Failed to start audio recording');
    }
  }

  async pause(): Promise<void> {
    if (this.state !== 'recording') {
      return;
    }
    if (!this.avRecorder) {
      throw new Error('Recorder is not initialized');
    }
    await this.avRecorder.pause();
    this.elapsedBeforePause += Date.now() - this.startedAt;
    this.startedAt = 0;
    this.state = 'paused';
  }

  async resume(): Promise<void> {
    if (this.state !== 'paused') {
      return;
    }
    if (!this.avRecorder) {
      throw new Error('Recorder is not initialized');
    }
    await this.avRecorder.resume();
    this.startedAt = Date.now();
    this.state = 'recording';
  }

  async stop(): Promise<AudioRecordResult> {
    if (this.state !== 'recording' && this.state !== 'paused') {
      throw new Error('Recorder is not active');
    }
    const resultPath = this.currentPath;
    const durationMs = this.totalDurationMs();
    try {
      await this.avRecorder?.stop();
    } finally {
      await this.avRecorder?.release();
      this.cleanupRecorder();
      this.state = 'idle';
      this.startedAt = 0;
      this.elapsedBeforePause = 0;
    }
    const result: AudioRecordResult = {
      path: resultPath,
      mimeType: 'audio/mp4',
      durationMs: Math.max(1, durationMs)
    };
    return result;
  }

  async cancel(): Promise<void> {
    if (this.state === 'idle') {
      return;
    }
    try {
      await this.avRecorder?.stop();
    } catch {
      // Ignore stop errors during cancellation.
    } finally {
      await this.avRecorder?.release();
      this.cleanupRecorder();
      this.removeCurrentFile();
      this.state = 'idle';
      this.startedAt = 0;
      this.elapsedBeforePause = 0;
      this.currentPath = '';
    }
  }

  getCurrentPath(): string {
    return this.currentPath;
  }

  getElapsedMs(): number {
    return this.totalDurationMs();
  }

  private cleanupRecorder(): void {
    if (this.fileHandle) {
      fileIo.closeSync(this.fileHandle);
      this.fileHandle = undefined;
    }
    this.avRecorder = undefined;
  }

  private removeCurrentFile(): void {
    if (!this.currentPath) {
      return;
    }
    try {
      if (fileIo.accessSync(this.currentPath)) {
        fileIo.unlinkSync(this.currentPath);
      }
    } catch {
      // Ignore file cleanup errors during cancellation.
    }
  }

  private totalDurationMs(): number {
    if (this.state === 'recording') {
      return this.elapsedBeforePause + (Date.now() - this.startedAt);
    }
    return this.elapsedBeforePause;
  }

  private ensureContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('AudioRecordService is not initialized');
    }
    return this.context;
  }
}

export const audioRecordService = AudioRecordService.getInstance();
