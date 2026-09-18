export class GradeMath {
  static weightedAverage(credits: Array<number>, values: Array<number>): number {
    if (credits.length !== values.length) {
      return Number.NaN;
    }
    let weighted: number = 0;
    let includedCredits: number = 0;
    for (let i = 0; i < credits.length; i++) {
      if (credits[i] > 0 && Number.isFinite(values[i])) {
        weighted += credits[i] * values[i];
        includedCredits += credits[i];
      }
    }
    return includedCredits === 0 ? Number.NaN : weighted / includedCredits;
  }
}
