import { GradeRecord } from './GradeRecord';

export class DiffItem {
  key: string = '';
  name: string = '';
  signature: string = '';

  static of(key: string, name: string, signature: string): DiffItem {
    const item: DiffItem = new DiffItem();
    item.key = key.trim();
    item.name = name.trim();
    item.signature = signature;
    return item;
  }
}

export class UpdateDiff {
  static changedNames(before: Array<DiffItem>, after: Array<DiffItem>): Array<string> {
    const oldItems: Map<string, DiffItem> = UpdateDiff.index(before);
    const newItems: Map<string, DiffItem> = UpdateDiff.index(after);
    const keys: Set<string> = new Set<string>();
    oldItems.forEach((_value: DiffItem, key: string) => {
      keys.add(key);
    });
    newItems.forEach((_value: DiffItem, key: string) => {
      keys.add(key);
    });

    const names: Set<string> = new Set<string>();
    keys.forEach((key: string) => {
      const oldItem: DiffItem | undefined = oldItems.get(key);
      const newItem: DiffItem | undefined = newItems.get(key);
      const changed: boolean = oldItem === undefined || newItem === undefined ||
        oldItem.signature !== newItem.signature;
      if (changed) {
        const name: string = newItem !== undefined ? newItem.name :
          (oldItem !== undefined ? oldItem.name : '');
        if (name.length > 0) {
          names.add(name);
        }
      }
    });
    const result: Array<string> = Array.from(names);
    result.sort();
    return result;
  }

  static notificationText(courseNames: Array<string>): string {
    if (courseNames.length === 0) {
      return '成绩有更新';
    }
    const suffix: string = '成绩有更新';
    if (courseNames.length === 1) {
      return courseNames[0] + suffix;
    }
    if (courseNames.length === 2) {
      return courseNames[0] + '、' + courseNames[1] + suffix;
    }
    return courseNames[0] + '、' + courseNames[1] + '等 ' + courseNames.length + ' 门' + suffix;
  }

  static gradeItems(records: Array<GradeRecord>): Array<DiffItem> {
    const items: Array<DiffItem> = [];
    records.forEach((grade: GradeRecord) => {
      items.push(DiffItem.of(grade.diffKey(), grade.course, grade.diffSignature()));
    });
    return items;
  }

  private static index(items: Array<DiffItem>): Map<string, DiffItem> {
    const result: Map<string, DiffItem> = new Map<string, DiffItem>();
    items.forEach((item: DiffItem) => {
      if (item.key.length > 0) {
        result.set(item.key, item);
      }
    });
    return result;
  }
}
