import { IdeaFolder } from '../model/IdeaModels';
import { ideaRepository } from '../repository/IdeaRepository';

class FolderSelectOption {
  value: string = '';
  constructor(value: string) {
    this.value = value;
  }
}

@Component
export struct FolderManagerComponent {
  @Link folders: IdeaFolder[];
  @Link folderNameInput: string;
  @Link folderParentInput: string;
  @Link editingFolderId: string;
  @Link folderId: string;
  onReload: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.folder_manager'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: $r('app.string.folder_name_placeholder'), text: this.folderNameInput })
          .onChange((value: string) => this.folderNameInput = value)
          .layoutWeight(1)
          .fontSize(14)
        if (this.rootFoldersForParentPicker().length > 0) {
          Select(this.rootFoldersForParentPicker().map((folder: IdeaFolder): FolderSelectOption => {
            return new FolderSelectOption(folder.name);
          }))
            .selected(this.folderParentInput.length === 0 ? -1 : this.rootFoldersForParentPicker().findIndex((f: IdeaFolder) => f.id === this.folderParentInput))
            .value(this.folderParentInput.length > 0 ? this.folderNameForSearch(this.folderParentInput) : $r('app.string.root_level'))
            .font({ size: 12 })
            .onSelect((index: number) => {
              const folder = this.rootFoldersForParentPicker()[index];
              this.folderParentInput = folder?.id ?? '';
            })
        }
        Button(this.editingFolderId.length > 0 ? $r('app.string.save_folder') : $r('app.string.new_folder'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(18)
          .onClick(async () => {
            await this.saveFolderFromInput();
            await this.reloadFolders();
            this.onReload();
          })
      }
      .width('100%')

      if (this.folders.length > 0) {
        List({ space: 8 }) {
          ForEach(this.displayFolders(), (folder: IdeaFolder) => {
            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(this.folderDisplayName(folder))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(folder.parentId ? '\u{1F4C2} 子文件夹' : '\u{1F4C1} 根文件夹')
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Row({ space: 4 }) {
                  Button($r('app.string.edit'))
                    .fontSize(12)
                    .height(28)
                    .padding({ left: 10, right: 10 })
                    .backgroundColor($r('app.color.surface_secondary'))
                    .fontColor($r('app.color.text_secondary'))
                    .borderRadius(14)
                    .onClick(() => {
                      this.editingFolderId = folder.id;
                      this.folderNameInput = folder.name;
                      this.folderParentInput = folder.parentId || '';
                    })
                  Button($r('app.string.delete'))
                    .fontSize(12)
                    .height(28)
                    .padding({ left: 10, right: 10 })
                    .backgroundColor($r('app.color.danger_bg'))
                    .fontColor($r('app.color.danger'))
                    .borderRadius(14)
                    .onClick(async () => {
                      await ideaRepository.deleteFolder(folder.id);
                      if (this.editingFolderId === folder.id) {
                        this.editingFolderId = '';
                        this.folderNameInput = '';
                        this.folderParentInput = '';
                      }
                      if (this.folderId === folder.id) {
                        this.folderId = '';
                      }
                      await this.reloadFolders();
                      this.onReload();
                    })
                }
              }
              .width('100%')
            }
          }, (folder: IdeaFolder) => folder.id)
        }
        .width('100%')
        .constraintSize({ maxHeight: 200 })
      } else {
        Text('\u{1F4C1} 暂无文件夹，先创建一个。')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
  }

  private async saveFolderFromInput(): Promise<void> {
    const name = this.folderNameInput.trim();
    if (name.length === 0) {
      return;
    }
    if (this.editingFolderId.length > 0) {
      await ideaRepository.updateFolder(this.editingFolderId, { name, parentId: this.folderParentInput || undefined, updateParent: true });
      this.editingFolderId = '';
    } else {
      await ideaRepository.createFolder(name, '#136F63', this.folderParentInput || undefined);
    }
    this.folderNameInput = '';
    this.folderParentInput = '';
  }

  private async reloadFolders(): Promise<void> {
    this.folders = await ideaRepository.listFolders();
  }

  private displayFolders(): IdeaFolder[] {
    const result: IdeaFolder[] = [];
    const roots = this.folders.filter((folder: IdeaFolder) => !folder.parentId);
    for (const root of roots) {
      result.push(root);
      for (const child of this.folders.filter((folder: IdeaFolder) => folder.parentId === root.id)) {
        result.push(child);
      }
    }
    for (const folder of this.folders) {
      if (!result.some((item: IdeaFolder) => item.id === folder.id)) {
        result.push(folder);
      }
    }
    return result;
  }

  private rootFoldersForParentPicker(): IdeaFolder[] {
    return this.folders.filter((folder: IdeaFolder) => !folder.parentId && folder.id !== this.editingFolderId);
  }

  private folderDisplayName(folder: IdeaFolder): string {
    if (!folder.parentId) {
      return folder.name;
    }
    const parent = this.folders.find((item: IdeaFolder) => item.id === folder.parentId);
    return parent ? `${parent.name} / ${folder.name}` : folder.name;
  }

  private folderNameForSearch(folderId: string): string {
    if (!folderId) return '';
    const folder = this.folders.find((item: IdeaFolder) => item.id === folderId);
    return folder ? folder.name : '';
  }
}
