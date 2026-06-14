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

export interface IdeaFolder {
  id: string;
  name: string;
  color: string;
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
  mimeType?: string;
  durationMs?: number;
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
  folderId?: string;
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
  folderId?: string;
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
  conflicts: string[];
}

export enum ImportConflictStrategy {
  KEEP_NEWER = 'keep_newer',
  FORCE_OVERWRITE = 'force_overwrite'
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
