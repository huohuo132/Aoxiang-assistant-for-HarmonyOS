import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { Config, Theme } from '../common/Config';
import { SyncPageParams } from '../common/RouteParams';
import { NetworkFeeMath, NetworkPackage } from '../model/NetworkFee';
import { CampusData } from '../services/CampusData';
import { CalendarService, NetworkCalendarEvent } from '../services/CalendarService';
import { Store } from '../services/Store';

@Entry
@Component
struct NetworkPage {
  @State balanceText: string = '--';
  @State inputBalance: string = '';
  @State packageName: string = '';
  @State packagePrice: number = 0;
  @State leadDaysText: string = '5';
  @State coveredText: string = '--';
  @State expiryText: string = '--';
  @State remindText: string = '--';
  @State updatedText: string = '尚未更新';
  @State working: boolean = false;
  @State hasEvent: boolean = false;
  private packages: Array<NetworkPackage> = NetworkPackage.options();

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
          Text('网费与到期提醒')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
          Text('按套餐价格与余额推算到期时间')
            .fontSize(11)
            .fontColor(Theme.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })

      Scroll() {
        Column() {
          Column() {
            Row() {
              Text('账户余额')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .layoutWeight(1)
              Text(this.updatedText)
                .fontSize(11)
                .fontColor(Theme.muted)
            }
            .width('100%')
            Text(this.balanceText)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.primary)
              .margin({ top: 8 })
            Row() {
              TextInput({ placeholder: '手动输入余额（元）', text: this.inputBalance })
                .type(InputType.Number)
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .fontColor(Theme.ink)
                .backgroundColor(Theme.background)
                .borderRadius(10)
                .onChange((value: string) => {
                  this.inputBalance = value;
                })
              Button('保存余额')
                .height(42)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.primary)
                .backgroundColor(Theme.primaryLight)
                .borderRadius(10)
                .padding({ left: 14, right: 14 })
                .margin({ left: 8 })
                .onClick(() => {
                  this.saveBalance();
                })
            }
            .width('100%')
            .margin({ top: 12 })
            Button('更新网费')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(12)
              .margin({ top: 12 })
              .onClick(() => {
                this.openSync();
              })
            Text('更新需在打开的页面中手动完成登录（含验证码）')
              .fontSize(11)
              .fontColor(Theme.muted)
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)

          Column() {
            Text('当前套餐')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            ForEach(this.packages, (item: NetworkPackage) => {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(14)
                    .fontColor(Theme.ink)
                  Text(`校内流量 ${item.traffic}，按月结算`)
                    .fontSize(11)
                    .fontColor(Theme.muted)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.packagePrice === item.price ? '已选' : `${item.price} 元`)
                  .fontSize(13)
                  .fontWeight(this.packagePrice === item.price ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.packagePrice === item.price ? Theme.primary : Theme.muted)
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .borderRadius(10)
              .onClick(() => {
                this.selectPackage(item);
              })
            }, (item: NetworkPackage) => item.name)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })

          Column() {
            Text('到期提醒')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Row() {
              Text('提前提醒')
                .fontSize(13)
                .fontColor(Theme.muted)
                .layoutWeight(1)
              TextInput({ placeholder: '5', text: this.leadDaysText })
                .type(InputType.Number)
                .width(90)
                .height(38)
                .fontSize(14)
                .fontColor(Theme.ink)
                .backgroundColor(Theme.background)
                .borderRadius(8)
                .textAlign(TextAlign.Center)
                .onChange((value: string) => {
                  this.leadDaysText = value;
                })
              Text('天')
                .fontSize(13)
                .fontColor(Theme.muted)
                .margin({ left: 8 })
              Button('保存')
                .height(38)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.primary)
                .backgroundColor(Theme.primaryLight)
                .borderRadius(8)
                .padding({ left: 12, right: 12 })
                .margin({ left: 8 })
                .onClick(() => {
                  this.saveLeadDays();
                })
            }
            .width('100%')
            .margin({ top: 10 })
            Row() {
              Text('可覆盖月数')
                .fontSize(13)
                .fontColor(Theme.muted)
                .layoutWeight(1)
              Text(this.coveredText)
                .fontSize(13)
                .fontColor(Theme.ink)
            }
            .width('100%')
            .margin({ top: 12 })
            Row() {
              Text('预计到期')
                .fontSize(13)
                .fontColor(Theme.muted)
                .layoutWeight(1)
              Text(this.expiryText)
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
              Text(this.remindText)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.primary)
            }
            .width('100%')
            .margin({ top: 8 })
            Button(this.hasEvent ? '更新日历提醒' : '在日历中创建提醒')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(12)
              .margin({ top: 14 })
              .enabled(!this.working)
              .onClick(() => {
                this.createCalendarEvent();
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })

          Column() {
            Text('计费说明')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Text('校园网以自然月为一个计费周期，月底结算时扣除所选套餐费用；套餐内未用完流量次月不清零，超出套餐按 1 元 1GB 计费。余额可覆盖的完整月数决定到期时间，提醒日期即到期日往前推设定的天数。')
              .fontSize(12)
              .fontColor(Theme.muted)
              .margin({ top: 8 })
              .lineHeight(20)
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
    const balance: number = Store.getNetworkBalance();
    this.balanceText = Number.isFinite(balance) ? `${balance}` : '--';
    this.packagePrice = Store.getNetworkPackagePrice();
    this.packageName = Store.getNetworkPackageName();
    this.leadDaysText = `${Store.getNetworkLeadDays()}`;
    const updatedAt: number = Store.getNumber(Config.KEY_NETWORK_UPDATED_AT, Number.NaN);
    this.updatedText = Number.isFinite(updatedAt)
      ? `更新于 ${NetworkFeeMath.formatDate(updatedAt)}` : '尚未更新';
    this.hasEvent = Store.getNetworkCalendarEventId() > 0;
    this.recompute(balance);
  }

  private recompute(balance: number): void {
    const price: number = this.packagePrice;
    const leadDays: number = this.parseLeadDays();
    if (!Number.isFinite(balance) || !Number.isFinite(price) || price <= 0) {
      this.coveredText = '--';
      this.expiryText = '--';
      this.remindText = '--';
      return;
    }
    const now: Date = new Date();
    const covered: number = NetworkFeeMath.monthsCovered(balance, price);
    const expiry: number = NetworkFeeMath.expiryTime(balance, price, now);
    const remind: number = NetworkFeeMath.reminderTime(balance, price, leadDays, now);
    this.coveredText = covered === 0 ? '不足 1 个月' : `${covered} 个月`;
    this.expiryText = covered === 0 ? '余额不足，请立即充值' : NetworkFeeMath.formatDate(expiry);
    this.remindText = NetworkFeeMath.formatDate(remind);
  }

  private parseLeadDays(): number {
    const parsed: number = Number.parseFloat(this.leadDaysText.trim());
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : NetworkFeeMath.DEFAULT_LEAD_DAYS;
  }

  private selectPackage(item: NetworkPackage): void {
    this.packagePrice = item.price;
    this.packageName = item.name;
    CampusData.setNetworkPackage(item.price, item.name);
    const balance: number = Store.getNetworkBalance();
    this.recompute(balance);
    this.showToast(`已选择 ${item.name}`);
  }

  private saveBalance(): void {
    const parsed: number = Number.parseFloat(this.inputBalance.trim());
    if (!Number.isFinite(parsed) || parsed < 0) {
      this.showToast('请输入有效的余额');
      return;
    }
    Store.put(Config.KEY_NETWORK_BALANCE, `${parsed}`);
    Store.put(Config.KEY_NETWORK_UPDATED_AT, `${Date.now()}`);
    Store.put(Config.KEY_NETWORK_ALERT_ACTIVE, false);
    this.inputBalance = '';
    this.refresh();
    CampusData.updateNetworkAlert(parsed);
    this.showToast('余额已保存');
  }

  private saveLeadDays(): void {
    const parsed: number = Number.parseFloat(this.leadDaysText.trim());
    if (!Number.isFinite(parsed) || parsed < 0) {
      this.showToast('请输入有效的提醒天数');
      return;
    }
    Store.put(Config.KEY_NETWORK_LEAD_DAYS, `${Math.floor(parsed)}`);
    this.leadDaysText = `${Math.floor(parsed)}`;
    this.recompute(Store.getNetworkBalance());
    this.showToast('提醒天数已保存');
  }

  private openSync(): void {
    const params: SyncPageParams = { target: 'network', chain: false };
    this.getUIContext().getRouter().pushUrl({ url: 'pages/sync', params: params });
  }

  private createCalendarEvent(): void {
    const balance: number = Store.getNetworkBalance();
    const price: number = this.packagePrice;
    if (!Number.isFinite(balance)) {
      this.showToast('请先更新或输入账户余额');
      return;
    }
    if (!Number.isFinite(price) || price <= 0) {
      this.showToast('请先选择当前套餐');
      return;
    }
    const now: Date = new Date();
    const covered: number = NetworkFeeMath.monthsCovered(balance, price);
    const remind: number = NetworkFeeMath.reminderClock(
      NetworkFeeMath.reminderTime(balance, price, this.parseLeadDays(), now));
    const expiry: number = NetworkFeeMath.expiryTime(balance, price, now);
    const name: string = this.packageName.length > 0 ? this.packageName : `${price}元套餐`;
    const title: string = covered === 0
      ? '校园网余额不足，请立即充值'
      : '校园网套餐余额即将不足，请充值';
    const description: string =
      `当前套餐：${name}（${price.toFixed(0)} 元/月）；账户余额：${balance.toFixed(2)} 元；` +
      `可覆盖 ${covered} 个月；预计 ${NetworkFeeMath.formatDate(expiry)} 起无法继续自动续订，请提前充值。`;
    const input: NetworkCalendarEvent = {
      title: title,
      description: description,
      startTime: remind,
      endTime: remind + 30 * 60 * 1000
    };
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.working = true;
    CalendarService.saveEvent(context, Store.getNetworkCalendarEventId(), input)
      .then((id: number) => {
        this.working = false;
        if (id < 0) {
          this.showToast('创建日历提醒失败，请检查日历权限');
          return;
        }
        Store.put(Config.KEY_NETWORK_CALENDAR_EVENT_ID, id);
        this.hasEvent = true;
        this.showToast(`已创建 ${NetworkFeeMath.formatDate(remind)} 的日历提醒`);
      }).catch((_error: Object) => {
        this.working = false;
        this.showToast('创建日历提醒失败，请检查日历权限');
      });
  }

  private showToast(message: string): void {
    const options: promptAction.ShowToastOptions = { message: message };
    this.getUIContext().getPromptAction().showToast(options);
  }
}
