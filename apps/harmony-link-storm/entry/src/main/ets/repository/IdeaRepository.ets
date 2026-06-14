import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import picker from '@ohos.file.picker';
import zlib from '@ohos.zlib';
import { CaptureDraftState, Idea, IdeaAsset, IdeaBackupAttachment, IdeaBackupPayload, IdeaDraft, IdeaExportPayload, IdeaFolder, IdeaType, ImportConflictStrategy, ImportResult } from '../model/IdeaModels';

const STORE_NAME = 'link_storm_ideas';
const IDEAS_KEY = 'ideas_json';
const CAPTURE_DRAFT_KEY = 'capture_draft_json';
const FOLDERS_KEY = 'folders_json';
const EXPORT_SCHEMA = 'link-storm-local-capture-export';
const EXPORT_FILE_SUFFIX = '.json';
const BACKUP_SCHEMA = 'link-storm-backup';
const BACKUP_FILE_SUFFIX = '.zip';

interface MergeResult {
  inserted: number;
  updated: number;
  skipped: number;
  conflicts: string[];
  items: Idea[];
}

export class IdeaRepository {
  private pref?: preferences.Preferences;
  private context?: common.UIAbilityContext;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.pref = await preferences.getPreferences(context, STORE_NAME);
  }

  async list(): Promise<Idea[]> {
    const raw = await this.ensureStore().get(IDEAS_KEY, '[]') as string;
    const ideas: Idea[] = JSON.parse(raw) as Idea[];
    return ideas.sort((a: Idea, b: Idea) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  async listFolders(): Promise<IdeaFolder[]> {
    const raw = await this.ensureStore().get(FOLDERS_KEY, '[]') as string;
    const folders: IdeaFolder[] = JSON.parse(raw) as IdeaFolder[];
    return folders.sort((a: IdeaFolder, b: IdeaFolder) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  async createFolder(name: string, color: string = '#136F63'): Promise<IdeaFolder> {
    const folders = await this.listFolders();
    const now = new Date().toISOString();
    const folder: IdeaFolder = {
      id: this.createId(),
      name: name.trim() || '未命名文件夹',
      color,
      createdAt: now,
      updatedAt: now
    };
    folders.unshift(folder);
    await this.persistFolders(folders);
    return folder;
  }

  async updateFolder(id: string, patch: Partial<IdeaFolder>): Promise<void> {
    const folders = await this.listFolders();
    const now = new Date().toISOString();
    const next = folders.map((folder: IdeaFolder) => {
      if (folder.id !== id) {
        return folder;
      }
      return {
        id: folder.id,
        name: patch.name ?? folder.name,
        color: patch.color ?? folder.color,
        createdAt: folder.createdAt,
        updatedAt: now
      } as IdeaFolder;
    });
    await this.persistFolders(next);
  }

  async deleteFolder(id: string, reassignIdeaFolderId?: string): Promise<void> {
    const folders = await this.listFolders();
    await this.persistFolders(folders.filter((folder: IdeaFolder) => folder.id !== id));
    const ideas = await this.list();
    const now = new Date().toISOString();
    const next = ideas.map((idea: Idea) => {
      if (idea.folderId !== id) {
        return idea;
      }
      return {
        id: idea.id,
        title: idea.title,
        type: idea.type,
        plainText: idea.plainText,
        note: idea.note,
        tags: idea.tags,
        folderId: reassignIdeaFolderId,
        context: idea.context,
        asset: idea.asset,
        isFavorite: idea.isFavorite,
        isArchived: idea.isArchived,
        syncStatus: idea.syncStatus,
        aiStatus: idea.aiStatus,
        createdAt: idea.createdAt,
        updatedAt: now
      } as Idea;
    });
    await this.persist(next);
  }

  async save(draft: IdeaDraft): Promise<Idea> {
    const ideas = await this.list();
    const now = new Date().toISOString();
    const idea: Idea = {
      id: this.createId(),
      title: draft.title || this.defaultTitle(draft.type),
      type: draft.type,
      plainText: draft.plainText,
      note: draft.note,
      tags: draft.tags,
      folderId: draft.folderId,
      context: draft.context,
      asset: draft.asset,
      isFavorite: false,
      isArchived: false,
      syncStatus: 'local_only',
      aiStatus: 'not_processed',
      createdAt: now,
      updatedAt: now
    };
    ideas.unshift(idea);
    await this.persist(ideas);
    return idea;
  }

  async update(id: string, patch: Partial<Idea>): Promise<void> {
    const ideas = await this.list();
    const now = new Date().toISOString();
    const next = ideas.map((idea: Idea) => {
      if (idea.id !== id) {
        return idea;
      }
      return {
        id: idea.id,
        title: patch.title ?? idea.title,
        type: patch.type ?? idea.type,
        plainText: patch.plainText ?? idea.plainText,
        note: patch.note ?? idea.note,
        tags: patch.tags ?? idea.tags,
        folderId: patch.folderId ?? idea.folderId,
        context: patch.context ?? idea.context,
        asset: patch.asset ?? idea.asset,
        isFavorite: patch.isFavorite ?? idea.isFavorite,
        isArchived: patch.isArchived ?? idea.isArchived,
        syncStatus: patch.syncStatus ?? idea.syncStatus,
        aiStatus: patch.aiStatus ?? idea.aiStatus,
        createdAt: idea.createdAt,
        updatedAt: now
      } as Idea;
    });
    await this.persist(next);
  }

  async saveCaptureDraft(draft: CaptureDraftState): Promise<void> {
    await this.ensureStore().put(CAPTURE_DRAFT_KEY, JSON.stringify(draft));
    await this.ensureStore().flush();
  }

  async loadCaptureDraft(): Promise<CaptureDraftState | undefined> {
    const raw = await this.ensureStore().get(CAPTURE_DRAFT_KEY, '') as string;
    if (!raw) {
      return undefined;
    }
    try {
      return JSON.parse(raw) as CaptureDraftState;
    } catch {
      return undefined;
    }
  }

  async clearCaptureDraft(): Promise<void> {
    await this.ensureStore().delete(CAPTURE_DRAFT_KEY);
    await this.ensureStore().flush();
  }

  async delete(id: string): Promise<void> {
    const ideas = await this.list();
    await this.persist(ideas.filter((idea: Idea) => idea.id !== id));
  }

  async getById(id: string): Promise<Idea | undefined> {
    const ideas = await this.list();
    return ideas.find((idea: Idea) => idea.id === id);
  }

  async exportJson(): Promise<string> {
    const folders = await this.listFolders();
    return JSON.stringify({
      schema: EXPORT_SCHEMA,
      version: 1,
      exportedAt: new Date().toISOString(),
      ideas: await this.list(),
      folders
    } as IdeaExportPayload, null, 2);
  }

  async exportSummary(): Promise<string> {
    const ideas = await this.list();
    const active = ideas.filter((idea: Idea) => !idea.isArchived).length;
    const archived = ideas.length - active;
    const favorite = ideas.filter((idea: Idea) => idea.isFavorite).length;
    return `总计${ideas.length}，收藏${favorite}，归档${archived}，活动${active}`;
  }

  async exportToFile(): Promise<string> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const fileNames = [`link-storm-export-${this.timestampStamp()}${EXPORT_FILE_SUFFIX}`];
    const uris = await pickerInstance.save({
      newFileNames: fileNames,
      defaultFilePathUri: fileUri.getUriFromPath(context.filesDir),
      fileSuffixChoices: ['JSON|json']
    });
    if (uris.length === 0) {
      throw new Error('Export cancelled');
    }

    const target = uris[0];
    const path = this.resolveFilePath(target);
    const file = fileIo.createRandomAccessFileSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      await file.write(await this.exportJson(), { encoding: 'utf-8' });
    } finally {
      file.close();
    }
    return target;
  }

  async exportBackupZip(): Promise<string> {
    const context = this.ensureContext();
    const tempRoot = `${context.cacheDir}/link-storm-backup-${Date.now()}`;
    const payloadDir = `${tempRoot}/payload`;
    const attachmentsDir = `${payloadDir}/attachments`;
    const manifestPath = `${payloadDir}/manifest.json`;
    const archivePath = `${context.filesDir}/link-storm-backup-${this.timestampStamp()}${BACKUP_FILE_SUFFIX}`;
    fileIo.mkdirSync(tempRoot);
    fileIo.mkdirSync(payloadDir);
    fileIo.mkdirSync(attachmentsDir);

    const ideas = await this.list();
    const folders = await this.listFolders();
    const attachmentEntries = await this.collectBackupAttachments(ideas, attachmentsDir);
    const backup: IdeaBackupPayload = {
      schema: BACKUP_SCHEMA,
      version: 1,
      exportedAt: new Date().toISOString(),
      ideas,
      folders,
      attachments: attachmentEntries
    };
    const manifestFile = fileIo.openSync(manifestPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(manifestFile.fd, JSON.stringify(backup, null, 2));
    } finally {
      fileIo.closeSync(manifestFile);
    }

    await zlib.compressFile(payloadDir, archivePath, {
      level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION
    });
    this.cleanupBackupTemp(tempRoot);
    return archivePath;
  }

  async importFromFile(strategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER): Promise<ImportResult> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const uris = await pickerInstance.select();
    if (uris.length === 0) {
      throw new Error('Import cancelled');
    }
    const payload = this.readTextByUri(uris[0]);
    return this.importJson(payload, strategy);
  }

  async importBackupZip(strategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER): Promise<ImportResult> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const uris = await pickerInstance.select();
    if (uris.length === 0) {
      throw new Error('Import cancelled');
    }
    const zipPath = this.resolveFilePath(uris[0]);
    const tempRoot = `${context.cacheDir}/link-storm-import-${Date.now()}`;
    const extractDir = `${tempRoot}/extract`;
    fileIo.mkdirSync(tempRoot);
    fileIo.mkdirSync(extractDir);
    await zlib.decompressFile(zipPath, extractDir);
    const manifest = this.readBackupManifest(extractDir);
    const parsed = JSON.parse(manifest) as IdeaBackupPayload;
    if (parsed.schema !== BACKUP_SCHEMA) {
      throw new Error('Invalid backup schema');
    }
    const existing = await this.list();
    const merged = this.mergeIdeas(existing, parsed.ideas, strategy);
    await this.persist(merged.items);
    if (Array.isArray((parsed as IdeaBackupPayload).folders)) {
      await this.persistFolders(this.mergeFolders(await this.listFolders(), (parsed as IdeaBackupPayload).folders, strategy));
    }
    this.cleanupBackupTemp(tempRoot);
    return {
      inserted: merged.inserted,
      updated: merged.updated,
      skipped: merged.skipped,
      conflicts: merged.conflicts
    };
  }

  async importJson(payload: string, strategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER): Promise<ImportResult> {
    let parsed: Partial<IdeaExportPayload>;
    try {
      parsed = JSON.parse(payload) as Partial<IdeaExportPayload>;
    } catch (err) {
      throw new Error(`Invalid JSON payload: ${String(err)}`);
    }
    if (parsed.schema !== EXPORT_SCHEMA) {
      throw new Error('Invalid export schema');
    }
    if (!Array.isArray(parsed.ideas)) {
      throw new Error('Invalid ideas payload');
    }

    const existing = await this.list();
    const merged = this.mergeIdeas(existing, parsed.ideas as Idea[], strategy);
    await this.persist(merged.items);
    if (Array.isArray(parsed.folders)) {
      await this.persistFolders(this.mergeFolders(await this.listFolders(), parsed.folders as IdeaFolder[], strategy));
    }
    return {
      inserted: merged.inserted,
      updated: merged.updated,
      skipped: merged.skipped,
      conflicts: merged.conflicts
    };
  }

  async pickAttachmentPath(): Promise<string | undefined> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const uris = await pickerInstance.select();
    if (uris.length === 0) {
      return undefined;
    }
    return this.resolveFilePath(uris[0]);
  }

  async replaceIdeaAsset(ideaId: string): Promise<IdeaAsset | undefined> {
    const pickedPath = await this.pickAttachmentPath();
    if (!pickedPath) {
      return undefined;
    }
    const current = await this.getById(ideaId);
    if (!current) {
      throw new Error('Idea not found');
    }
    const copiedPath = await this.copyAttachmentToIdeaStorage(pickedPath, ideaId, current.asset?.type || current.type);
    const nextAsset: IdeaAsset = {
      type: this.inferAssetType(pickedPath, current.asset?.type || current.type),
      localUri: copiedPath,
      mimeType: this.inferMimeType(pickedPath, current.asset?.mimeType),
      previewPath: this.isImageLikeAsset(pickedPath) ? copiedPath : (current.asset?.previewPath || undefined),
      durationMs: current.asset?.durationMs,
      strokes: current.asset?.strokes
    };
    await this.update(ideaId, { asset: nextAsset });
    return nextAsset;
  }

  async clearIdeaAsset(ideaId: string): Promise<void> {
    const current = await this.getById(ideaId);
    if (!current) {
      throw new Error('Idea not found');
    }
    const storedPath = current.asset?.localUri;
    if (storedPath && this.isManagedAttachmentPath(storedPath)) {
      this.removeFileIfExists(storedPath);
    }
    if (current.asset?.previewPath && current.asset.previewPath !== storedPath && this.isManagedAttachmentPath(current.asset.previewPath)) {
      this.removeFileIfExists(current.asset.previewPath);
    }
    await this.update(ideaId, { asset: undefined });
  }

  async copyAttachmentToIdeaStorage(sourcePath: string, ideaId: string, kind: string): Promise<string> {
    const context = this.ensureContext();
    const attachmentsDir = `${context.filesDir}/idea-attachments`;
    fileIo.mkdirSync(attachmentsDir);
    const safeKind = this.safeName(kind || 'asset');
    const targetPath = `${attachmentsDir}/${ideaId}-${safeKind}-${Date.now()}${this.extensionFromPath(sourcePath)}`;
    fileIo.copyFileSync(sourcePath, targetPath);
    return targetPath;
  }

  private readTextByUri(uri: string): string {
    const path = this.resolveFilePath(uri);
    return fileIo.readTextSync(path);
  }

  private resolveFilePath(uri: string): string {
    if (uri.startsWith('file://')) {
      return new fileUri.FileUri(uri).path;
    }
    if (uri.startsWith('/')) {
      return uri;
    }
    return new fileUri.FileUri(uri).path;
  }

  private async collectBackupAttachments(ideas: Idea[], attachmentsDir: string): Promise<IdeaBackupAttachment[]> {
    const entries: IdeaBackupAttachment[] = [];
    for (const idea of ideas) {
      const asset = idea.asset;
      if (!asset?.localUri) {
        continue;
      }
      const sourcePath = this.resolveFilePath(asset.localUri);
      if (!fileIo.accessSync(sourcePath)) {
        continue;
      }
      const fileName = `${idea.id}-${this.safeName(asset.type || 'asset')}${this.extensionFromPath(sourcePath)}`;
      const relativePath = `attachments/${fileName}`;
      const destPath = `${attachmentsDir}/${fileName}`;
      fileIo.copyFileSync(sourcePath, destPath);
      entries.push({
        ideaId: idea.id,
        kind: asset.type || 'asset',
        sourcePath,
        relativePath
      });
    }
    return entries;
  }

  private readBackupManifest(extractDir: string): string {
    const rootManifest = `${extractDir}/manifest.json`;
    if (fileIo.accessSync(rootManifest)) {
      return fileIo.readTextSync(rootManifest);
    }
    const nestedManifest = `${extractDir}/payload/manifest.json`;
    if (fileIo.accessSync(nestedManifest)) {
      return fileIo.readTextSync(nestedManifest);
    }
    throw new Error('Backup manifest not found');
  }

  private cleanupBackupTemp(tempRoot: string): void {
    try {
      fileIo.rmdirSync(tempRoot);
    } catch {
      return;
    }
  }

  private extensionFromPath(path: string): string {
    const lastDot = path.lastIndexOf('.');
    if (lastDot < 0) {
      return '';
    }
    return path.substring(lastDot);
  }

  private safeName(value: string): string {
    return value.replace(/[^a-zA-Z0-9_-]/g, '_');
  }

  private inferAssetType(path: string, fallback: string): string {
    const lower = path.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif')) {
      return 'image';
    }
    if (lower.endsWith('.m4a') || lower.endsWith('.aac') || lower.endsWith('.mp3') || lower.endsWith('.wav')) {
      return 'audio';
    }
    if (fallback) {
      return fallback;
    }
    return 'manual';
  }

  private inferMimeType(path: string, fallback?: string): string | undefined {
    const lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.m4a') || lower.endsWith('.aac') || lower.endsWith('.mp3') || lower.endsWith('.wav')) {
      return 'audio/mp4';
    }
    return fallback;
  }

  private isImageLikeAsset(path: string): boolean {
    const lower = path.toLowerCase();
    return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  private isManagedAttachmentPath(path: string): boolean {
    const context = this.ensureContext();
    const normalized = this.resolveFilePath(path);
    return normalized.startsWith(context.filesDir);
  }

  private removeFileIfExists(path: string): void {
    const resolved = this.resolveFilePath(path);
    if (!fileIo.accessSync(resolved)) {
      return;
    }
    fileIo.unlinkSync(resolved);
  }

  private async persist(ideas: Idea[]): Promise<void> {
    await this.ensureStore().put(IDEAS_KEY, JSON.stringify(ideas));
    await this.ensureStore().flush();
  }

  private async persistFolders(folders: IdeaFolder[]): Promise<void> {
    await this.ensureStore().put(FOLDERS_KEY, JSON.stringify(folders));
    await this.ensureStore().flush();
  }

  private ensureStore(): preferences.Preferences {
    if (!this.pref) {
      throw new Error('IdeaRepository is not initialized');
    }
    return this.pref;
  }

  private ensureContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('IdeaRepository is not initialized');
    }
    return this.context;
  }

  private createId(): string {
    return `${Date.now()}-${Math.round(Math.random() * 1000000)}`;
  }

  private defaultTitle(type: IdeaType): string {
    if (type === IdeaType.AUDIO) {
      return `语音想法 ${new Date().toLocaleString()}`;
    }
    if (type === IdeaType.HANDWRITING) {
      return `手写想法 ${new Date().toLocaleString()}`;
    }
    return `文档想法 ${new Date().toLocaleString()}`;
  }

  private mergeIdeas(existing: Idea[], incoming: Idea[], strategy: ImportConflictStrategy): MergeResult {
    const map = new Map<string, Idea>();
    let inserted = 0;
    let updated = 0;
    let skipped = 0;
    const conflicts: string[] = [];

    for (const idea of existing) {
      map.set(idea.id, idea);
    }

    for (const idea of incoming) {
      if (!idea || typeof idea.id !== 'string') {
        skipped++;
        continue;
      }
      const current = map.get(idea.id);
      if (!current) {
        map.set(idea.id, idea);
        inserted++;
        continue;
      }
      const incomingNewer = Date.parse(idea.updatedAt) > Date.parse(current.updatedAt);
      const shouldOverwrite = strategy === ImportConflictStrategy.FORCE_OVERWRITE || incomingNewer;
      if (shouldOverwrite) {
        map.set(idea.id, idea);
        updated++;
      } else {
        conflicts.push(idea.id);
        skipped++;
      }
    }

    const result: MergeResult = {
      inserted,
      updated,
      skipped,
      conflicts,
      items: Array.from(map.values()).sort((a: Idea, b: Idea) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt))
    };
    return result;
  }

  private mergeFolders(existing: IdeaFolder[], incoming: IdeaFolder[], strategy: ImportConflictStrategy): IdeaFolder[] {
    const map = new Map<string, IdeaFolder>();
    for (const folder of existing) {
      map.set(folder.id, folder);
    }

    for (const folder of incoming) {
      if (!folder || typeof folder.id !== 'string') {
        continue;
      }
      const current = map.get(folder.id);
      if (!current) {
        map.set(folder.id, folder);
        continue;
      }
      const incomingNewer = Date.parse(folder.updatedAt) > Date.parse(current.updatedAt);
      const shouldOverwrite = strategy === ImportConflictStrategy.FORCE_OVERWRITE || incomingNewer;
      if (shouldOverwrite) {
        map.set(folder.id, folder);
      }
    }

    return Array.from(map.values()).sort((a: IdeaFolder, b: IdeaFolder) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private timestampStamp(): string {
    const now = new Date();
    const pad = (value: number): string => `${value}`.padStart(2, '0');
    return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  }
}

export const ideaRepository = new IdeaRepository();
