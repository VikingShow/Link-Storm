import relationalStore from '@ohos.data.relationalStore';
import { common } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import picker from '@ohos.file.picker';
import zlib from '@ohos.zlib';
import { CaptureDraftState, Idea, IdeaAsset, IdeaBackupAttachment, IdeaBackupPayload, IdeaDraft, IdeaExportPayload, IdeaFolder, IdeaTag, IdeaType, ImportConflictStrategy, ImportResult } from '../model/IdeaModels';

const STORE_NAME = 'link_storm_ideas';
const IDEAS_TABLE = 'ideas';
const FOLDERS_TABLE = 'folders';
const TAGS_TABLE = 'tags';
const CAPTURE_DRAFT_KEY = 'capture_draft_json';
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

type RdbStore = relationalStore.RdbStore;
type ValuesBucket = relationalStore.ValuesBucket;

export class IdeaRepository {
  private store?: RdbStore;
  private context?: common.UIAbilityContext;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.store = await relationalStore.getRdbStore(context, {
      name: STORE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
      encrypt: false,
      customDir: 'link-storm'
    });
    await this.ensureSchema();
  }

  async list(): Promise<Idea[]> {
    const resultSet = await this.ensureStore().query(new relationalStore.RdbPredicates(IDEAS_TABLE));
    try {
      return this.readIdeas(resultSet);
    } finally {
      resultSet.close();
    }
  }

  async listFolders(): Promise<IdeaFolder[]> {
    const resultSet = await this.ensureStore().query(new relationalStore.RdbPredicates(FOLDERS_TABLE));
    try {
      return this.readFolders(resultSet);
    } finally {
      resultSet.close();
    }
  }

  async listTags(): Promise<IdeaTag[]> {
    const resultSet = await this.ensureStore().query(new relationalStore.RdbPredicates(TAGS_TABLE));
    try {
      return this.readTags(resultSet);
    } finally {
      resultSet.close();
    }
  }

  async createTag(name: string, color: string = '#0B4F47'): Promise<IdeaTag> {
    const tag: IdeaTag = {
      id: this.createId(),
      name: name.trim() || '未命名标签',
      color,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await this.ensureStore().insert(TAGS_TABLE, this.tagToBucket(tag));
    return tag;
  }

  async updateTag(id: string, patch: Partial<IdeaTag>): Promise<void> {
    const current = await this.getTagById(id);
    if (!current) {
      return;
    }
    const next: IdeaTag = {
      id: current.id,
      name: patch.name ?? current.name,
      color: patch.color ?? current.color,
      createdAt: current.createdAt,
      updatedAt: new Date().toISOString()
    };
    await this.ensureStore().update(this.tagToBucket(next), this.predicatesFor(TAGS_TABLE, id));
  }

  async deleteTag(id: string): Promise<void> {
    await this.ensureStore().delete(this.predicatesFor(TAGS_TABLE, id));
  }

  async assignFolder(ids: string[], folderId?: string): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    const now = new Date().toISOString();
    for (const id of ids) {
      const current = await this.getById(id);
      if (!current) {
        continue;
      }
      const next: Idea = {
        id: current.id,
        title: current.title,
        type: current.type,
        plainText: current.plainText,
        note: current.note,
        tags: current.tags,
        folderId: folderId,
        context: current.context,
        asset: current.asset,
        isFavorite: current.isFavorite,
        isArchived: current.isArchived,
        syncStatus: current.syncStatus,
        aiStatus: current.aiStatus,
        createdAt: current.createdAt,
        updatedAt: now
      };
      await this.ensureStore().update(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id));
    }
  }

  async assignTags(ids: string[], tags: string[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    const mergedTags = Array.from(new Set(tags.map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0)));
    const now = new Date().toISOString();
    for (const id of ids) {
      const current = await this.getById(id);
      if (!current) {
        continue;
      }
      const nextTags: string[] = current.tags.slice();
      for (const tag of mergedTags) {
        if (!nextTags.includes(tag)) {
          nextTags.push(tag);
        }
      }
      const next: Idea = {
        id: current.id,
        title: current.title,
        type: current.type,
        plainText: current.plainText,
        note: current.note,
        tags: nextTags,
        folderId: current.folderId,
        context: current.context,
        asset: current.asset,
        isFavorite: current.isFavorite,
        isArchived: current.isArchived,
        syncStatus: current.syncStatus,
        aiStatus: current.aiStatus,
        createdAt: current.createdAt,
        updatedAt: now
      };
      await this.ensureStore().update(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id));
    }
  }

  async removeTags(ids: string[], tags: string[]): Promise<void> {
    if (ids.length === 0 || tags.length === 0) {
      return;
    }
    const removeSet = new Set(tags.map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0));
    const now = new Date().toISOString();
    for (const id of ids) {
      const current = await this.getById(id);
      if (!current) {
        continue;
      }
      const next: Idea = {
        id: current.id,
        title: current.title,
        type: current.type,
        plainText: current.plainText,
        note: current.note,
        tags: current.tags.filter((tag: string) => !removeSet.has(tag)),
        folderId: current.folderId,
        context: current.context,
        asset: current.asset,
        isFavorite: current.isFavorite,
        isArchived: current.isArchived,
        syncStatus: current.syncStatus,
        aiStatus: current.aiStatus,
        createdAt: current.createdAt,
        updatedAt: now
      };
      await this.ensureStore().update(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id));
    }
  }

  async createFolder(name: string, color: string = '#136F63'): Promise<IdeaFolder> {
    const folder: IdeaFolder = {
      id: this.createId(),
      name: name.trim() || '未命名文件夹',
      color,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    await this.ensureStore().insert(FOLDERS_TABLE, this.folderToBucket(folder));
    return folder;
  }

  async updateFolder(id: string, patch: Partial<IdeaFolder>): Promise<void> {
    const current = await this.getFolderById(id);
    if (!current) {
      return;
    }
    const next: IdeaFolder = {
      id: current.id,
      name: patch.name ?? current.name,
      color: patch.color ?? current.color,
      createdAt: current.createdAt,
      updatedAt: new Date().toISOString()
    };
    await this.ensureStore().update(this.folderToBucket(next), this.predicatesFor(FOLDERS_TABLE, id));
  }

  async deleteFolder(id: string, reassignIdeaFolderId?: string): Promise<void> {
    await this.ensureStore().delete(this.predicatesFor(FOLDERS_TABLE, id));
    const ideas = await this.list();
    const now = new Date().toISOString();
    for (const idea of ideas.filter((item: Idea) => item.folderId === id)) {
      const next: Idea = {
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
      };
      await this.ensureStore().update(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, idea.id));
    }
  }

  async save(draft: IdeaDraft): Promise<Idea> {
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
    await this.ensureStore().insert(IDEAS_TABLE, this.ideaToBucket(idea));
    return idea;
  }

  async update(id: string, patch: Partial<Idea>): Promise<void> {
    const current = await this.getById(id);
    if (!current) {
      return;
    }
    const next: Idea = {
      id: current.id,
      title: patch.title ?? current.title,
      type: patch.type ?? current.type,
      plainText: patch.plainText ?? current.plainText,
      note: patch.note ?? current.note,
      tags: patch.tags ?? current.tags,
      folderId: patch.folderId ?? current.folderId,
      context: patch.context ?? current.context,
      asset: patch.asset ?? current.asset,
      isFavorite: patch.isFavorite ?? current.isFavorite,
      isArchived: patch.isArchived ?? current.isArchived,
      syncStatus: patch.syncStatus ?? current.syncStatus,
      aiStatus: patch.aiStatus ?? current.aiStatus,
      createdAt: current.createdAt,
      updatedAt: new Date().toISOString()
    };
    await this.ensureStore().update(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id));
  }

  async saveCaptureDraft(draft: CaptureDraftState): Promise<void> {
    const context = this.ensureContext();
    this.writeTextFile(`${context.filesDir}/${CAPTURE_DRAFT_KEY}`, JSON.stringify(draft));
  }

  async loadCaptureDraft(): Promise<CaptureDraftState | undefined> {
    const context = this.ensureContext();
    const path = `${context.filesDir}/${CAPTURE_DRAFT_KEY}`;
    if (!fileIo.accessSync(path)) {
      return undefined;
    }
    try {
      return JSON.parse(fileIo.readTextSync(path)) as CaptureDraftState;
    } catch {
      return undefined;
    }
  }

  async clearCaptureDraft(): Promise<void> {
    const context = this.ensureContext();
    const path = `${context.filesDir}/${CAPTURE_DRAFT_KEY}`;
    if (fileIo.accessSync(path)) {
      fileIo.unlinkSync(path);
    }
  }

  async delete(id: string): Promise<void> {
    await this.ensureStore().delete(this.predicatesFor(IDEAS_TABLE, id));
  }

  async getById(id: string): Promise<Idea | undefined> {
    const resultSet = await this.ensureStore().query(this.predicatesFor(IDEAS_TABLE, id));
    try {
      const ideas = this.readIdeas(resultSet);
      return ideas.length > 0 ? ideas[0] : undefined;
    } finally {
      resultSet.close();
    }
  }

  async exportJson(): Promise<string> {
    return JSON.stringify({
      schema: EXPORT_SCHEMA,
      version: 1,
      exportedAt: new Date().toISOString(),
      ideas: await this.list(),
      folders: await this.listFolders(),
      tags: await this.listTags()
    } as IdeaExportPayload, null, 2);
  }

  async exportSummary(): Promise<string> {
    const ideas = await this.list();
    const active = ideas.filter((idea: Idea) => !idea.isArchived).length;
    const archived = ideas.length - active;
    const favorite = ideas.filter((idea: Idea) => idea.isFavorite).length;
    return `总计${ideas.length}，收藏${favorite}，归档${archived}，活跃${active}`;
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
    this.writeTextFile(path, await this.exportJson());
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

    const backup: IdeaBackupPayload = {
      schema: BACKUP_SCHEMA,
      version: 1,
      exportedAt: new Date().toISOString(),
      ideas: await this.list(),
      folders: await this.listFolders(),
      tags: await this.listTags(),
      attachments: await this.collectBackupAttachments(await this.list(), attachmentsDir)
    };
    this.writeTextFile(manifestPath, JSON.stringify(backup, null, 2));
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
    return this.importJson(fileIo.readTextSync(this.resolveFilePath(uris[0])), strategy);
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
    const merged = await this.importPayloadIdeas(parsed.ideas, strategy);
    if (Array.isArray(parsed.folders)) {
      await this.replaceFolders(this.mergeFolders(await this.listFolders(), parsed.folders, strategy));
    }
    if (Array.isArray(parsed.tags)) {
      await this.replaceTags(this.mergeTags(await this.listTags(), parsed.tags, strategy));
    }
    this.cleanupBackupTemp(tempRoot);
    return merged;
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
    const merged = await this.importPayloadIdeas(parsed.ideas as Idea[], strategy);
    if (Array.isArray(parsed.folders)) {
      await this.replaceFolders(this.mergeFolders(await this.listFolders(), parsed.folders as IdeaFolder[], strategy));
    }
    if (Array.isArray(parsed.tags)) {
      await this.replaceTags(this.mergeTags(await this.listTags(), parsed.tags as IdeaTag[], strategy));
    }
    return merged;
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

  private async ensureSchema(): Promise<void> {
    await this.ensureStore().executeSql(`CREATE TABLE IF NOT EXISTS ${IDEAS_TABLE} (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      type TEXT NOT NULL,
      plainText TEXT NOT NULL,
      note TEXT NOT NULL,
      tags TEXT NOT NULL,
      folderId TEXT,
      contextTitle TEXT NOT NULL,
      contextUrl TEXT NOT NULL,
      contextManualNote TEXT NOT NULL,
      contextCapturedAt TEXT NOT NULL,
      assetJson TEXT,
      isFavorite INTEGER NOT NULL,
      isArchived INTEGER NOT NULL,
      syncStatus TEXT NOT NULL,
      aiStatus TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )`);
    await this.ensureStore().executeSql(`CREATE TABLE IF NOT EXISTS ${FOLDERS_TABLE} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )`);
    await this.ensureStore().executeSql(`CREATE TABLE IF NOT EXISTS ${TAGS_TABLE} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )`);
  }

  private async importPayloadIdeas(incoming: Idea[], strategy: ImportConflictStrategy): Promise<ImportResult> {
    const existing = await this.list();
    const merged = this.mergeIdeas(existing, incoming, strategy);
    await this.replaceIdeas(merged.items);
    return {
      inserted: merged.inserted,
      updated: merged.updated,
      skipped: merged.skipped,
      conflicts: merged.conflicts
    };
  }

  private async replaceIdeas(items: Idea[]): Promise<void> {
    await this.ensureStore().delete(new relationalStore.RdbPredicates(IDEAS_TABLE));
    for (const item of items) {
      await this.ensureStore().insert(IDEAS_TABLE, this.ideaToBucket(item));
    }
  }

  private async replaceFolders(items: IdeaFolder[]): Promise<void> {
    await this.ensureStore().delete(new relationalStore.RdbPredicates(FOLDERS_TABLE));
    for (const item of items) {
      await this.ensureStore().insert(FOLDERS_TABLE, this.folderToBucket(item));
    }
  }

  private async replaceTags(items: IdeaTag[]): Promise<void> {
    await this.ensureStore().delete(new relationalStore.RdbPredicates(TAGS_TABLE));
    for (const item of items) {
      await this.ensureStore().insert(TAGS_TABLE, this.tagToBucket(item));
    }
  }

  private readIdeas(resultSet: relationalStore.ResultSet): Idea[] {
    const items: Idea[] = [];
    while (resultSet.goToNextRow()) {
      items.push(this.rowToIdea(resultSet));
    }
    return items.sort((a: Idea, b: Idea) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private readFolders(resultSet: relationalStore.ResultSet): IdeaFolder[] {
    const items: IdeaFolder[] = [];
    while (resultSet.goToNextRow()) {
      items.push(this.rowToFolder(resultSet));
    }
    return items.sort((a: IdeaFolder, b: IdeaFolder) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private readTags(resultSet: relationalStore.ResultSet): IdeaTag[] {
    const items: IdeaTag[] = [];
    while (resultSet.goToNextRow()) {
      items.push(this.rowToTag(resultSet));
    }
    return items.sort((a: IdeaTag, b: IdeaTag) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private rowToIdea(resultSet: relationalStore.ResultSet): Idea {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      type: resultSet.getString(resultSet.getColumnIndex('type')) as IdeaType,
      plainText: resultSet.getString(resultSet.getColumnIndex('plainText')),
      note: resultSet.getString(resultSet.getColumnIndex('note')),
      tags: JSON.parse(resultSet.getString(resultSet.getColumnIndex('tags'))) as string[],
      folderId: this.readNullableString(resultSet, 'folderId') || undefined,
      context: {
        title: resultSet.getString(resultSet.getColumnIndex('contextTitle')),
        url: resultSet.getString(resultSet.getColumnIndex('contextUrl')),
        manualNote: resultSet.getString(resultSet.getColumnIndex('contextManualNote')),
        capturedAt: resultSet.getString(resultSet.getColumnIndex('contextCapturedAt'))
      },
      asset: this.parseAssetJson(this.readNullableString(resultSet, 'assetJson')),
      isFavorite: resultSet.getLong(resultSet.getColumnIndex('isFavorite')) === 1,
      isArchived: resultSet.getLong(resultSet.getColumnIndex('isArchived')) === 1,
      syncStatus: resultSet.getString(resultSet.getColumnIndex('syncStatus')),
      aiStatus: resultSet.getString(resultSet.getColumnIndex('aiStatus')),
      createdAt: resultSet.getString(resultSet.getColumnIndex('createdAt')),
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updatedAt'))
    };
  }

  private rowToFolder(resultSet: relationalStore.ResultSet): IdeaFolder {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      name: resultSet.getString(resultSet.getColumnIndex('name')),
      color: resultSet.getString(resultSet.getColumnIndex('color')),
      createdAt: resultSet.getString(resultSet.getColumnIndex('createdAt')),
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updatedAt'))
    };
  }

  private rowToTag(resultSet: relationalStore.ResultSet): IdeaTag {
    return {
      id: resultSet.getString(resultSet.getColumnIndex('id')),
      name: resultSet.getString(resultSet.getColumnIndex('name')),
      color: resultSet.getString(resultSet.getColumnIndex('color')),
      createdAt: resultSet.getString(resultSet.getColumnIndex('createdAt')),
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updatedAt'))
    };
  }

  private ideaToBucket(idea: Idea): ValuesBucket {
    return {
      id: idea.id,
      title: idea.title,
      type: idea.type,
      plainText: idea.plainText,
      note: idea.note,
      tags: JSON.stringify(idea.tags),
      folderId: idea.folderId || null,
      contextTitle: idea.context.title,
      contextUrl: idea.context.url,
      contextManualNote: idea.context.manualNote,
      contextCapturedAt: idea.context.capturedAt,
      assetJson: idea.asset ? JSON.stringify(idea.asset) : null,
      isFavorite: idea.isFavorite ? 1 : 0,
      isArchived: idea.isArchived ? 1 : 0,
      syncStatus: idea.syncStatus,
      aiStatus: idea.aiStatus,
      createdAt: idea.createdAt,
      updatedAt: idea.updatedAt
    };
  }

  private folderToBucket(folder: IdeaFolder): ValuesBucket {
    return {
      id: folder.id,
      name: folder.name,
      color: folder.color,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt
    };
  }

  private tagToBucket(tag: IdeaTag): ValuesBucket {
    return {
      id: tag.id,
      name: tag.name,
      color: tag.color,
      createdAt: tag.createdAt,
      updatedAt: tag.updatedAt
    };
  }

  private parseAssetJson(value: string | undefined): IdeaAsset | undefined {
    if (!value) {
      return undefined;
    }
    try {
      return JSON.parse(value) as IdeaAsset;
    } catch {
      return undefined;
    }
  }

  private readNullableString(resultSet: relationalStore.ResultSet, columnName: string): string {
    const idx = resultSet.getColumnIndex(columnName);
    if (idx < 0) {
      return '';
    }
    const value = resultSet.getString(idx);
    return value ?? '';
  }

  private async getFolderById(id: string): Promise<IdeaFolder | undefined> {
    const resultSet = await this.ensureStore().query(this.predicatesFor(FOLDERS_TABLE, id));
    try {
      const items = this.readFolders(resultSet);
      return items.length > 0 ? items[0] : undefined;
    } finally {
      resultSet.close();
    }
  }

  private async getTagById(id: string): Promise<IdeaTag | undefined> {
    const resultSet = await this.ensureStore().query(this.predicatesFor(TAGS_TABLE, id));
    try {
      const items = this.readTags(resultSet);
      return items.length > 0 ? items[0] : undefined;
    } finally {
      resultSet.close();
    }
  }

  private predicatesFor(table: string, id: string): relationalStore.RdbPredicates {
    return new relationalStore.RdbPredicates(table).equalTo('id', id);
  }

  private ensureStore(): RdbStore {
    if (!this.store) {
      throw new Error('IdeaRepository is not initialized');
    }
    return this.store;
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

    return {
      inserted,
      updated,
      skipped,
      conflicts,
      items: Array.from(map.values()).sort((a: Idea, b: Idea) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt))
    };
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
      if (!current || strategy === ImportConflictStrategy.FORCE_OVERWRITE || Date.parse(folder.updatedAt) > Date.parse(current.updatedAt)) {
        map.set(folder.id, folder);
      }
    }
    return Array.from(map.values()).sort((a: IdeaFolder, b: IdeaFolder) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private mergeTags(existing: IdeaTag[], incoming: IdeaTag[], strategy: ImportConflictStrategy): IdeaTag[] {
    const map = new Map<string, IdeaTag>();
    for (const tag of existing) {
      map.set(tag.id, tag);
    }
    for (const tag of incoming) {
      if (!tag || typeof tag.id !== 'string') {
        continue;
      }
      const current = map.get(tag.id);
      if (!current || strategy === ImportConflictStrategy.FORCE_OVERWRITE || Date.parse(tag.updatedAt) > Date.parse(current.updatedAt)) {
        map.set(tag.id, tag);
      }
    }
    return Array.from(map.values()).sort((a: IdeaTag, b: IdeaTag) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
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
    return fallback || 'manual';
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

  private writeTextFile(path: string, text: string): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(file.fd, text, { encoding: 'utf-8' });
    } finally {
      fileIo.closeSync(file);
    }
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

  private timestampStamp(): string {
    return new Date().toISOString().replace(/[:.]/g, '-');
  }

  private async readAllIdeas(): Promise<Idea[]> {
    return this.list();
  }
}

export const ideaRepository = new IdeaRepository();
