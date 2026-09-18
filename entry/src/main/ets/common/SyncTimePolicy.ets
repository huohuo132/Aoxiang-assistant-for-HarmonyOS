export class SyncTimePolicy {
  static isElectricitySettlementTime(now: Date): boolean {
    return now.getHours() === 0;
  }
}
