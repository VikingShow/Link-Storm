import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import picker from '@ohos.file.picker';
import { Idea, IdeaDraft, IdeaExportPayload, IdeaType, ImportConflictStrategy, ImportResult } from '../model/IdeaModels';

const STORE_NAME = 'link_storm_ideas';
const IDEAS_KEY = 'ideas_json';
const EXPORT_SCHEMA = 'link-storm-local-capture-export';
const EXPORT_FILE_SUFFIX = '.json';

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

  async delete(id: string): Promise<void> {
    const ideas = await this.list();
    await this.persist(ideas.filter((idea: Idea) => idea.id !== id));
  }

  async getById(id: string): Promise<Idea | undefined> {
    const ideas = await this.list();
    return ideas.find((idea: Idea) => idea.id === id);
  }

  async exportJson(): Promise<string> {
    return JSON.stringify({
      schema: EXPORT_SCHEMA,
      version: 1,
      exportedAt: new Date().toISOString(),
      ideas: await this.list()
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
    return {
      inserted: merged.inserted,
      updated: merged.updated,
      skipped: merged.skipped,
      conflicts: merged.conflicts
    };
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

  private async persist(ideas: Idea[]): Promise<void> {
    await this.ensureStore().put(IDEAS_KEY, JSON.stringify(ideas));
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

  private timestampStamp(): string {
    const now = new Date();
    const pad = (value: number): string => `${value}`.padStart(2, '0');
    return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  }
}

export const ideaRepository = new IdeaRepository();
