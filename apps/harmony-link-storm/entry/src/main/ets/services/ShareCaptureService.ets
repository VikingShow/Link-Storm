import { Want } from '@kit.AbilityKit';
import fileUri from '@ohos.file.fileuri';

export type ShareContextType = 'link' | 'shared_text' | 'screenshot' | 'image' | 'manual_note' | 'unknown';
type WantParamValue = string | number | boolean | string[] | number[] | boolean[] | null | undefined;
type WantParams = Record<string, WantParamValue>;

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
  private state: ShareCaptureState = this.cloneState(EMPTY_STATE);

  static getInstance(): ShareCaptureService {
    if (!ShareCaptureService.instance) {
      ShareCaptureService.instance = new ShareCaptureService();
    }
    return ShareCaptureService.instance;
  }

  setShareState(state: ShareCaptureState): void {
    this.state = this.cloneState(state);
  }

  getShareState(): ShareCaptureState {
    return this.cloneState(this.state);
  }

  clearShareState(): void {
    this.state = this.cloneState(EMPTY_STATE);
  }

  applyWant(want: Want): void {
    const now = new Date().toISOString();
    const sourceApp = this.readString(want.bundleName);
    const url = this.pickUrl(want);
    const sharedText = this.pickSharedText(want);
    const attachments = this.pickAttachments(want);
    const contextType = this.inferContextType(url, sharedText, attachments);

    this.setShareState({
      contextType,
      title: this.deriveTitle(want, url, sharedText, sourceApp),
      sharedText,
      url,
      attachments,
      sourceApp,
      capturedAt: now
    });
  }

  private pickUrl(want: Want): string {
    const candidates = [
      this.readString(want.uri),
      this.readFirstParam(want, 'uri'),
      this.readFirstParam(want, 'url'),
      this.readFirstParam(want, 'link'),
      this.readFirstParam(want, 'shareUrl'),
      this.readFirstParam(want, 'ohos.extra.param.key.shareUrl')
    ];
    for (const candidate of candidates) {
      const normalized = this.normalizeUrl(candidate);
      if (normalized.length > 0) {
        return normalized;
      }
    }
    return '';
  }

  private pickSharedText(want: Want): string {
    const candidates = [
      this.readParam(want, 'text'),
      this.readParam(want, 'sharedText'),
      this.readParam(want, 'content'),
      this.readParam(want, 'data'),
      this.readParam(want, 'shareAbstract'),
      this.readParam(want, 'ohos.extra.param.key.shareAbstract'),
      this.readParam(want, 'contentTitle'),
      this.readParam(want, 'ohos.extra.param.key.contentTitle')
    ];
    for (const candidate of candidates.flat()) {
      const trimmed = candidate.trim();
      if (trimmed.length > 0) {
        return trimmed;
      }
    }
    return '';
  }

  private pickAttachments(want: Want): string[] {
    const values = [
      this.readParam(want, 'uri'),
      this.readParam(want, 'uris'),
      this.readParam(want, 'url'),
      this.readString(want.uri),
      this.readParam(want, 'path'),
      this.readParam(want, 'paths'),
      this.readParam(want, 'stream'),
      this.readParam(want, 'streams'),
      this.readParam(want, 'ohos.extra.param.key.stream'),
      this.readParam(want, 'ohos.extra.param.key.streams')
    ];
    const attachments = values
      .flat()
      .map((value: string) => this.normalizeAttachment(value))
      .filter((value: string) => value.length > 0);
    return Array.from(new Set(attachments));
  }

  private inferContextType(url: string, sharedText: string, attachments: string[]): ShareContextType {
    if (url.length > 0) {
      return 'link';
    }
    if (attachments.some((item: string) => this.isImageLike(item))) {
      return 'image';
    }
    if (sharedText.length > 0) {
      return 'shared_text';
    }
    if (attachments.length > 0) {
      return 'manual_note';
    }
    return 'unknown';
  }

  private deriveTitle(want: Want, url: string, sharedText: string, sourceApp: string): string {
    const fromUrl = this.titleFromUrl(url);
    if (fromUrl.length > 0) {
      return fromUrl;
    }

    const textSnippet = this.firstLine(sharedText);
    if (textSnippet.length > 0) {
      return textSnippet;
    }

    const wantTitle = this.readFirstParam(want, 'title').trim();
    if (wantTitle.length > 0) {
      return wantTitle;
    }

    return sourceApp;
  }

  private titleFromUrl(url: string): string {
    if (url.length === 0) {
      return '';
    }
    try {
      const withoutScheme = this.stripScheme(url);
      const slashIndex = withoutScheme.indexOf('/');
      const host = slashIndex >= 0 ? withoutScheme.substring(0, slashIndex) : withoutScheme;
      const path = slashIndex >= 0 ? withoutScheme.substring(slashIndex + 1).replace(/\/+$/, '') : '';
      if (path.length > 0) {
        const segments = path.split('/').filter((item: string) => item.length > 0);
        const last = segments.length > 0 ? segments[segments.length - 1] : '';
        if (last.length > 0) {
          return decodeURIComponent(last);
        }
      }
      return host;
    } catch {
      const trimmed = url.trim();
      const lastSlash = trimmed.lastIndexOf('/');
      if (lastSlash >= 0 && lastSlash < trimmed.length - 1) {
        return trimmed.substring(lastSlash + 1);
      }
      return trimmed;
    }
  }

  private firstLine(text: string): string {
    if (text.length === 0) {
      return '';
    }
    const line = text.split(/\r?\n/, 1)[0].trim();
    if (line.length <= 40) {
      return line;
    }
    return `${line.substring(0, 40)}...`;
  }

  private normalizeUrl(value: string): string {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('file://')) {
      return trimmed;
    }
    if (trimmed.includes('://')) {
      return trimmed;
    }
    if (trimmed.startsWith('www.')) {
      return `https://${trimmed}`;
    }
    return '';
  }

  private normalizeAttachment(value: string): string {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return '';
    }
    if (trimmed.startsWith('file://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return fileUri.getUriFromPath(trimmed);
    }
    if (trimmed.startsWith('content://')) {
      return trimmed;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '';
  }

  private isImageLike(value: string): boolean {
    const lower = value.toLowerCase();
    return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  private stripScheme(url: string): string {
    const schemeIndex = url.indexOf('://');
    if (schemeIndex >= 0) {
      return url.substring(schemeIndex + 3);
    }
    if (url.startsWith('//')) {
      return url.substring(2);
    }
    return url;
  }

  private readString(value: WantParamValue): string {
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return `${value}`;
    }
    return '';
  }

  private readStrings(value: WantParamValue): string[] {
    if (Array.isArray(value)) {
      return value.map((item: string | number | boolean) => this.readString(item));
    }
    const single = this.readString(value);
    return single.length > 0 ? [single] : [];
  }

  private readParam(want: Want, key: string): string[] {
    const params = want.parameters as WantParams | undefined;
    if (!params) {
      return [];
    }
    return this.readStrings(params[key]);
  }

  private readFirstParam(want: Want, key: string): string {
    const values = this.readParam(want, key);
    return values.length > 0 ? values[0] : '';
  }

  private cloneState(state: ShareCaptureState): ShareCaptureState {
    return {
      contextType: state.contextType,
      title: state.title,
      sharedText: state.sharedText,
      url: state.url,
      attachments: state.attachments.slice(),
      sourceApp: state.sourceApp,
      capturedAt: state.capturedAt
    };
  }
}

export const shareCaptureService = ShareCaptureService.getInstance();
