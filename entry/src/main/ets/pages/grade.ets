import { GradeRecord } from '../model/GradeRecord';
import { GradeMath } from '../model/GradeMath';
import { Store } from '../services/Store';
import { Theme } from '../common/Config';
import { SyncPageParams } from '../common/RouteParams';

@Entry
@Component
struct GradePage {
  @State records: Array<GradeRecord> = [];
  @State gpaText: string = '--';
  @State weightedText: string = '--';

  aboutToAppear(): void {
    this.refresh();
  }

  onPageShow(): void {
    this.refresh();
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor(Theme.ink)
          .width(40)
          .height(52)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
        Column() {
          Text('成绩')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
          Text(`共 ${this.records.length} 门课程`)
            .fontSize(11)
            .fontColor(Theme.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('更新')
          .height(34)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(Theme.primary)
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            const params: SyncPageParams = { target: 'grades', chain: false };
            this.getUIContext().getRouter().pushUrl({ url: 'pages/sync', params: params });
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 14 })

      Scroll() {
        Column() {
          Row() {
            Column() {
              Text(this.gpaText)
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.primary)
              Text('总 GPA')
                .fontSize(11)
                .fontColor(Theme.muted)
                .margin({ top: 2 })
              Text('学生画像数据')
                .fontSize(9)
                .fontColor(Theme.muted)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Center)
            .layoutWeight(1)

            Column() {
              Text(this.weightedText)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
              Text('加权成绩（分）')
                .fontSize(11)
                .fontColor(Theme.muted)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Center)
            .layoutWeight(1)

            Column() {
              Text(`${this.records.length}`)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
              Text('课程（门）')
                .fontSize(11)
                .fontColor(Theme.muted)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Center)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 18, bottom: 18 })
          .backgroundColor(Theme.surface)
          .borderRadius(16)

          if (this.records.length === 0) {
            Column() {
              Text('暂无成绩数据')
                .fontSize(14)
                .fontColor(Theme.muted)
              Text('请先登录并完成一次同步')
                .fontSize(12)
                .fontColor(Theme.muted)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding({ top: 40, bottom: 40 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column() {
              Text('成绩明细')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .margin({ bottom: 10 })
              ForEach(this.records, (record: GradeRecord) => {
                Row() {
                  Column() {
                    Text(record.course)
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.ink)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${record.category} · ${record.credits} 学分`)
                      .fontSize(11)
                      .fontColor(Theme.muted)
                      .margin({ top: 4 })
                    if (record.detail.length > 0) {
                      Text(record.detail)
                        .fontSize(10)
                        .fontColor(Theme.muted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 2 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column() {
                    Text('绩点')
                      .fontSize(9)
                      .fontColor(Theme.primary)
                    Text(record.pointText())
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.primary)
                    Text(`分数 ${record.scoreText()}`)
                      .fontSize(9)
                      .fontColor(Theme.muted)
                  }
                  .alignItems(HorizontalAlign.Center)
                  .justifyContent(FlexAlign.Center)
                  .width(82)
                  .padding({ top: 8, bottom: 8 })
                  .backgroundColor(Theme.primaryLight)
                  .borderRadius(12)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ top: 10, bottom: 10 })
              }, (record: GradeRecord) => record.diffKey() + '|' + record.diffSignature())
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(16)
            .backgroundColor(Theme.surface)
            .borderRadius(16)
            .margin({ top: 14 })
          }
        }
        .padding({ left: 16, right: 16, bottom: 30 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background)
  }

  private refresh(): void {
    this.records = Store.loadGrades();
    const gpa: number = Store.getPortraitGpa();
    this.gpaText = Number.isNaN(gpa) ? '--' : gpa.toFixed(3);
    const credits: Array<number> = [];
    const values: Array<number> = [];
    this.records.forEach((record: GradeRecord) => {
      credits.push(record.credits);
      values.push(record.score === undefined ? Number.NaN : record.score);
    });
    const weighted: number = GradeMath.weightedAverage(credits, values);
    this.weightedText = Number.isNaN(weighted) ? '--' : weighted.toFixed(2);
  }
}
