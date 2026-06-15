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
  createdAt: string;
  updatedAt: string;
}

export interface IdeaTag {
  id: string;
  name: string;
  color: string;
  createdAt: string;
  updatedAt: string;
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

export interface IdeaAiOutput {
  id: string;
  ideaId: string;
  outputType: string;
  content: string;
  sourceIdeaIds: string[];
  createdAt: string;
  updatedAt: string;
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

export interface CaptureDraftState {
  activeType: IdeaType;
  title: string;
  tags: string;
  sourceTitle: string;
  sourceUrl: string;
  folderId?: string;
  note: string;
  documentText: string;
  audioStatus: string;
  audioPath: string;
  audioDurationMs: number;
  audioRecorderState: string;
  handwritingText: string;
  handwritingStrokes: HandwritingStroke[];
  currentStrokePoints: StrokePoint[];
  handwritingPreviewPath?: string;
  savedAt: string;
}

export interface IdeaExportPayload {
  schema: string;
  version: number;
  exportedAt: string;
  ideas: Idea[];
  folders: IdeaFolder[];
  tags: IdeaTag[];
  aiOutputs?: IdeaAiOutput[];
}

export interface IdeaBackupPayload {
  schema: string;
  version: number;
  exportedAt: string;
  sourceDevice?: IdeaBackupSourceDevice;
  ideas: Idea[];
  folders: IdeaFolder[];
  tags: IdeaTag[];
  aiOutputs?: IdeaAiOutput[];
  attachments: IdeaBackupAttachment[];
}

export interface IdeaBackupSourceDevice {
  name: string;
  type: string;
  os: string;
}

export interface IdeaBackupAttachment {
  ideaId: string;
  kind: string;
  role?: string;
  sourcePath: string;
  relativePath: string;
}

export interface IdeaBackupPreview {
  exportedAt: string;
  sourceDevice: string;
  ideaCount: number;
  folderCount: number;
  tagCount: number;
  aiOutputCount: number;
  attachmentCount: number;
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
