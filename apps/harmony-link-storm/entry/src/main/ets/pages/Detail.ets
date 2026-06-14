import router from '@ohos.router';
import { Idea, ideaTypeLabel } from '../model/IdeaModels';
import { ideaRepository } from '../repository/IdeaRepository';

interface DetailParams {
  id?: string;
}

@Entry
@Component
struct Detail {
  @State private ideaId: string = '';
  @State private idea: Idea | undefined = undefined;
  @State private title: string = '';
  @State private tags: string = '';
  @State private note: string = '';
  @State private plainText: string = '';
  @State private sourceTitle: string = '';
  @State private sourceUrl: string = '';
  @State private status: string = '';

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as DetailParams;
    this.ideaId = params.id ?? '';
    await this.reload();
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('想法详情')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text(this.idea ? ideaTypeLabel(this.idea.type) : '加载中')
            .fontSize(12)
            .fontColor('#667085')
        }
        Blank()
        Button('返回')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .onClick(() => router.back())
      }
      .width('100%')

      if (this.idea) {
        TextInput({ text: this.title, placeholder: '标题' })
          .onChange((value: string) => this.title = value)
        TextInput({ text: this.tags, placeholder: '标签，逗号分隔' })
          .onChange((value: string) => this.tags = value)
        TextInput({ text: this.sourceTitle, placeholder: '来源标题' })
          .onChange((value: string) => this.sourceTitle = value)
        TextInput({ text: this.sourceUrl, placeholder: '来源链接' })
          .onChange((value: string) => this.sourceUrl = value)
        TextArea({ text: this.plainText, placeholder: '正文' })
          .height(160)
          .onChange((value: string) => this.plainText = value)
        TextArea({ text: this.note, placeholder: '备注' })
          .height(120)
          .onChange((value: string) => this.note = value)

        Row({ space: 10 }) {
          Button(this.idea.isFavorite ? '取消收藏' : '收藏')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              const current = this.idea;
              if (!current) {
                return;
              }
              await ideaRepository.update(this.ideaId, { isFavorite: !current.isFavorite });
              await this.reload();
            })
          Button(this.idea.isArchived ? '取消归档' : '归档')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .onClick(async () => {
              const current = this.idea;
              if (!current) {
                return;
              }
              await ideaRepository.update(this.ideaId, { isArchived: !current.isArchived });
              await this.reload();
            })
          Button('保存')
            .backgroundColor('#136F63')
            .fontColor(Color.White)
            .onClick(async () => {
              await ideaRepository.update(this.ideaId, {
                title: this.title,
                plainText: this.plainText,
                note: this.note,
                tags: this.parseTags(),
                context: {
                  title: this.sourceTitle,
                  url: this.sourceUrl,
                  manualNote: this.note,
                  capturedAt: this.idea ? this.idea.context.capturedAt : new Date().toISOString()
                }
              });
              this.status = '已保存';
              await this.reload();
            })
          Button('删除')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontColor('#B42318')
            .onClick(async () => {
              await ideaRepository.delete(this.ideaId);
              router.back();
            })
        }

        Text(this.status)
          .fontColor('#667085')
          .fontSize(12)
      } else {
        Text(this.status || '未找到记录')
      }
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  private async reload(): Promise<void> {
    if (!this.ideaId) {
      this.status = '缺少想法 ID';
      return;
    }
    const loaded = await ideaRepository.getById(this.ideaId);
    if (!loaded) {
      this.status = '记录不存在';
      this.idea = undefined;
      return;
    }
    this.idea = loaded;
    this.title = loaded.title;
    this.tags = loaded.tags.join(', ');
    this.note = loaded.note;
    this.plainText = loaded.plainText;
    this.sourceTitle = loaded.context.title;
    this.sourceUrl = loaded.context.url;
    this.status = '';
  }

  private parseTags(): string[] {
    return this.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
  }
}
