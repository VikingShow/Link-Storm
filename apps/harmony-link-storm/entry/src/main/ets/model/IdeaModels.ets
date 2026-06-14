export enum IdeaType {
  AUDIO = 'audio',
  HANDWRITING = 'handwriting',
  DOCUMENT = 'document'
}

export interface IdeaContext {
  title: string;
  url: string;
  manualNote: string;
  capturedAt: string;
}

export interface StrokePoint {
  x: number;
  y: number;
  t: number;
  pressure: number;
}

export interface HandwritingStroke {
  color: string;
  width: number;
  points: StrokePoint[];
}

export interface IdeaAsset {
  type: string;
  localUri: string;
  strokes?: HandwritingStroke[];
  previewPath?: string;
}

export interface Idea {
  id: string;
  title: string;
  type: IdeaType;
  plainText: string;
  note: string;
  tags: string[];
  context: IdeaContext;
  asset?: IdeaAsset;
  isFavorite: boolean;
  isArchived: boolean;
  syncStatus: string;
  aiStatus: string;
  createdAt: string;
  updatedAt: string;
}

export interface IdeaDraft {
  title: string;
  type: IdeaType;
  plainText: string;
  note: string;
  tags: string[];
  context: IdeaContext;
  asset?: IdeaAsset;
}

export interface IdeaExportPayload {
  schema: string;
  version: number;
  exportedAt: string;
  ideas: Idea[];
}

export interface ImportResult {
  inserted: number;
  updated: number;
  skipped: number;
}

export function ideaTypeLabel(type: IdeaType): string {
  if (type === IdeaType.AUDIO) {
    return '语音';
  }
  if (type === IdeaType.HANDWRITING) {
    return '手写';
  }
  return '文档';
}
