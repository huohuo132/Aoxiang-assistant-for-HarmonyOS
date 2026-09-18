import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { Config } from '../common/Config';

export class Notifier {
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return true;
    } catch (error) {
      return false;
    }
  }

  static publishGradeUpdate(text: string): void {
    Notifier.publish(Config.NOTIFICATION_ID_GRADE, '成绩有更新', text);
  }

  static publishElectricityAlert(text: string): void {
    Notifier.publish(Config.NOTIFICATION_ID_ELECTRICITY, '电费余额不足', text);
  }

  static publishAuthentication(text: string): void {
    Notifier.publish(1006, '登录验证', text);
  }

  private static publish(id: number, title: string, text: string): void {
    const normal: notificationManager.NotificationBasicContent = {
      title: title,
      text: text,
      additionalText: ''
    };
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: normal
    };
    const request: notificationManager.NotificationRequest = {
      id: id,
      content: content
    };
    notificationManager.publish(request).then((): void => {
    }).catch((error: BusinessError): void => {
      console.error(`publish notification failed: ${error.code} ${error.message}`);
    });
  }
}
