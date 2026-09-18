import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { GradeMath } from '../model/GradeMath';
import { GradeRecord } from '../model/GradeRecord';
import { NetworkFeeMath } from '../model/NetworkFee';
import { Store } from '../services/Store';
import { Notifier } from '../services/Notifier';
import { CampusData } from '../services/CampusData';
import { Config, Theme } from '../common/Config';
import { SyncPageParams } from '../common/RouteParams';

@Entry
@Component
struct Index {
  @State gpaText: string = '--';
  @State weightedText: string = '--';
  @State courseCount: number = 0;
  @State electricityText: string = '--';
  @State networkBalanceText: string = '--';
  @State networkPackageText: string = '未设置';
  @State networkRemindText: string = '--';
  @State hasCredentials: boolean = false;
  @State verified: boolean = false;
  @State alertEnabled: boolean = true;
  @State thresholdInput: string = '20';

  aboutToAppear(): void {
    this.refresh();
  }

  onPageShow(): void {
    this.refresh();
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('翱翔助手')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
          Text(this.accountSubtitle())
            .fontSize(11)
            .fontColor(Theme.muted)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      Scroll() {
        Column() {
          Row() {
            MetricItem({ metricValue: this.gpaText, metricLabel: 'GPA（绩点）' })
            MetricItem({ metricValue: this.weightedText, metricLabel: '加权成绩（分）' })
            MetricItem({ metricValue: `${this.courseCount}`, metricLabel: '课程（门）' })
            MetricItem({ metricValue: this.electricityText, metricLabel: '剩余电费（度）' })
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .backgroundColor(Theme.surface)
          .borderRadius(16)

          Row() {
            Button('更新成绩')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(12)
              .onClick(() => {
                this.openSync('grades');
              })
            Button('更新电费')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.primary)
              .backgroundColor(Theme.primaryLight)
              .borderRadius(12)
              .margin({ left: 10 })
              .onClick(() => {
                this.openSync('electricity');
              })
          }
          .width('100%')
          .margin({ top: 14 })

          Column() {
            Row() {
              Text('成绩明细')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .layoutWeight(1)
              Text('查看 ›')
                .fontSize(12)
                .fontColor(Theme.primary)
                .onClick(() => {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/grade' });
                })
            }
            .width('100%')
            Text(this.courseCount > 0 ? `已收录 ${this.courseCount} 门课程，含 GPA 与成绩构成` : '登录后同步成绩数据')
              .fontSize(11)
              .fontColor(Theme.muted)
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/grade' });
          })

          Column() {
            Text('电费提醒')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Row() {
              Text('余额不足提醒')
                .fontSize(13)
                .fontColor(Theme.ink)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.alertEnabled })
                .onChange((isOn: boolean) => {
                  this.handleAlertToggle(isOn);
                })
            }
            .width('100%')
            .margin({ top: 10 })
            if (this.alertEnabled) {
              Row() {
                Text('提醒余量（度）')
                  .fontSize(13)
                  .fontColor(Theme.muted)
                  .layoutWeight(1)
                TextInput({ placeholder: '20', text: this.thresholdInput })
                  .type(InputType.Number)
                  .width(90)
                  .height(38)
                  .fontSize(14)
                  .fontColor(Theme.ink)
                  .backgroundColor(Theme.background)
                  .borderRadius(8)
                  .textAlign(TextAlign.Center)
                  .onChange((value: string) => {
                    this.thresholdInput = value;
                  })
                Button('保存余量')
                  .height(38)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .backgroundColor(Theme.primary)
                  .borderRadius(8)
                  .padding({ left: 12, right: 12 })
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.saveThreshold();
                  })
              }
              .width('100%')
              .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })

          Column() {
            Row() {
              Text('网费与日历提醒')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .layoutWeight(1)
              Text('详情 ›')
                .fontSize(12)
                .fontColor(Theme.primary)
                .onClick(() => {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/network' });
                })
            }
            .width('100%')
            Row() {
              Text('当前套餐')
                .fontSize(13)
                .fontColor(Theme.muted)
                .layoutWeight(1)
              Text(this.networkPackageText)
                .fontSize(13)
                .fontColor(Theme.ink)
            }
            .width('100%')
            .margin({ top: 10 })
            Row() {
              Text('账户余额')
                .fontSize(13)
                .fontColor(Theme.muted)
                .layoutWeight(1)
              Text(`${this.networkBalanceText} 元`)
                .fontSize(13)
                .fontColor(Theme.ink)
            }
            .width('100%')
            .margin({ top: 8 })
            Row() {
              Text('提醒日期')
                .fontSize(13)
                .fontColor(Theme.muted)
                .layoutWeight(1)
              Text(this.networkRemindText)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.primary)
            }
            .width('100%')
            .margin({ top: 8 })
            Button('更新网费')
              .width('100%')
              .height(40)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.primary)
              .backgroundColor(Theme.primaryLight)
              .borderRadius(10)
              .margin({ top: 12 })
              .onClick(() => {
                this.openSync('network');
              })
            Text('登录网络自助系统后可读取套餐与余额，并在日历中创建到期提醒')
              .fontSize(11)
              .fontColor(Theme.muted)
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })

          Column() {
            Row() {
              Text('账号')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .layoutWeight(1)
              Text(this.verified ? '已验证' : this.hasCredentials ? '待验证' : '未登录')
                .fontSize(12)
                .fontColor(this.verified ? Theme.green : Theme.muted)
            }
            .width('100%')
            Button(this.hasCredentials ? '重新登录' : '登录翱翔门户')
              .width('100%')
              .height(40)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.primary)
              .backgroundColor(Theme.primaryLight)
              .borderRadius(10)
              .margin({ top: 12 })
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/login' });
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })
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
    const records: Array<GradeRecord> = Store.loadGrades();
    this.courseCount = records.length;
    const gpa: number = Store.getPortraitGpa();
    this.gpaText = Number.isNaN(gpa) ? '--' : gpa.toFixed(3);
    const credits: Array<number> = [];
    const values: Array<number> = [];
    records.forEach((record: GradeRecord) => {
      credits.push(record.credits);
      values.push(record.score === undefined ? Number.NaN : record.score);
    });
    const weighted: number = GradeMath.weightedAverage(credits, values);
    this.weightedText = Number.isNaN(weighted) ? '--' : weighted.toFixed(2);
    const balance: number = Store.getElectricityBalance();
    this.electricityText = Number.isNaN(balance) ? '--' : balance.toFixed(2);
    this.refreshNetwork();
    this.hasCredentials = Store.hasSavedCredentials();
    this.verified = Store.getBool(Config.KEY_CREDENTIALS_VERIFIED, false);
    this.alertEnabled = Store.getBool(Config.KEY_ELECTRICITY_ALERT_ENABLED, true);
    this.thresholdInput = `${Store.getNumber(Config.KEY_ELECTRICITY_ALERT_THRESHOLD, 20)}`;
  }

  private refreshNetwork(): void {
    const balance: number = Store.getNetworkBalance();
    this.networkBalanceText = Number.isFinite(balance) ? balance.toFixed(2) : '--';
    const price: number = Store.getNetworkPackagePrice();
    const name: string = Store.getNetworkPackageName();
    if (Number.isFinite(price) && price > 0) {
      this.networkPackageText = name.length > 0 ? name : `${price}元套餐`;
    } else {
      this.networkPackageText = '未设置';
    }
    if (Number.isFinite(balance) && Number.isFinite(price) && price > 0) {
      const covered: number = NetworkFeeMath.monthsCovered(balance, price);
      if (covered === 0) {
        this.networkRemindText = '余额不足，请充值';
      } else {
        const remind: number = NetworkFeeMath.reminderTime(balance, price,
          Store.getNetworkLeadDays(), new Date());
        this.networkRemindText = NetworkFeeMath.formatDate(remind);
      }
    } else {
      this.networkRemindText = '--';
    }
  }

  private openSync(target: string): void {
    if (target !== 'network' && !this.hasCredentials) {
      this.showToast('请先登录翱翔门户');
      this.getUIContext().getRouter().pushUrl({ url: 'pages/login' });
      return;
    }
    const params: SyncPageParams = { target: target, chain: false };
    this.getUIContext().getRouter().pushUrl({ url: 'pages/sync', params: params });
  }

  private handleAlertToggle(isOn: boolean): void {
    this.alertEnabled = isOn;
    Store.put(Config.KEY_ELECTRICITY_ALERT_ENABLED, isOn);
    Store.put(Config.KEY_ELECTRICITY_ALERT_ACTIVE, false);
    if (isOn) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      Notifier.requestPermission(context).then((ok: boolean) => {
        if (!ok) {
          this.showToast('未开启通知权限，将无法收到电费提醒');
        }
      }).catch((_error: Object) => {
      });
    }
  }

  private saveThreshold(): void {
    const parsed: number = Number.parseFloat(this.thresholdInput.trim());
    if (!Number.isFinite(parsed) || parsed < 0) {
      this.showToast('请输入有效报警余量');
      return;
    }
    Store.put(Config.KEY_ELECTRICITY_ALERT_THRESHOLD, `${parsed}`);
    Store.put(Config.KEY_ELECTRICITY_ALERT_ACTIVE, false);
    this.thresholdInput = `${parsed}`;
    this.showToast('报警余量已保存');
    const balance: number = Store.getElectricityBalance();
    if (!Number.isNaN(balance)) {
      CampusData.updateElectricityAlert(balance);
    }
  }

  private accountSubtitle(): string {
    if (!this.hasCredentials) {
      return '未登录';
    }
    return this.verified ? '账号已验证' : '账号待验证';
  }

  private showToast(message: string): void {
    const options: promptAction.ShowToastOptions = { message: message };
    this.getUIContext().getPromptAction().showToast(options);
  }
}

@Component
struct MetricItem {
  @Prop metricValue: string = '--';
  @Prop metricLabel: string = '';

  build() {
    Column() {
      Text(this.metricValue)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.metricValue === '--' ? Theme.muted : Theme.ink)
        .maxLines(1)
      Text(this.metricLabel)
        .fontSize(10)
        .fontColor(Theme.muted)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }
}
