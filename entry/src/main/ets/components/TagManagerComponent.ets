import { LengthMetrics } from '@kit.ArkUI';
import { IdeaTag } from '../model/IdeaModels';
import { ideaRepository } from '../repository/IdeaRepository';

@Component
export struct TagManagerComponent {
  @Link tagsCatalog: IdeaTag[];
  @Link tagNameInput: string;
  @Link editingTagId: string;
  @Link tagFilter: string;
  onReload: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.tag_manager'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: $r('app.string.tag_name_placeholder'), text: this.tagNameInput })
          .onChange((value: string) => this.tagNameInput = value)
          .layoutWeight(1)
          .fontSize(14)
        Button(this.editingTagId.length > 0 ? $r('app.string.save_tag') : $r('app.string.new_tag'))
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor(Color.White)
          .borderRadius(18)
          .onClick(async () => {
            await this.saveTagFromInput();
            await this.reloadTags();
            this.onReload();
          })
      }
      .width('100%')

      if (this.tagsCatalog.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.tagsCatalog, (tag: IdeaTag) => {
            Row({ space: 4 }) {
              Text(tag.name)
                .fontSize(13)
                .fontColor(this.tagFilter === tag.name ? Color.White : $r('app.color.text_primary'))
                .backgroundColor(this.tagFilter === tag.name ? tag.color : $r('app.color.chip_bg_unselected'))
                .borderRadius(14)
                .padding({ left: 12, right: 8, top: 6, bottom: 6 })
                .onClick(() => this.tagFilter = tag.name)
              Text('\u270E')
                .fontSize(14)
                .fontColor($r('app.color.icon_secondary'))
                .padding(4)
                .onClick(() => {
                  this.editingTagId = tag.id;
                  this.tagNameInput = tag.name;
                })
              Text('\u2716')
                .fontSize(12)
                .fontColor($r('app.color.danger'))
                .padding(4)
                .onClick(async () => {
                  await ideaRepository.deleteTag(tag.id);
                  if (this.tagFilter === tag.name) {
                    this.tagFilter = '';
                  }
                  if (this.editingTagId === tag.id) {
                    this.editingTagId = '';
                    this.tagNameInput = '';
                  }
                  await this.reloadTags();
                  this.onReload();
                })
            }
          }, (tag: IdeaTag) => tag.id)
        }
        .width('100%')
      } else {
        Text('\u{1F3F7} 暂无标签，先创建一个。')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
    }
    .padding(16)
    .width('100%')
    .backgroundColor($r('app.color.surface_primary'))
    .borderRadius(12)
  }

  private async saveTagFromInput(): Promise<void> {
    const name = this.tagNameInput.trim();
    if (name.length === 0) {
      return;
    }
    if (this.editingTagId.length > 0) {
      await ideaRepository.updateTag(this.editingTagId, { name });
      this.editingTagId = '';
    } else {
      await ideaRepository.createTag(name);
    }
    this.tagNameInput = '';
  }

  private async reloadTags(): Promise<void> {
    this.tagsCatalog = await ideaRepository.listTags();
  }
}
