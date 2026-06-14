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
    if (!fileIo.accessSync(resolved)) {
      throw new Error(`Audio file not found: ${resolved}`);
    }
    if (this.currentPath !== resolved) {
      await this.release();
      this.player = await media.createAVPlayer();
      this.installListeners();
      this.fileHandle = fileIo.openSync(resolved, fileIo.OpenMode.READ_ONLY);
      this.player.url = `fd://${this.fileHandle.fd}`;
      this.currentPath = resolved;
      await this.preparePlayer();
      return;
    }
    if (this.player?.state === 'prepared' || this.player?.state === 'paused' || this.player?.state === 'completed') {
      await this.player.play();
      return;
    }
    if (this.player?.state === 'idle') {
      this.fileHandle = fileIo.openSync(resolved, fileIo.OpenMode.READ_ONLY);
      this.player.url = `fd://${this.fileHandle.fd}`;
      await this.preparePlayer();
      return;
    }
    await this.player?.play();
  }

  async pause(): Promise<void> {
    if (!this.player) {
      return;
    }
    await this.invokeWithCallback((done) => this.player?.pause(done));
  }

  async stop(): Promise<void> {
    if (!this.player) {
      return;
    }
    await this.invokeWithCallback((done) => this.player?.stop(done));
    await this.invokeWithCallback((done) => this.player?.reset(done));
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

  private installListeners(): void {
    if (!this.player) {
      return;
    }
    this.player.on('error', () => {
      this.currentPath = '';
    });
  }

  private async preparePlayer(): Promise<void> {
    if (!this.player) {
      throw new Error('Audio player is not initialized');
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
