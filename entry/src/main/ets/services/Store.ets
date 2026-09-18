import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Config } from '../common/Config';
import { GradeRecord } from '../model/GradeRecord';

interface GradeJson {
  course: string;
  credits: number;
  point: number | null;
  score: number | null;
  category: string;
  detail: string;
}

export class Store {
  private static prefs: preferences.Preferences | undefined = undefined;

  static init(context: common.Context): void {
    if (Store.prefs === undefined) {
      Store.prefs = preferences.getPreferencesSync(context, { name: Config.PREF_NAME });
    }
  }

  static getString(key: string, defaultValue: string): string {
    const value = Store.prefs?.getSync(key, defaultValue) as string;
    return value ?? defaultValue;
  }

  static getNumber(key: string, defaultValue: number): number {
    const raw: string = Store.getString(key, `${defaultValue}`);
    const parsed: number = Number.parseFloat(raw);
    return Number.isFinite(parsed) ? parsed : defaultValue;
  }

  static getBool(key: string, defaultValue: boolean): boolean {
    const value = Store.prefs?.getSync(key, defaultValue) as boolean;
    return value ?? defaultValue;
  }

  static put(key: string, value: preferences.ValueType): void {
    Store.prefs?.putSync(key, value);
    Store.prefs?.flush().catch((_error: Object) => {
    });
  }

  static remove(key: string): void {
    Store.prefs?.deleteSync(key);
    Store.prefs?.flush().catch((_error: Object) => {
    });
  }

  static loadGrades(): Array<GradeRecord> {
    const raw: string = Store.getString(Config.KEY_GRADES, '');
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as Array<GradeJson>;
      const records: Array<GradeRecord> = [];
      parsed.forEach((item: GradeJson) => {
        records.push(GradeRecord.of(item.course, item.credits,
          item.point === null ? undefined : item.point,
          item.score === null ? undefined : item.score,
          item.category.length > 0 ? item.category : '课程',
          GradeRecord.cleanDetail(item.detail)));
      });
      return GradeRecord.keepHighest(records);
    } catch (_error) {
      return [];
    }
  }

  static saveGrades(records: Array<GradeRecord>): void {
    let json: string = '[';
    for (let i = 0; i < records.length; i++) {
      if (i > 0) {
        json += ',';
      }
      json += records[i].toJson();
    }
    json += ']';
    Store.put(Config.KEY_GRADES, json);
  }

  static getPortraitGpa(): number {
    return Store.getNumber(Config.KEY_PORTRAIT_GPA, Number.NaN);
  }

  static getElectricityBalance(): number {
    return Store.getNumber(Config.KEY_ELECTRICITY_BALANCE, Number.NaN);
  }

  static hasSavedCredentials(): boolean {
    return Store.getString(Config.KEY_CREDENTIALS, '').length > 0;
  }
}
