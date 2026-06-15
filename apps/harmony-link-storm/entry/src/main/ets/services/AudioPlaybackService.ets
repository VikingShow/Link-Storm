import { BusinessError } from '@kit.BasicServicesKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';

export class AudioPlaybackService {
  private static instance: AudioPlaybackService | undefined;
  private context: common.UIAbilityContext | undefined;
  private player: media.AVPlayer | undefined;
  private currentPath: string = '';
  private fileHandle: fileIo.File | undefined;
  private lastError: string = '';

  static getInstance(context?: common.UIAbilityContext): AudioPlaybackService {
    if (!AudioPlaybackService.instance) {
      AudioPlaybackService.instance = new AudioPlaybackService();
    }
    if (context) {
      AudioPlaybackService.instance.context = context;
    }
    return AudioPlaybackService.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async play(path: string): Promise<void> {
    const resolved = this.resolvePath(path);
    if (!this.audioFileExists(resolved)) {
      this.lastError = `音频文件不存在：${resolved}`;
      throw new Error(this.lastError);
    }
    try {
      if (this.currentPath !== resolved) {
        await this.release();
        this.player = await media.createAVPlayer();
        this.installListeners();
        this.fileHandle = fileIo.openSync(resolved, fileIo.OpenMode.READ_ONLY);
        this.player.url = `fd://${this.fileHandle.fd}`;
        this.currentPath = resolved;
        await this.preparePlayer();
        this.lastError = '';
        return;
      }
      if (this.player?.state === 'prepared' || this.player?.state === 'paused' || this.player?.state === 'completed') {
        await this.player.play();
        this.lastError = '';
        return;
      }
      if (this.player?.state === 'idle') {
        this.closeFileHandle();
        this.fileHandle = fileIo.openSync(resolved, fileIo.OpenMode.READ_ONLY);
        this.player.url = `fd://${this.fileHandle.fd}`;
        await this.preparePlayer();
        this.lastError = '';
        return;
      }
      await this.player?.play();
      this.lastError = '';
    } catch (err) {
      await this.releaseQuietly();
      this.lastError = `播放音频失败：${String(err)}`;
      throw new Error(this.lastError);
    }
  }

  async pause(): Promise<void> {
    if (!this.player) {
      return;
    }
    try {
      await this.invokeWithCallback((done) => this.player?.pause(done));
      this.lastError = '';
    } catch (err) {
      this.lastError = `暂停音频失败：${String(err)}`;
      throw new Error(this.lastError);
    }
  }

  async stop(): Promise<void> {
    if (!this.player) {
      return;
    }
    try {
      await this.invokeWithCallback((done) => this.player?.stop(done));
      await this.invokeWithCallback((done) => this.player?.reset(done));
      await this.release();
      this.lastError = '';
    } catch (err) {
      await this.releaseQuietly();
      this.lastError = `停止音频失败：${String(err)}`;
      throw new Error(this.lastError);
    }
  }

  async release(): Promise<void> {
    if (!this.player) {
      this.closeFileHandle();
      this.currentPath = '';
      return;
    }
    await this.invokeWithCallback((done) => this.player?.release(done));
    this.player = undefined;
    this.closeFileHandle();
    this.currentPath = '';
  }

  getState(): string {
    return this.player?.state ?? 'idle';
  }

  getLastError(): string {
    return this.lastError;
  }

  private installListeners(): void {
    if (!this.player) {
      return;
    }
    this.player.on('error', () => {
      this.lastError = '音频播放器报告播放错误';
      this.closeFileHandle();
      this.currentPath = '';
    });
  }

  private async preparePlayer(): Promise<void> {
    if (!this.player) {
      this.lastError = '音频播放器尚未初始化';
      throw new Error(this.lastError);
    }
    this.player.audioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0
    };
    await this.invokeWithCallback((done) => this.player?.prepare(done));
    await this.player.play();
  }

  private resolvePath(path: string): string {
    if (path.startsWith('file://')) {
      return path.slice('file://'.length);
    }
    return path;
  }

  private audioFileExists(path: string): boolean {
    if (!path) {
      return false;
    }
    try {
      return fileIo.accessSync(path);
    } catch {
      return false;
    }
  }

  private closeFileHandle(): void {
    if (!this.fileHandle) {
      return;
    }
    try {
      fileIo.closeSync(this.fileHandle);
    } finally {
      this.fileHandle = undefined;
    }
  }

  private async releaseQuietly(): Promise<void> {
    try {
      await this.release();
    } catch {
      this.player = undefined;
      this.closeFileHandle();
      this.currentPath = '';
    }
  }

  private async invokeWithCallback(action: (done: (err: BusinessError) => void) => void | undefined): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      try {
        action((err: BusinessError) => {
          if (err) {
            reject(new Error(err.message));
            return;
          }
          resolve();
        });
      } catch (err) {
        reject(err as Error);
      }
    });
  }
}

export const audioPlaybackService = AudioPlaybackService.getInstance();
