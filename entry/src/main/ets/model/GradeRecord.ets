export interface GradeRowData {
  course: string;
  credits: number;
  point: number | null;
  grade: string;
  detail: string;
}

export class GradeRecord {
  course: string = '';
  category: string = '课程';
  detail: string = '';
  credits: number = 0;
  point: number | undefined = undefined;
  score: number | undefined = undefined;

  static of(course: string, credits: number, point: number | undefined,
    score: number | undefined, category: string, detail: string): GradeRecord {
    const record: GradeRecord = new GradeRecord();
    record.course = course;
    record.credits = credits;
    record.point = point;
    record.score = score;
    record.category = category;
    record.detail = detail;
    return record;
  }

  pointText(): string {
    return this.point === undefined ? '--' : this.point.toFixed(1);
  }

  scoreText(): string {
    return this.score === undefined ? '--' : this.score.toFixed(0);
  }

  diffKey(): string {
    return GradeRecord.normalizeCourseName(this.course);
  }

  diffSignature(): string {
    const pointPart: string = this.point === undefined ? '' : this.point.toFixed(6);
    const scorePart: string = this.score === undefined ? '' : this.score.toFixed(6);
    return this.diffKey() + '|' + this.credits.toFixed(6) + '|' + pointPart + '|' +
      scorePart + '|' + GradeRecord.cleanDetail(this.detail);
  }

  toJson(): string {
    const pointPart: string = this.point === undefined ? 'null' : `${this.point}`;
    const scorePart: string = this.score === undefined ? 'null' : `${this.score}`;
    return `{"course":${JSON.stringify(this.course)},"credits":${this.credits},` +
      `"point":${pointPart},"score":${scorePart},` +
      `"category":${JSON.stringify(this.category)},"detail":${JSON.stringify(this.detail)}}`;
  }

  static fromRowData(row: GradeRowData): GradeRecord {
    const point: number | undefined = row.point === null ? undefined : row.point;
    const score: number | undefined = GradeRecord.parseNumber(row.grade);
    return GradeRecord.of(row.course, row.credits, point, score, '课程',
      GradeRecord.cleanDetail(row.detail));
  }

  static fromCells(cells: Array<string>): GradeRecord {
    const course: string = cells.length > 0 ? cells[0] : '';
    const credits: number = GradeRecord.parseNumber(cells.length > 1 ? cells[1] : '') ?? 0;
    const point: number | undefined = GradeRecord.parseNumber(cells.length > 2 ? cells[2] : '');
    const score: number | undefined = GradeRecord.parseNumber(cells.length > 3 ? cells[3] : '');
    const detail: string = cells.length > 4 ? cells[4] : '';
    return GradeRecord.of(course, credits, point, score, '课程', GradeRecord.cleanDetail(detail));
  }

  static keepHighest(records: Array<GradeRecord>): Array<GradeRecord> {
    const bestByCourse: Map<string, GradeRecord> = new Map<string, GradeRecord>();
    records.forEach((candidate: GradeRecord) => {
      const key: string = candidate.diffKey();
      if (key.length === 0) {
        return;
      }
      const current: GradeRecord | undefined = bestByCourse.get(key);
      if (current === undefined || GradeRecord.isHigher(candidate, current)) {
        bestByCourse.set(key, candidate);
      }
    });
    return Array.from(bestByCourse.values());
  }

  static normalizeCourseName(value: string): string {
    return value.trim().replace(new RegExp('\\s+', 'g'), ' ').toLowerCase();
  }

  static cleanDetail(raw: string): string {
    let value: string = raw;
    for (let pass = 0; pass < 2; pass++) {
      value = value.replace(new RegExp('&nbsp;', 'g'), ' ')
        .replace(new RegExp('&quot;', 'g'), '"')
        .replace(new RegExp('&#39;', 'g'), "'")
        .replace(new RegExp('&#x27;', 'g'), "'")
        .replace(new RegExp('&lt;', 'g'), '<')
        .replace(new RegExp('&gt;', 'g'), '>')
        .replace(new RegExp('&amp;', 'g'), '&');
      value = value.replace(new RegExp('<br\\s*/?>', 'gi'), ' ')
        .replace(new RegExp('<[^>]*>', 'g'), ' ');
    }
    return value.replace(new RegExp('\\\\n', 'g'), ' ')
      .replace(new RegExp('\\\\r', 'g'), ' ')
      .replace(new RegExp('\\s+', 'g'), ' ')
      .trim();
  }

  private static isHigher(candidate: GradeRecord, current: GradeRecord): boolean {
    if (candidate.score !== undefined || current.score !== undefined) {
      if (candidate.score === undefined) {
        return false;
      }
      if (current.score === undefined) {
        return true;
      }
      if (candidate.score !== current.score) {
        return candidate.score > current.score;
      }
    }
    if (candidate.point === undefined) {
      return false;
    }
    return current.point === undefined || candidate.point > current.point;
  }

  private static parseNumber(value: string): number | undefined {
    const cleaned: string = value.replace(new RegExp('[^0-9.\\-]', 'g'), '');
    if (cleaned.length === 0) {
      return undefined;
    }
    const parsed: number = Number.parseFloat(cleaned);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
}
