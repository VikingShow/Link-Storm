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
const CAPTURE_DRAFT_TABLE = 'capture_draft_state';
const CAPTURE_DRAFT_ID = 'capture_draft';
const CAPTURE_DRAFT_KEY = 'capture_draft_json';
const EXPORT_SCHEMA = 'link-storm-local-capture-export';
const EXPORT_FILE_SUFFIX = '.json';
const MARKDOWN_EXPORT_FILE_SUFFIX = '.md';
const TXT_EXPORT_FILE_SUFFIX = '.txt';
const BACKUP_SCHEMA = 'link-storm-backup';
const BACKUP_FILE_SUFFIX = '.zip';

interface MergeResult {
  inserted: number;
  updated: number;
  skipped: number;
  conflicts: string[];
  items: Idea[];
}

interface CaptureDraftRecord {
  id: string;
  payload: string;
  savedAt: string;
}

type RdbStore = relationalStore.RdbStore;
type ValuesBucket = relationalStore.ValuesBucket;

export class IdeaRepository {
  private store?: RdbStore;
  private context?: common.UIAbilityContext;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.store = await relationalStore.getRdbStore(context, {
        name: STORE_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
        encrypt: false,
        customDir: 'link-storm'
      });
    } catch (err) {
      this.store = undefined;
      throw new Error(`初始化本地数据库失败：${String(err)}`);
    }
    await this.ensureSchema();
  }

  async list(): Promise<Idea[]> {
    const resultSet = await this.queryRowsGuarded(new relationalStore.RdbPredicates(IDEAS_TABLE), '读取想法列表失败');
    try {
      return this.readIdeas(resultSet);
    } finally {
      this.closeResultSet(resultSet);
    }
  }

  async listFolders(): Promise<IdeaFolder[]> {
    const resultSet = await this.queryRowsGuarded(new relationalStore.RdbPredicates(FOLDERS_TABLE), '读取文件夹列表失败');
    try {
      return this.readFolders(resultSet);
    } finally {
      this.closeResultSet(resultSet);
    }
  }

  async listTags(): Promise<IdeaTag[]> {
    const resultSet = await this.queryRowsGuarded(new relationalStore.RdbPredicates(TAGS_TABLE), '读取标签列表失败');
    try {
      return this.readTags(resultSet);
    } finally {
      this.closeResultSet(resultSet);
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
    await this.insertRowGuarded(TAGS_TABLE, this.tagToBucket(tag), '创建标签失败');
    return tag;
  }

  async updateTag(id: string, patch: Partial<IdeaTag>): Promise<void> {
    const current = await this.getTagById(id);
    if (!current) {
      return;
    }
    const nextName = patch.name ?? current.name;
    const next: IdeaTag = {
      id: current.id,
      name: nextName,
      color: patch.color ?? current.color,
      createdAt: current.createdAt,
      updatedAt: new Date().toISOString()
    };
    await this.updateRowsGuarded(this.tagToBucket(next), this.predicatesFor(TAGS_TABLE, id), '更新标签失败');
    if (current.name !== nextName) {
      await this.renameTagInIdeas(current.name, nextName);
    }
  }

  async deleteTag(id: string): Promise<void> {
    const current = await this.getTagById(id);
    await this.deleteRowsGuarded(this.predicatesFor(TAGS_TABLE, id), '删除标签失败');
    if (!current) {
      return;
    }
    const ideas = await this.list();
    const affected = ideas.filter((idea: Idea) => idea.tags.includes(current.name));
    if (affected.length === 0) {
      return;
    }
    await this.removeTags(affected.map((idea: Idea) => idea.id), [current.name]);
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
      await this.updateRowsGuarded(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id), '更新想法文件夹失败');
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
      await this.updateRowsGuarded(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id), '更新想法标签失败');
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
      await this.updateRowsGuarded(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id), '移除想法标签失败');
    }
  }

  private async renameTagInIdeas(oldName: string, newName: string): Promise<void> {
    const normalizedOld = oldName.trim();
    const normalizedNew = newName.trim();
    if (normalizedOld.length === 0 || normalizedNew.length === 0 || normalizedOld === normalizedNew) {
      return;
    }
    const ideas = await this.list();
    const now = new Date().toISOString();
    for (const idea of ideas.filter((item: Idea) => item.tags.includes(normalizedOld))) {
      const nextTags: string[] = [];
      for (const tag of idea.tags) {
        const nextTag = tag === normalizedOld ? normalizedNew : tag;
        if (!nextTags.includes(nextTag)) {
          nextTags.push(nextTag);
        }
      }
      const next: Idea = {
        id: idea.id,
        title: idea.title,
        type: idea.type,
        plainText: idea.plainText,
        note: idea.note,
        tags: nextTags,
        folderId: idea.folderId,
        context: idea.context,
        asset: idea.asset,
        isFavorite: idea.isFavorite,
        isArchived: idea.isArchived,
        syncStatus: idea.syncStatus,
        aiStatus: idea.aiStatus,
        createdAt: idea.createdAt,
        updatedAt: now
      };
      await this.updateRowsGuarded(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, idea.id), '同步想法标签失败');
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
    await this.insertRowGuarded(FOLDERS_TABLE, this.folderToBucket(folder), '创建文件夹失败');
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
    await this.updateRowsGuarded(this.folderToBucket(next), this.predicatesFor(FOLDERS_TABLE, id), '更新文件夹失败');
  }

  async deleteFolder(id: string, reassignIdeaFolderId?: string): Promise<void> {
    await this.deleteRowsGuarded(this.predicatesFor(FOLDERS_TABLE, id), '删除文件夹失败');
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
      await this.updateRowsGuarded(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, idea.id), '重分配想法文件夹失败');
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
    await this.insertRowGuarded(IDEAS_TABLE, this.ideaToBucket(idea), '保存想法失败');
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
    await this.updateRowsGuarded(this.ideaToBucket(next), this.predicatesFor(IDEAS_TABLE, id), '更新想法失败');
  }

  async saveCaptureDraft(draft: CaptureDraftState): Promise<void> {
    const record: CaptureDraftRecord = {
      id: CAPTURE_DRAFT_ID,
      payload: JSON.stringify(draft),
      savedAt: draft.savedAt || new Date().toISOString()
    };
    const predicates = this.predicatesFor(CAPTURE_DRAFT_TABLE, CAPTURE_DRAFT_ID);
    const existing = await this.queryRowsGuarded(predicates, '读取捕捉草稿失败');
    try {
      if (this.goToFirstRow(existing)) {
        await this.updateRowsGuarded(this.captureDraftToBucket(record), predicates, '更新捕捉草稿失败');
      } else {
        await this.insertRowGuarded(CAPTURE_DRAFT_TABLE, this.captureDraftToBucket(record), '保存捕捉草稿失败');
      }
    } finally {
      this.closeResultSet(existing);
    }
  }

  async loadCaptureDraft(): Promise<CaptureDraftState | undefined> {
    const resultSet = await this.queryRowsGuarded(this.predicatesFor(CAPTURE_DRAFT_TABLE, CAPTURE_DRAFT_ID), '读取捕捉草稿失败');
    try {
      if (this.goToFirstRow(resultSet)) {
        return this.parseCaptureDraft(this.readString(resultSet, 'payload'));
      }
    } finally {
      this.closeResultSet(resultSet);
    }
    const legacyDraft = this.loadLegacyCaptureDraft();
    if (legacyDraft) {
      await this.saveCaptureDraft(legacyDraft);
      this.clearLegacyCaptureDraft();
    }
    return legacyDraft;
  }

  async clearCaptureDraft(): Promise<void> {
    await this.deleteRowsGuarded(this.predicatesFor(CAPTURE_DRAFT_TABLE, CAPTURE_DRAFT_ID), '清除捕捉草稿失败');
    this.clearLegacyCaptureDraft();
  }

  async delete(id: string): Promise<void> {
    const current = await this.getById(id);
    await this.deleteRowsGuarded(this.predicatesFor(IDEAS_TABLE, id), '删除想法失败');
    this.cleanupManagedIdeaAssetFiles(current?.asset);
  }

  async getById(id: string): Promise<Idea | undefined> {
    const resultSet = await this.queryRowsGuarded(this.predicatesFor(IDEAS_TABLE, id), '读取想法详情失败');
    try {
      const ideas = this.readIdeas(resultSet);
      return ideas.length > 0 ? ideas[0] : undefined;
    } finally {
      this.closeResultSet(resultSet);
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
    return this.exportTextContentToFile(await this.exportJson(), `link-storm-export-${this.timestampStamp()}${EXPORT_FILE_SUFFIX}`, ['JSON|json']);
  }

  async exportMarkdownToFile(content: string): Promise<string> {
    return this.exportTextContentToFile(content, `link-storm-export-${this.timestampStamp()}${MARKDOWN_EXPORT_FILE_SUFFIX}`, ['Markdown|md']);
  }

  async exportPlainTextToFile(content: string): Promise<string> {
    return this.exportTextContentToFile(content, `link-storm-export-${this.timestampStamp()}${TXT_EXPORT_FILE_SUFFIX}`, ['Text|txt']);
  }

  private async exportTextContentToFile(content: string, fileName: string, fileSuffixChoices: string[]): Promise<string> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const uris = await pickerInstance.save({
      newFileNames: [fileName],
      defaultFilePathUri: fileUri.getUriFromPath(context.filesDir),
      fileSuffixChoices
    });
    if (uris.length === 0) {
      throw new Error('已取消导出');
    }
    const target = uris[0];
    const path = this.resolveFilePath(target);
    this.writeTextFile(path, content);
    return target;
  }

  async exportBackupZip(): Promise<string> {
    const context = this.ensureContext();
    const tempRoot = `${context.cacheDir}/link-storm-backup-${Date.now()}`;
    const payloadDir = `${tempRoot}/payload`;
    const attachmentsDir = `${payloadDir}/attachments`;
    const manifestPath = `${payloadDir}/manifest.json`;
    const archivePath = `${context.filesDir}/link-storm-backup-${this.timestampStamp()}${BACKUP_FILE_SUFFIX}`;
    this.ensureDirectory(tempRoot);
    this.ensureDirectory(payloadDir);
    this.ensureDirectory(attachmentsDir);

    try {
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
      await this.compressDirectoryGuarded(payloadDir, archivePath);
      return archivePath;
    } finally {
      this.cleanupBackupTemp(tempRoot);
    }
  }

  async importFromFile(strategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER): Promise<ImportResult> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const uris = await pickerInstance.select();
    if (uris.length === 0) {
      throw new Error('已取消导入');
    }
    return this.importJson(this.readTextFileGuarded(this.resolveFilePath(uris[0]), '读取导入文件失败'), strategy);
  }

  async importBackupZip(strategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER): Promise<ImportResult> {
    const context = this.ensureContext();
    const pickerInstance = new picker.DocumentViewPicker(context);
    const uris = await pickerInstance.select();
    if (uris.length === 0) {
      throw new Error('已取消导入');
    }
    const zipPath = this.resolveFilePath(uris[0]);
    const tempRoot = `${context.cacheDir}/link-storm-import-${Date.now()}`;
    const extractDir = `${tempRoot}/extract`;
    this.ensureDirectory(tempRoot);
    this.ensureDirectory(extractDir);
    try {
      await this.decompressArchiveGuarded(zipPath, extractDir);
      const manifest = this.readBackupManifest(extractDir);
      const parsed = JSON.parse(manifest) as IdeaBackupPayload;
      if (parsed.schema !== BACKUP_SCHEMA) {
        throw new Error('备份格式不正确');
      }
      const attachmentsDir = this.prepareImportAttachmentsDir();
      const attachmentMap = this.extractBackupAttachments(parsed.attachments, extractDir, attachmentsDir);
      const importedIdeas = this.attachImportedAssets(parsed.ideas, attachmentMap);
      const merged = await this.importPayloadIdeas(importedIdeas, strategy);
      if (Array.isArray(parsed.folders)) {
        await this.replaceFolders(this.mergeFolders(await this.listFolders(), parsed.folders, strategy));
      }
      if (Array.isArray(parsed.tags)) {
        await this.replaceTags(this.mergeTags(await this.listTags(), parsed.tags, strategy));
      }
      return merged;
    } finally {
      this.cleanupBackupTemp(tempRoot);
    }
  }

  async importJson(payload: string, strategy: ImportConflictStrategy = ImportConflictStrategy.KEEP_NEWER): Promise<ImportResult> {
    let parsed: Partial<IdeaExportPayload>;
    try {
      parsed = JSON.parse(payload) as Partial<IdeaExportPayload>;
    } catch (err) {
      throw new Error(`JSON 内容不正确：${String(err)}`);
    }
    if (parsed.schema !== EXPORT_SCHEMA) {
      throw new Error('导出格式不正确');
    }
    if (!Array.isArray(parsed.ideas)) {
      throw new Error('想法数据不正确');
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
      throw new Error('想法不存在');
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
    this.cleanupManagedIdeaAssetFiles(current.asset, [nextAsset.localUri, nextAsset.previewPath || '']);
    return nextAsset;
  }

  async importSharedAttachment(ideaId: string, sourceUri: string): Promise<IdeaAsset | undefined> {
    const sourcePath = this.resolveFilePath(sourceUri);
    const current = await this.getById(ideaId);
    if (!current) {
      throw new Error('想法不存在');
    }
    const copiedPath = await this.copyAttachmentToIdeaStorage(sourcePath, ideaId, 'shared');
    const nextAsset: IdeaAsset = {
      type: this.inferAssetType(sourcePath, current.asset?.type || 'shared'),
      localUri: copiedPath,
      mimeType: this.inferMimeType(sourcePath, current.asset?.mimeType),
      previewPath: this.isImageLikeAsset(sourcePath) ? copiedPath : (current.asset?.previewPath || undefined),
      durationMs: current.asset?.durationMs,
      strokes: current.asset?.strokes
    };
    await this.update(ideaId, { asset: nextAsset });
    this.cleanupManagedIdeaAssetFiles(current.asset, [nextAsset.localUri, nextAsset.previewPath || '']);
    return nextAsset;
  }

  async clearIdeaAsset(ideaId: string): Promise<void> {
    const current = await this.getById(ideaId);
    if (!current) {
      throw new Error('想法不存在');
    }
    await this.update(ideaId, { asset: undefined });
    this.cleanupManagedIdeaAssetFiles(current.asset);
  }

  async copyAttachmentToIdeaStorage(sourcePath: string, ideaId: string, kind: string): Promise<string> {
    const context = this.ensureContext();
    const attachmentsDir = `${context.filesDir}/idea-attachments`;
    this.ensureDirectory(attachmentsDir);
    const safeKind = this.safeName(kind || 'asset');
    const targetPath = `${attachmentsDir}/${ideaId}-${safeKind}-${Date.now()}${this.extensionFromPath(sourcePath)}`;
    try {
      fileIo.copyFileSync(sourcePath, targetPath);
    } catch (err) {
      throw new Error(`复制附件失败：${String(err)}`);
    }
    return targetPath;
  }

  private async ensureSchema(): Promise<void> {
    await this.executeSqlGuarded(`CREATE TABLE IF NOT EXISTS ${IDEAS_TABLE} (
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
    )`, '初始化想法表失败');
    await this.executeSqlGuarded(`CREATE TABLE IF NOT EXISTS ${FOLDERS_TABLE} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )`, '初始化文件夹表失败');
    await this.executeSqlGuarded(`CREATE TABLE IF NOT EXISTS ${TAGS_TABLE} (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )`, '初始化标签表失败');
    await this.executeSqlGuarded(`CREATE TABLE IF NOT EXISTS ${CAPTURE_DRAFT_TABLE} (
      id TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      savedAt TEXT NOT NULL
    )`, '初始化捕捉草稿表失败');
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
    const existing = await this.list();
    const keepPaths = this.collectManagedAssetPaths(items);
    await this.deleteTableRowsGuarded(IDEAS_TABLE, '清空想法表失败');
    for (const item of items) {
      await this.insertRowGuarded(IDEAS_TABLE, this.ideaToBucket(item), '写入想法数据失败');
    }
    for (const item of existing) {
      this.cleanupManagedIdeaAssetFiles(item.asset, keepPaths);
    }
  }

  private async replaceFolders(items: IdeaFolder[]): Promise<void> {
    await this.deleteTableRowsGuarded(FOLDERS_TABLE, '清空文件夹表失败');
    for (const item of items) {
      await this.insertRowGuarded(FOLDERS_TABLE, this.folderToBucket(item), '写入文件夹数据失败');
    }
  }

  private async replaceTags(items: IdeaTag[]): Promise<void> {
    await this.deleteTableRowsGuarded(TAGS_TABLE, '清空标签表失败');
    for (const item of items) {
      await this.insertRowGuarded(TAGS_TABLE, this.tagToBucket(item), '写入标签数据失败');
    }
  }

  private prepareImportAttachmentsDir(): string {
    const context = this.ensureContext();
    const attachmentsDir = `${context.filesDir}/idea-attachments`;
    this.ensureDirectory(attachmentsDir);
    return attachmentsDir;
  }

  private extractBackupAttachments(attachments: IdeaBackupAttachment[] | undefined, extractDir: string, attachmentsDir: string): Map<string, string> {
    const map = new Map<string, string>();
    if (!Array.isArray(attachments)) {
      return map;
    }
    for (const attachment of attachments) {
      const sourcePath = `${extractDir}/${attachment.relativePath}`;
      if (!this.fileExists(sourcePath)) {
        continue;
      }
      const role = attachment.role || 'localUri';
      const fileName = `${attachment.ideaId}-${this.safeName(role)}-${this.safeName(attachment.kind || 'asset')}-${Date.now()}${this.extensionFromPath(sourcePath)}`;
      const targetPath = `${attachmentsDir}/${fileName}`;
      try {
        fileIo.copyFileSync(sourcePath, targetPath);
        map.set(`${attachment.ideaId}:${role}`, targetPath);
      } catch {
        // Skip attachments that cannot be restored from the backup archive.
      }
    }
    return map;
  }

  private attachImportedAssets(ideas: Idea[], attachmentMap: Map<string, string>): Idea[] {
    return ideas.map((idea: Idea) => {
      const localUri = attachmentMap.get(`${idea.id}:localUri`);
      const previewPath = attachmentMap.get(`${idea.id}:previewPath`);
      if (!localUri && !previewPath) {
        return idea;
      }
      const nextAsset: IdeaAsset = this.copyImportedAsset(idea, localUri || '');
      if (localUri) {
        nextAsset.localUri = localUri;
      }
      if (previewPath) {
        nextAsset.previewPath = previewPath;
      } else if (localUri && !nextAsset.previewPath && this.isImageLikeAsset(localUri)) {
        nextAsset.previewPath = localUri;
      }
      return this.copyImportedIdeaWithAsset(idea, nextAsset);
    });
  }

  private copyImportedAsset(idea: Idea, fallbackLocalUri: string): IdeaAsset {
    if (!idea.asset) {
      return {
        type: idea.type,
        localUri: fallbackLocalUri
      };
    }
    return {
      type: idea.asset.type,
      localUri: idea.asset.localUri,
      mimeType: idea.asset.mimeType,
      durationMs: idea.asset.durationMs,
      strokes: idea.asset.strokes,
      previewPath: idea.asset.previewPath
    };
  }

  private copyImportedIdeaWithAsset(idea: Idea, asset: IdeaAsset): Idea {
    return {
      id: idea.id,
      title: idea.title,
      type: idea.type,
      plainText: idea.plainText,
      note: idea.note,
      tags: idea.tags,
      folderId: idea.folderId,
      context: idea.context,
      asset,
      isFavorite: idea.isFavorite,
      isArchived: idea.isArchived,
      syncStatus: idea.syncStatus,
      aiStatus: idea.aiStatus,
      createdAt: idea.createdAt,
      updatedAt: idea.updatedAt
    };
  }

  private readIdeas(resultSet: relationalStore.ResultSet): Idea[] {
    const items: Idea[] = [];
    while (this.goToNextRow(resultSet)) {
      try {
        items.push(this.rowToIdea(resultSet));
      } catch {
        // Skip rows that cannot be converted into a valid idea.
      }
    }
    return items.sort((a: Idea, b: Idea) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private readFolders(resultSet: relationalStore.ResultSet): IdeaFolder[] {
    const items: IdeaFolder[] = [];
    while (this.goToNextRow(resultSet)) {
      try {
        items.push(this.rowToFolder(resultSet));
      } catch {
        // Skip rows that cannot be converted into a valid folder.
      }
    }
    return items.sort((a: IdeaFolder, b: IdeaFolder) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private readTags(resultSet: relationalStore.ResultSet): IdeaTag[] {
    const items: IdeaTag[] = [];
    while (this.goToNextRow(resultSet)) {
      try {
        items.push(this.rowToTag(resultSet));
      } catch {
        // Skip rows that cannot be converted into a valid tag.
      }
    }
    return items.sort((a: IdeaTag, b: IdeaTag) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  }

  private rowToIdea(resultSet: relationalStore.ResultSet): Idea {
    const now = new Date().toISOString();
    return {
      id: this.readString(resultSet, 'id', this.createId()),
      title: this.readString(resultSet, 'title', '未命名想法'),
      type: this.readIdeaType(resultSet),
      plainText: this.readString(resultSet, 'plainText'),
      note: this.readString(resultSet, 'note'),
      tags: this.parseTagsJson(this.readString(resultSet, 'tags', '[]')),
      folderId: this.readNullableString(resultSet, 'folderId') || undefined,
      context: {
        title: this.readString(resultSet, 'contextTitle'),
        url: this.readString(resultSet, 'contextUrl'),
        manualNote: this.readString(resultSet, 'contextManualNote'),
        capturedAt: this.readString(resultSet, 'contextCapturedAt', now)
      },
      asset: this.parseAssetJson(this.readNullableString(resultSet, 'assetJson')),
      isFavorite: this.readLong(resultSet, 'isFavorite') === 1,
      isArchived: this.readLong(resultSet, 'isArchived') === 1,
      syncStatus: this.readString(resultSet, 'syncStatus', 'local_only'),
      aiStatus: this.readString(resultSet, 'aiStatus', 'not_processed'),
      createdAt: this.readString(resultSet, 'createdAt', now),
      updatedAt: this.readString(resultSet, 'updatedAt', now)
    };
  }

  private rowToFolder(resultSet: relationalStore.ResultSet): IdeaFolder {
    const now = new Date().toISOString();
    return {
      id: this.readString(resultSet, 'id', this.createId()),
      name: this.readString(resultSet, 'name', '未命名文件夹'),
      color: this.readString(resultSet, 'color', '#136F63'),
      createdAt: this.readString(resultSet, 'createdAt', now),
      updatedAt: this.readString(resultSet, 'updatedAt', now)
    };
  }

  private rowToTag(resultSet: relationalStore.ResultSet): IdeaTag {
    const now = new Date().toISOString();
    return {
      id: this.readString(resultSet, 'id', this.createId()),
      name: this.readString(resultSet, 'name', '未命名标签'),
      color: this.readString(resultSet, 'color', '#0B4F47'),
      createdAt: this.readString(resultSet, 'createdAt', now),
      updatedAt: this.readString(resultSet, 'updatedAt', now)
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

  private captureDraftToBucket(record: CaptureDraftRecord): ValuesBucket {
    return {
      id: record.id,
      payload: record.payload,
      savedAt: record.savedAt
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

  private cleanupManagedIdeaAssetFiles(asset?: IdeaAsset, keepPaths: string[] = []): void {
    if (!asset) {
      return;
    }
    const keepSet = new Set(keepPaths.filter((path: string) => path.length > 0));
    const storedPath = asset.localUri;
    if (storedPath && this.isManagedAttachmentPath(storedPath) && !keepSet.has(storedPath)) {
      this.removeFileIfExists(storedPath);
    }
    const previewPath = asset.previewPath;
    if (previewPath && previewPath !== storedPath && this.isManagedAttachmentPath(previewPath) && !keepSet.has(previewPath)) {
      this.removeFileIfExists(previewPath);
    }
  }

  private collectManagedAssetPaths(ideas: Idea[]): string[] {
    const paths: string[] = [];
    for (const idea of ideas) {
      const asset = idea.asset;
      if (!asset) {
        continue;
      }
      if (asset.localUri && this.isManagedAttachmentPath(asset.localUri) && !paths.includes(asset.localUri)) {
        paths.push(asset.localUri);
      }
      if (asset.previewPath && this.isManagedAttachmentPath(asset.previewPath) && !paths.includes(asset.previewPath)) {
        paths.push(asset.previewPath);
      }
    }
    return paths;
  }

  private cleanupManagedPath(path: string | undefined): void {
    if (!path || !this.isManagedAttachmentPath(path)) {
      return;
    }
    this.removeFileIfExists(path);
  }

  private parseCaptureDraft(value: string): CaptureDraftState | undefined {
    if (!value) {
      return undefined;
    }
    try {
      const parsed = JSON.parse(value) as CaptureDraftState;
      if (!parsed.handwritingPreviewPath) {
        parsed.handwritingPreviewPath = undefined;
      }
      return parsed;
    } catch {
      return undefined;
    }
  }

  private loadLegacyCaptureDraft(): CaptureDraftState | undefined {
    const context = this.ensureContext();
    const path = `${context.filesDir}/${CAPTURE_DRAFT_KEY}`;
    if (!this.fileExists(path)) {
      return undefined;
    }
    try {
      return JSON.parse(fileIo.readTextSync(path)) as CaptureDraftState;
    } catch {
      return undefined;
    }
  }

  private clearLegacyCaptureDraft(): void {
    const context = this.ensureContext();
    const path = `${context.filesDir}/${CAPTURE_DRAFT_KEY}`;
    this.removeFileIfExists(path);
  }

  private readNullableString(resultSet: relationalStore.ResultSet, columnName: string): string {
    return this.readString(resultSet, columnName);
  }

  private readString(resultSet: relationalStore.ResultSet, columnName: string, fallback: string = ''): string {
    try {
      const idx = resultSet.getColumnIndex(columnName);
      if (idx < 0) {
        return fallback;
      }
      const value = resultSet.getString(idx);
      return value ?? fallback;
    } catch {
      return fallback;
    }
  }

  private readLong(resultSet: relationalStore.ResultSet, columnName: string, fallback: number = 0): number {
    try {
      const idx = resultSet.getColumnIndex(columnName);
      if (idx < 0) {
        return fallback;
      }
      return resultSet.getLong(idx);
    } catch {
      return fallback;
    }
  }

  private readIdeaType(resultSet: relationalStore.ResultSet): IdeaType {
    const value = this.readString(resultSet, 'type', IdeaType.DOCUMENT);
    if (value === IdeaType.AUDIO || value === IdeaType.HANDWRITING || value === IdeaType.DOCUMENT) {
      return value as IdeaType;
    }
    return IdeaType.DOCUMENT;
  }

  private parseTagsJson(value: string): string[] {
    try {
      const parsed = JSON.parse(value) as string[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.filter((tag: string) => typeof tag === 'string');
    } catch {
      return [];
    }
  }

  private async getFolderById(id: string): Promise<IdeaFolder | undefined> {
    const resultSet = await this.queryRowsGuarded(this.predicatesFor(FOLDERS_TABLE, id), '读取文件夹详情失败');
    try {
      const items = this.readFolders(resultSet);
      return items.length > 0 ? items[0] : undefined;
    } finally {
      this.closeResultSet(resultSet);
    }
  }

  private async getTagById(id: string): Promise<IdeaTag | undefined> {
    const resultSet = await this.queryRowsGuarded(this.predicatesFor(TAGS_TABLE, id), '读取标签详情失败');
    try {
      const items = this.readTags(resultSet);
      return items.length > 0 ? items[0] : undefined;
    } finally {
      this.closeResultSet(resultSet);
    }
  }

  private predicatesFor(table: string, id: string): relationalStore.RdbPredicates {
    return new relationalStore.RdbPredicates(table).equalTo('id', id);
  }

  private closeResultSet(resultSet: relationalStore.ResultSet): void {
    try {
      resultSet.close();
    } catch {
      // Ignore close failures after query results have been consumed.
    }
  }

  private goToFirstRow(resultSet: relationalStore.ResultSet): boolean {
    try {
      return resultSet.goToFirstRow();
    } catch {
      return false;
    }
  }

  private goToNextRow(resultSet: relationalStore.ResultSet): boolean {
    try {
      return resultSet.goToNextRow();
    } catch {
      return false;
    }
  }

  private readTextFileGuarded(path: string, message: string): string {
    try {
      return fileIo.readTextSync(path);
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private async decompressArchiveGuarded(zipPath: string, extractDir: string): Promise<void> {
    try {
      await zlib.decompressFile(zipPath, extractDir);
    } catch (err) {
      throw new Error(`解压备份失败：${String(err)}`);
    }
  }

  private async compressDirectoryGuarded(payloadDir: string, archivePath: string): Promise<void> {
    try {
      await zlib.compressFile(payloadDir, archivePath, {
        level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION
      });
    } catch (err) {
      throw new Error(`压缩备份失败：${String(err)}`);
    }
  }

  private async executeSqlGuarded(sql: string, message: string): Promise<void> {
    try {
      await this.ensureStore().executeSql(sql);
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private async deleteTableRowsGuarded(table: string, message: string): Promise<void> {
    try {
      await this.ensureStore().delete(new relationalStore.RdbPredicates(table));
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private async deleteRowsGuarded(predicates: relationalStore.RdbPredicates, message: string): Promise<void> {
    try {
      await this.ensureStore().delete(predicates);
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private async insertRowGuarded(table: string, bucket: ValuesBucket, message: string): Promise<void> {
    try {
      await this.ensureStore().insert(table, bucket);
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private async updateRowsGuarded(bucket: ValuesBucket, predicates: relationalStore.RdbPredicates, message: string): Promise<void> {
    try {
      await this.ensureStore().update(bucket, predicates);
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private async queryRowsGuarded(predicates: relationalStore.RdbPredicates, message: string): Promise<relationalStore.ResultSet> {
    try {
      return await this.ensureStore().query(predicates);
    } catch (err) {
      throw new Error(`${message}：${String(err)}`);
    }
  }

  private ensureStore(): RdbStore {
    if (!this.store) {
      throw new Error('想法仓库尚未初始化');
    }
    return this.store;
  }

  private ensureContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('想法仓库尚未初始化');
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
      if (!asset) {
        continue;
      }
      this.collectBackupAttachment(entries, idea.id, asset.type || 'asset', 'localUri', asset.localUri, attachmentsDir);
      if (asset.previewPath && asset.previewPath !== asset.localUri) {
        this.collectBackupAttachment(entries, idea.id, asset.type || 'asset', 'previewPath', asset.previewPath, attachmentsDir);
      }
    }
    return entries;
  }

  private collectBackupAttachment(entries: IdeaBackupAttachment[], ideaId: string, kind: string, role: string, path: string, attachmentsDir: string): void {
    if (!path) {
      return;
    }
    const sourcePath = this.resolveFilePath(path);
    if (!this.fileExists(sourcePath)) {
      return;
    }
    const fileName = `${ideaId}-${this.safeName(role)}-${this.safeName(kind || 'asset')}${this.extensionFromPath(sourcePath)}`;
    const relativePath = `attachments/${fileName}`;
    const destPath = `${attachmentsDir}/${fileName}`;
    try {
      fileIo.copyFileSync(sourcePath, destPath);
      entries.push({
        ideaId,
        kind,
        role,
        sourcePath,
        relativePath
      });
    } catch {
      // Skip attachments that cannot be copied into the backup payload.
    }
  }

  private readBackupManifest(extractDir: string): string {
    const rootManifest = `${extractDir}/manifest.json`;
    if (this.fileExists(rootManifest)) {
      return this.readTextFileGuarded(rootManifest, '读取备份清单失败');
    }
    const nestedManifest = `${extractDir}/payload/manifest.json`;
    if (this.fileExists(nestedManifest)) {
      return this.readTextFileGuarded(nestedManifest, '读取备份清单失败');
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
    if (!this.fileExists(resolved)) {
      return;
    }
    try {
      fileIo.unlinkSync(resolved);
    } catch {
      // Ignore best-effort cleanup failures for managed files.
    }
  }

  private writeTextFile(path: string, text: string): void {
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      try {
        fileIo.writeSync(file.fd, text, { encoding: 'utf-8' });
      } finally {
        try {
          fileIo.closeSync(file);
        } catch {
          // Ignore close failures after the write attempt has completed.
        }
      }
    } catch (err) {
      throw new Error(`写入文本文件失败：${String(err)}`);
    }
  }

  private ensureDirectory(path: string): void {
    try {
      if (!this.fileExists(path)) {
        fileIo.mkdirSync(path);
      }
    } catch {
      // Directory creation is retried by the file operation that needs it.
    }
  }

  private fileExists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch {
      return false;
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
