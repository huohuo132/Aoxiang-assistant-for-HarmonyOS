import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { CredentialStore } from '../services/CredentialStore';
import { Store } from '../services/Store';
import { Theme } from '../common/Config';
import { SyncPageParams } from '../common/RouteParams';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State hasSaved: boolean = false;
  @State saving: boolean = false;

  aboutToAppear(): void {
    this.hasSaved = Store.hasSavedCredentials();
    if (this.hasSaved) {
      CredentialStore.read().then((creds: Array<string>) => {
        this.username = creds[0] ?? '';
      }).catch((_error: Object) => {
      });
    }
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
        Text('登录翱翔门户')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink)
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })

      Scroll() {
        Column() {
          Column() {
            Text('翱翔助手')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Text('保存前会先验证账号和密码')
              .fontSize(12)
              .fontColor(Theme.muted)
              .margin({ top: 8 })
          }
          .width('100%')
          .margin({ top: 24, bottom: 20 })
          .justifyContent(FlexAlign.Center)

          Column() {
            Text('学号')
              .fontSize(12)
              .fontColor(Theme.muted)
            TextInput({ placeholder: '学号', text: this.username })
              .height(48)
              .fontSize(15)
              .fontColor(Theme.ink)
              .backgroundColor(Theme.background)
              .borderRadius(10)
              .margin({ top: 8 })
              .onChange((value: string) => {
                this.username = value;
              })
            Text('翱翔门户密码')
              .fontSize(12)
              .fontColor(Theme.muted)
              .margin({ top: 16 })
            TextInput({ placeholder: '翱翔门户密码', text: this.password })
              .type(InputType.Password)
              .height(48)
              .fontSize(15)
              .fontColor(Theme.ink)
              .backgroundColor(Theme.background)
              .borderRadius(10)
              .margin({ top: 8 })
              .onChange((value: string) => {
                this.password = value;
              })
            Button(this.hasSaved ? '保存并验证' : '登录')
              .width('100%')
              .height(46)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor(Theme.primary)
              .borderRadius(12)
              .margin({ top: 24 })
              .enabled(!this.saving)
              .onClick(() => {
                this.handleLogin();
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor(Theme.surface)
          .borderRadius(16)

          Column() {
            Text('登录说明')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Text('1. 首次登录会自动同步成绩与电费数据\n2. 连续两次失败后将打开统一认证页人工登录\n3. 只有实际进入教务系统才算认证成功\n4. 账号密码使用系统密钥加密存储在本机')
              .fontSize(12)
              .fontColor(Theme.muted)
              .margin({ top: 8 })
              .lineHeight(20)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor(Theme.surface)
          .borderRadius(16)
          .margin({ top: 14 })

          if (this.hasSaved) {
            Button('退出登录')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.orange)
              .backgroundColor(Theme.surface)
              .borderRadius(12)
              .margin({ top: 14 })
              .onClick(() => {
                this.handleLogout();
              })
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

  private handleLogin(): void {
    const account: string = this.username.trim();
    const secret: string = this.password;
    if (account.length === 0 || secret.length === 0) {
      this.showToast('请输入账号和密码');
      return;
    }
    this.saving = true;
    CredentialStore.save(account, secret).then((ok: boolean) => {
      this.saving = false;
      if (!ok) {
        this.showToast('无法安全保存账号，请重试');
        return;
      }
      const params: SyncPageParams = { target: 'validate', chain: true };
      this.getUIContext().getRouter().pushUrl({ url: 'pages/sync', params: params });
    }).catch((_error: Object) => {
      this.saving = false;
      this.showToast('无法安全保存账号，请重试');
    });
  }

  private handleLogout(): void {
    CredentialStore.clear();
    Store.remove('auto_last_grades');
    Store.remove('auto_last_electricity');
    webview.WebCookieManager.clearAllCookies().then((): void => {
    }).catch((_error: Object) => {
    });
    this.showToast('已退出登录');
    this.hasSaved = false;
    this.password = '';
  }

  private showToast(message: string): void {
    const options: promptAction.ShowToastOptions = { message: message };
    this.getUIContext().getPromptAction().showToast(options);
  }
}
