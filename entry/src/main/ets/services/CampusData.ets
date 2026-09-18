import { Config } from '../common/Config';
import { GradeRecord, GradeRowData } from '../model/GradeRecord';
import { NetworkFeeMath } from '../model/NetworkFee';
import { UpdateDiff } from '../model/UpdateDiff';
import { Store } from './Store';
import { Notifier } from './Notifier';

export class CampusData {
  static applyGrades(rows: Array<GradeRowData>, gpa: number | undefined): string {
    const records: Array<GradeRecord> = [];
    rows.forEach((row: GradeRowData) => {
      records.push(GradeRecord.fromRowData(row));
    });
    return CampusData.applyGradeRecords(records, gpa);
  }

  static applyGradeRecords(records: Array<GradeRecord>, gpa: number | undefined): string {
    const before: Array<GradeRecord> = Store.loadGrades();
    const isFirstImport: boolean = before.length === 0;
    const merged: Array<GradeRecord> = GradeRecord.keepHighest(records);
    const changed: Array<string> = UpdateDiff.changedNames(
      UpdateDiff.gradeItems(before), UpdateDiff.gradeItems(merged));
    Store.saveGrades(merged);
    if (gpa !== undefined) {
      Store.put(Config.KEY_PORTRAIT_GPA, `${gpa}`);
    }
    if (!isFirstImport && changed.length > 0) {
      const text: string = UpdateDiff.notificationText(changed);
      Notifier.publishGradeUpdate(text);
      return text;
    }
    return `已更新 ${merged.length} 门课程`;
  }

  static applyElectricity(balance: number): void {
    Store.put(Config.KEY_ELECTRICITY_BALANCE, `${balance}`);
    Store.put(Config.KEY_ELECTRICITY_SOURCE, 'ELECTRICITY_HOME');
    CampusData.updateElectricityAlert(balance);
  }

  static applyNetworkFee(balance: number, packageName: string, packagePrice: number): void {
    Store.put(Config.KEY_NETWORK_BALANCE, `${balance}`);
    if (Number.isFinite(packagePrice) && packagePrice > 0) {
      Store.put(Config.KEY_NETWORK_PACKAGE_PRICE, `${packagePrice}`);
      if (packageName.length > 0) {
        Store.put(Config.KEY_NETWORK_PACKAGE_NAME, packageName);
      }
    }
    Store.put(Config.KEY_NETWORK_UPDATED_AT, `${Date.now()}`);
    CampusData.updateNetworkAlert(balance);
  }

  static updateNetworkAlert(balance: number): void {
    const price: number = Store.getNetworkPackagePrice();
    if (!Number.isFinite(price) || price <= 0) {
      return;
    }
    const enabled: boolean = Store.getBool(Config.KEY_NETWORK_ALERT_ENABLED, true);
    const active: boolean = Store.getBool(Config.KEY_NETWORK_ALERT_ACTIVE, false);
    const covered: number = NetworkFeeMath.monthsCovered(balance, price);
    const low: boolean = enabled && covered <= 1;
    if (low && !active) {
      const text: string = covered === 0
        ? `余额 ${balance.toFixed(2)} 元，已不足以支付 ${price.toFixed(0)} 元套餐，请及时充值`
        : `余额 ${balance.toFixed(2)} 元，仅够支付 1 个月 ${price.toFixed(0)} 元套餐，请及时充值`;
      Notifier.publishNetworkAlert(text);
    }
    Store.put(Config.KEY_NETWORK_ALERT_ACTIVE, low);
  }

  static setNetworkPackage(price: number, name: string): void {
    Store.put(Config.KEY_NETWORK_PACKAGE_PRICE, `${price}`);
    Store.put(Config.KEY_NETWORK_PACKAGE_NAME, name);
    Store.put(Config.KEY_NETWORK_ALERT_ACTIVE, false);
  }

  static updateElectricityAlert(balance: number): void {
    const enabled: boolean = Store.getBool(Config.KEY_ELECTRICITY_ALERT_ENABLED, true);
    const threshold: number = Store.getNumber(Config.KEY_ELECTRICITY_ALERT_THRESHOLD, 20);
    const active: boolean = Store.getBool(Config.KEY_ELECTRICITY_ALERT_ACTIVE, false);
    const low: boolean = enabled && balance < threshold;
    if (low && !active) {
      Notifier.publishElectricityAlert(
        `剩余 ${balance.toFixed(2)} 度，低于 ${threshold.toFixed(2)} 度`);
    }
    Store.put(Config.KEY_ELECTRICITY_ALERT_ACTIVE, low);
  }
}
