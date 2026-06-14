import { Want } from '@kit.AbilityKit';

export type ShareContextType = 'link' | 'shared_text' | 'screenshot' | 'image' | 'manual_note' | 'unknown';

export interface ShareCaptureState {
  contextType: ShareContextType;
  title: string;
  sharedText: string;
  url: string;
  attachments: string[];
  sourceApp: string;
  capturedAt: string;
}

const EMPTY_STATE: ShareCaptureState = {
  contextType: 'unknown',
  title: '',
  sharedText: '',
  url: '',
  attachments: [],
  sourceApp: '',
  capturedAt: ''
};

export class ShareCaptureService {
  private static instance: ShareCaptureService | undefined;
  private state: ShareCaptureState = {
    contextType: EMPTY_STATE.contextType,
    title: EMPTY_STATE.title,
    sharedText: EMPTY_STATE.sharedText,
    url: EMPTY_STATE.url,
    attachments: [],
    sourceApp: EMPTY_STATE.sourceApp,
    capturedAt: EMPTY_STATE.capturedAt
  };

  static getInstance(): ShareCaptureService {
    if (!ShareCaptureService.instance) {
      ShareCaptureService.instance = new ShareCaptureService();
    }
    return ShareCaptureService.instance;
  }

  setShareState(state: ShareCaptureState): void {
    this.state = {
      contextType: state.contextType,
      title: state.title,
      sharedText: state.sharedText,
      url: state.url,
      attachments: state.attachments.slice(),
      sourceApp: state.sourceApp,
      capturedAt: state.capturedAt
    };
  }

  getShareState(): ShareCaptureState {
    return {
      contextType: this.state.contextType,
      title: this.state.title,
      sharedText: this.state.sharedText,
      url: this.state.url,
      attachments: this.state.attachments.slice(),
      sourceApp: this.state.sourceApp,
      capturedAt: this.state.capturedAt
    };
  }

  clearShareState(): void {
    this.state = {
      contextType: EMPTY_STATE.contextType,
      title: EMPTY_STATE.title,
      sharedText: EMPTY_STATE.sharedText,
      url: EMPTY_STATE.url,
      attachments: [],
      sourceApp: EMPTY_STATE.sourceApp,
      capturedAt: EMPTY_STATE.capturedAt
    };
  }

  applyWant(want: Want): void {
    const shareUrl = typeof want.uri === 'string' ? want.uri : '';
    const bundleName = typeof want.bundleName === 'string' ? want.bundleName : '';
    const capturedAt = new Date().toISOString();
    this.setShareState({
      contextType: shareUrl.length > 0 ? 'link' : 'unknown',
      title: this.deriveTitle(shareUrl, bundleName),
      sharedText: '',
      url: shareUrl,
      attachments: shareUrl.length > 0 ? [shareUrl] : [],
      sourceApp: bundleName,
      capturedAt
    });
  }

  private deriveTitle(shareUrl: string, bundleName: string): string {
    if (shareUrl.length > 0) {
      const trimmed = shareUrl.trim();
      const lastSlash = trimmed.lastIndexOf('/');
      if (lastSlash >= 0 && lastSlash < trimmed.length - 1) {
        return trimmed.substring(lastSlash + 1);
      }
      return trimmed;
    }
    return bundleName;
  }
}

export const shareCaptureService = ShareCaptureService.getInstance();
