import { calendarManager } from '@kit.CalendarKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { Config } from '../common/Config';

export interface NetworkCalendarEvent {
  title: string;
  description: string;
  startTime: number;
  endTime: number;
}

export class CalendarService {
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    const permissions: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, permissions);
      for (let i = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] !== 0) {
          return false;
        }
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  static async saveEvent(context: common.UIAbilityContext, eventId: number,
    input: NetworkCalendarEvent): Promise<number> {
    const granted: boolean = await CalendarService.requestPermission(context);
    if (!granted) {
      return -1;
    }
    const calendar: calendarManager.Calendar | undefined =
      await CalendarService.ensureCalendar(context);
    if (calendar === undefined) {
      return -1;
    }
    if (eventId > 0) {
      const update: calendarManager.Event = {
        id: eventId,
        title: input.title,
        description: input.description,
        type: calendarManager.EventType.NORMAL,
        startTime: input.startTime,
        endTime: input.endTime,
        reminderTime: [0]
      };
      try {
        await calendar.updateEvent(update);
        return eventId;
      } catch (error) {
      }
    }
    const event: calendarManager.Event = {
      title: input.title,
      description: input.description,
      type: calendarManager.EventType.NORMAL,
      startTime: input.startTime,
      endTime: input.endTime,
      reminderTime: [0]
    };
    try {
      return await calendar.addEvent(event);
    } catch (error) {
      return -1;
    }
  }

  static async deleteEvent(context: common.UIAbilityContext, eventId: number): Promise<boolean> {
    if (eventId <= 0) {
      return false;
    }
    const granted: boolean = await CalendarService.requestPermission(context);
    if (!granted) {
      return false;
    }
    const calendar: calendarManager.Calendar | undefined =
      await CalendarService.ensureCalendar(context);
    if (calendar === undefined) {
      return false;
    }
    try {
      await calendar.deleteEvent(eventId);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static async ensureCalendar(
    context: common.UIAbilityContext): Promise<calendarManager.Calendar | undefined> {
    const manager: calendarManager.CalendarManager = calendarManager.getCalendarManager(context);
    const account: calendarManager.CalendarAccount = {
      name: Config.CALENDAR_ACCOUNT_NAME,
      type: calendarManager.CalendarType.LOCAL,
      displayName: Config.CALENDAR_DISPLAY_NAME
    };
    try {
      return await manager.getCalendar(account);
    } catch (error) {
    }
    try {
      const created: calendarManager.Calendar = await manager.createCalendar(account);
      const config: calendarManager.CalendarConfig = {
        enableReminder: true,
        color: '#2F80ED'
      };
      try {
        await created.setConfig(config);
      } catch (error) {
      }
      return created;
    } catch (error) {
      return undefined;
    }
  }
}
