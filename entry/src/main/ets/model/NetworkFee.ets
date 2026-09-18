export class NetworkPackage {
  name: string;
  price: number;
  traffic: string;

  constructor(name: string, price: number, traffic: string) {
    this.name = name;
    this.price = price;
    this.traffic = traffic;
  }

  static options(): Array<NetworkPackage> {
    const list: Array<NetworkPackage> = [];
    list.push(new NetworkPackage('10元包30GB', 10, '30GB'));
    list.push(new NetworkPackage('20元包80GB', 20, '80GB'));
    list.push(new NetworkPackage('30元包130GB', 30, '130GB'));
    list.push(new NetworkPackage('50元包月不限量', 50, '不限量'));
    return list;
  }

  static ofPrice(price: number): NetworkPackage | undefined {
    if (!Number.isFinite(price) || price <= 0) {
      return undefined;
    }
    const list: Array<NetworkPackage> = NetworkPackage.options();
    for (let i = 0; i < list.length; i++) {
      if (list[i].price === price) {
        return list[i];
      }
    }
    return undefined;
  }

  static detect(text: string): NetworkPackage | undefined {
    const normalized: string = text.replace(new RegExp('\\s+', 'g'), ' ');
    const match: RegExpMatchArray | null =
      normalized.match(new RegExp('(\\d{1,3})\\s*元\\s*包\\s*(月不限量|月|\\d{1,4}\\s*GB|\\d{1,4}\\s*G)', 'i'));
    if (match === null) {
      return undefined;
    }
    const price: number = Number.parseFloat(match[1]);
    if (!Number.isFinite(price) || price <= 0) {
      return undefined;
    }
    const traffic: string = match[2].replace(new RegExp('\\s+', 'g'), '');
    return new NetworkPackage(`${price}元包${traffic}`, price, traffic);
  }
}

export class NetworkFeeMath {
  static readonly DEFAULT_LEAD_DAYS: number = 5;

  static monthsCovered(balance: number, price: number): number {
    if (!Number.isFinite(balance) || !Number.isFinite(price) || price <= 0 || balance < price) {
      return 0;
    }
    return Math.floor(balance / price);
  }

  static expiryTime(balance: number, price: number, now: Date): number {
    const covered: number = NetworkFeeMath.monthsCovered(balance, price);
    return new Date(now.getFullYear(), now.getMonth() + covered, 1, 0, 0, 0, 0).getTime();
  }

  static reminderTime(balance: number, price: number, leadDays: number, now: Date): number {
    const expiry: number = NetworkFeeMath.expiryTime(balance, price, now);
    const lead: number = leadDays > 0 ? Math.floor(leadDays) : 0;
    const target: number = expiry - lead * 24 * 60 * 60 * 1000;
    const today: number = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0).getTime();
    return target < today ? today : target;
  }

  static reminderClock(time: number): number {
    const date: Date = new Date(time);
    return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 9, 0, 0, 0).getTime();
  }

  static formatDate(time: number): string {
    const date: Date = new Date(time);
    return `${date.getFullYear()}-${NetworkFeeMath.pad(date.getMonth() + 1)}-${NetworkFeeMath.pad(date.getDate())}`;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
