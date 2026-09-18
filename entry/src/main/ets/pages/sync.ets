import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { CampusCollector, CollectorListener, SyncTarget } from '../collector/CampusCollector';
import { SyncPageParams } from '../common/RouteParams';
import { Config, Theme } from '../common/Config';
import { SyncTimePolicy } from '../common/SyncTimePolicy';
import { CredentialStore } from '../services/CredentialStore';
import { Store } from '../services/Store';

@Entry
@Component
struct SyncPage {
  @State statusText: string = '正在登录…';
  @State headerTitle: string = '更新成绩';
  @State showWeb: boolean = false;
  @State showSmsPanel: boolean = false;
  @State showSavePanel: boolean = false;
  @State smsInput: string = '';
  @State saveUsername: string = '';
  @State savePassword: string = '';
  @State initialUrl: string = 'about:blank';
  private controller: webview.WebviewController = new webview.WebviewController();
  private collector: CampusCollector | undefined = undefined;
  private targetQueue: Array<string> = [];
  private currentTarget: string = 'grades';
  private resumeTarget: string = '';

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as SyncPageParams;
    this.currentTarget = params?.target ?? 'grades';
    if (this.currentTarget !== 'grades' && this.currentTarget !== 'electricity' &&
      this.currentTarget !== 'validate') {
      this.currentTarget = 'grades';
    }
    const chain: boolean = params?.chain ?? false;
    if (chain && this.currentTarget === 'validate') {
      this.targetQueue = ['grades', 'electricity'];
    }
    this.headerTitle = this.labelFor(this.currentTarget);
    this.initialUrl = this.currentTarget === 'electricity' ? Config.ELECTRICITY_SSO : Config.EDUCATION_SSO;
    const apiScript: string = this.loadRawFile('api_collect.js');
    const autoScript: string = this.loadRawFile('auto_collect.js');
    this.collector = new CampusCollector(this.controller, this.createListener(), apiScript, autoScript);
    this.startTarget(this.currentTarget);
  }

  aboutToDisappear(): void {
    this.collector?.stop();
  }

  build() {
    Stack() {
      Web({ src: this.initialUrl, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .width('100%')
        .height('100%')
        .onLoadIntercept((event: OnLoadInterceptEvent) => {
          const requestUrl: string = event.data.getRequestUrl();
          return !requestUrl.includes(Config.DOMAIN) && !requestUrl.startsWith('about:');
        })

      if (this.showWeb) {
        Column() {
          Row() {
            Text('‹')
              .fontSize(32)
              .fontColor(Theme.ink)
              .width(40)
              .height(52)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.collector?.stop();
                this.getUIContext().getRouter().back();
              })
            Column() {
              Text('统一认证')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
              Text('请在页面中完成登录，成功后会自动继续')
                .fontSize(11)
                .fontColor(Theme.muted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 12, right: 12 })
          .backgroundColor(Theme.background)
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      } else {
        Column() {
          Row() {
            Text('‹')
              .fontSize(32)
              .fontColor(Theme.ink)
              .width(40)
              .height(52)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.collector?.stop();
                this.getUIContext().getRouter().back();
              })
            Column() {
              Text(this.headerTitle)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 12 })

          Column() {
            LoadingProgress()
              .width(42)
              .height(42)
              .color(Theme.primary)
            Column() {
              Text(`正在通过统一认证${this.headerTitle}`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
              Text(this.statusText)
                .fontSize(12)
                .fontColor(Theme.muted)
                .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 20, right: 20 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.background)
      }

      if (this.showSmsPanel) {
        Column() {
          Column() {
            Text('安全验证')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.primary)
            Text('输入短信验证码')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
              .margin({ top: 6 })
            Text('验证码已由校方认证系统发送，请输入后继续。')
              .fontSize(12)
              .fontColor(Theme.muted)
              .margin({ top: 6 })
            TextInput({ placeholder: '短信验证码', text: this.smsInput })
              .type(InputType.Number)
              .height(48)
              .fontSize(14)
              .fontColor(Theme.ink)
              .backgroundColor(Theme.background)
              .borderRadius(10)
              .margin({ top: 14 })
              .onChange((value: string) => {
                this.smsInput = value;
              })
            Row() {
              Button('取消')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ink)
                .backgroundColor(Theme.line)
                .onClick(() => {
                  this.showSmsPanel = false;
                  this.collector?.stop();
                  this.getUIContext().getRouter().back();
                })
              Button('验证')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor(Theme.primary)
                .margin({ left: 10 })
                .onClick(() => {
                  const code: string = this.smsInput.trim();
                  if (code.length < 4) {
                    this.showToast('请输入有效验证码');
                    return;
                  }
                  this.showSmsPanel = false;
                  this.collector?.submitSmsCode(code);
                })
            }
            .width('100%')
            .margin({ top: 14 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('86%')
          .padding({ left: 22, right: 22, top: 20, bottom: 16 })
          .backgroundColor(Theme.surface)
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(0,0,0,0.45)')
      }

      if (this.showSavePanel) {
        Column() {
          Column() {
            Text('账号')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.primary)
            Text('保存账号密码')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
              .margin({ top: 6 })
            Text('统一认证已通过，请保存账号和翱翔门户密码')
              .fontSize(12)
              .fontColor(Theme.muted)
              .margin({ top: 6 })
            TextInput({ placeholder: '学号', text: this.saveUsername })
              .height(48)
              .fontSize(14)
              .fontColor(Theme.ink)
              .backgroundColor(Theme.background)
              .borderRadius(10)
              .margin({ top: 14 })
              .onChange((value: string) => {
                this.saveUsername = value;
              })
            TextInput({ placeholder: '翱翔门户密码', text: this.savePassword })
              .type(InputType.Password)
              .height(48)
              .fontSize(14)
              .fontColor(Theme.ink)
              .backgroundColor(Theme.background)
              .borderRadius(10)
              .margin({ top: 10 })
              .onChange((value: string) => {
                this.savePassword = value;
              })
            Row() {
              Button('跳过')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.ink)
                .backgroundColor(Theme.line)
                .onClick(() => {
                  this.showSavePanel = false;
                  this.resumeAfterInteractive();
                })
              Button('保存并继续')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor(Theme.primary)
                .margin({ left: 10 })
                .onClick(() => {
                  const account: string = this.saveUsername.trim();
                  const secret: string = this.savePassword;
                  if (account.length === 0 || secret.length === 0) {
                    this.showToast('请输入账号和密码');
                    return;
                  }
                  CredentialStore.save(account, secret).then((ok: boolean) => {
                    if (!ok) {
                      this.showToast('无法安全保存账号，请重试');
                      return;
                    }
                    this.showSavePanel = false;
                    this.resumeAfterInteractive();
                  }).catch((_error: Object) => {
                    this.showToast('无法安全保存账号，请重试');
                  });
                })
            }
            .width('100%')
            .margin({ top: 14 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('86%')
          .padding({ left: 22, right: 22, top: 20, bottom: 16 })
          .backgroundColor(Theme.surface)
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(0,0,0,0.45)')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.background)
  }

  private createListener(): CollectorListener {
    const listener: CollectorListener = {
      onStatus: (text: string): void => {
        this.statusText = text;
      },
      onFinished: (ok: boolean, message: string): void => {
        this.handleFinished(ok, message);
      },
      onCredentialsRequired: (explicitError: boolean): void => {
        this.handleCredentialsRequired(explicitError);
      },
      onSmsRequired: (invalid: boolean): void => {
        this.handleSmsRequired(invalid);
      },
      onInteractiveLogin: (): void => {
        this.handleInteractiveLogin();
      },
      onInteractivePassed: (): void => {
        this.handleInteractivePassed();
      }
    };
    return listener;
  }

  private startTarget(target: string): void {
    this.currentTarget = target;
    this.headerTitle = this.labelFor(target);
    if (target === 'electricity' && SyncTimePolicy.isElectricitySettlementTime(new Date())) {
      this.showToast('电费系统正在结算，请在 1:00 后更新');
      this.getUIContext().getRouter().back();
      return;
    }
    CredentialStore.read().then((creds: Array<string>) => {
      const collector: CampusCollector | undefined = this.collector;
      if (collector === undefined) {
        return;
      }
      collector.start(target as SyncTarget, creds[0] ?? '', creds[1] ?? '');
    }).catch((_error: Object) => {
      this.showToast('读取登录信息失败');
      this.getUIContext().getRouter().back();
    });
  }

  private handleFinished(ok: boolean, message: string): void {
    if (ok) {
      const next: string | undefined = this.targetQueue.shift();
      if (next !== undefined) {
        this.startTarget(next);
        return;
      }
      this.showToast(message.length > 0 ? message : '更新完成');
      this.getUIContext().getRouter().back();
      return;
    }
    this.showToast(message.length > 0 ? message : '更新失败，请稍后重试');
    this.getUIContext().getRouter().back();
  }

  private handleCredentialsRequired(explicitError: boolean): void {
    this.showToast(explicitError ? '账号或翱翔门户密码错误' : '登录信息已失效，请重新登录');
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/login' });
  }

  private handleSmsRequired(invalid: boolean): void {
    if (this.showSmsPanel) {
      return;
    }
    this.smsInput = '';
    this.showSmsPanel = true;
    if (invalid) {
      this.showToast('验证码错误或已失效');
    }
  }

  private handleInteractiveLogin(): void {
    if (this.showWeb) {
      return;
    }
    this.resumeTarget = this.currentTarget;
    this.showSmsPanel = false;
    this.showWeb = true;
    this.collector?.switchToBootstrap();
  }

  private handleInteractivePassed(): void {
    this.showWeb = false;
    if (Store.hasSavedCredentials()) {
      Store.put(Config.KEY_CREDENTIALS_VERIFIED, true);
      Store.put(Config.KEY_CREDENTIAL_FAILURE_COUNT, 0);
      this.resumeAfterInteractive();
      return;
    }
    this.saveUsername = '';
    this.savePassword = '';
    this.showSavePanel = true;
  }

  private resumeAfterInteractive(): void {
    const target: string = this.resumeTarget.length > 0 ? this.resumeTarget : this.currentTarget;
    this.startTarget(target);
  }

  private labelFor(target: string): string {
    if (target === 'validate') {
      return '验证账号';
    }
    if (target === 'electricity') {
      return '更新电费';
    }
    return '更新成绩';
  }

  private loadRawFile(name: string): string {
    const context = this.getUIContext().getHostContext() as common.Context;
    const buffer: Uint8Array = context.resourceManager.getRawFileContentSync(name);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(buffer);
  }

  private showToast(message: string): void {
    const options: promptAction.ShowToastOptions = { message: message };
    this.getUIContext().getPromptAction().showToast(options);
  }
}
