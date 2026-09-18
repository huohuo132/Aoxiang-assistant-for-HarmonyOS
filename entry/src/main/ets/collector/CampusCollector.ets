import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { Config } from '../common/Config';
import { CampusData } from '../services/CampusData';
import { Store } from '../services/Store';
import { GradeRecord, GradeRowData } from '../model/GradeRecord';

export type SyncTarget = 'grades' | 'electricity' | 'validate' | 'bootstrap' | 'network';

export interface CollectorResult {
  phase: string;
  message: string;
  rows: Array<GradeRowData>;
  cells: Array<Array<string>>;
  gpa: number | null;
  balance: number;
  packageName: string;
  packagePrice: number;
  complete: boolean;
}

export interface CollectorListener {
  onStatus: (text: string) => void;
  onFinished: (ok: boolean, message: string) => void;
  onCredentialsRequired: (explicitError: boolean) => void;
  onSmsRequired: (invalid: boolean) => void;
  onInteractiveLogin: () => void;
  onInteractivePassed: () => void;
}

export class CampusCollector {
  private controller: webview.WebviewController;
  private listener: CollectorListener;
  private apiScript: string;
  private autoScript: string;

  private target: SyncTarget = 'validate';
  private timerId: number = -1;
  private attempts: number = 0;
  private navigationCooldownUntil: number = 0;
  private credentialsSubmittedAt: number = 0;
  private credentialsSubmitted: boolean = false;
  private smsCode: string = '';
  private smsSubmitted: boolean = false;
  private authVisited: boolean = false;
  private authExited: boolean = false;
  private pendingGradeRows: Array<GradeRowData> = [];
  private portraitStartedAt: number = 0;
  private finished: boolean = false;
  private username: string = '';
  private password: string = '';

  constructor(controller: webview.WebviewController, listener: CollectorListener,
    apiScript: string, autoScript: string) {
    this.controller = controller;
    this.listener = listener;
    this.apiScript = apiScript;
    this.autoScript = autoScript;
  }

  start(target: SyncTarget, username: string, password: string): void {
    this.target = target;
    this.username = username;
    this.password = password;
    this.resetRunState();
    this.trackAuth();
    let url: string = Config.EDUCATION_SSO;
    if (target === 'electricity') {
      url = Config.ELECTRICITY_SSO;
    } else if (target === 'network') {
      url = Config.NETWORK_PORTAL;
    }
    try {
      this.controller.loadUrl(url);
    } catch (error) {
    }
    this.listener.onStatus('正在登录…');
    this.schedulePoll();
  }

  switchToBootstrap(): void {
    this.target = 'bootstrap';
    this.resetRunState();
    this.listener.onStatus('请在统一认证页面完成登录');
    this.schedulePoll();
  }

  submitSmsCode(code: string): void {
    this.smsCode = code;
    this.smsSubmitted = false;
  }

  stop(): void {
    this.finished = true;
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private resetRunState(): void {
    this.stop();
    this.finished = false;
    this.attempts = 0;
    this.navigationCooldownUntil = 0;
    this.credentialsSubmittedAt = 0;
    this.credentialsSubmitted = false;
    this.smsSubmitted = false;
    this.pendingGradeRows = [];
    this.portraitStartedAt = 0;
  }

  private schedulePoll(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
    }
    this.timerId = setInterval((): void => {
      this.poll();
    }, Config.POLL_INTERVAL_MS);
  }

  private poll(): void {
    if (this.finished) {
      return;
    }
    this.attempts++;
    if (this.attempts > Config.MAX_ATTEMPTS) {
      this.fail('自动采集超时，请稍后重试');
      return;
    }
    this.trackAuth();
    if (this.pendingGradeRows.length > 0 && this.portraitStartedAt > 0 &&
      Date.now() - this.portraitStartedAt >= Config.PORTRAIT_TIMEOUT_MS) {
      this.completeGrades(this.pendingGradeRows, undefined);
      return;
    }
    const script: string = this.buildScript(this.apiScript);
    this.controller.runJavaScript(script).then((result: string) => {
      this.handleResult(this.parseResult(result), true);
    }).catch((_error: BusinessError): void => {
    });
  }

  private runAuto(): void {
    const script: string = this.buildScript(this.autoScript);
    this.controller.runJavaScript(script).then((result: string) => {
      this.handleResult(this.parseResult(result), false);
    }).catch((_error: BusinessError): void => {
    });
  }

  private buildScript(template: string): string {
    const allowNavigation: boolean = Date.now() >= this.navigationCooldownUntil;
    const canAutofill: boolean = this.target !== 'bootstrap' && this.target !== 'network' &&
      !this.credentialsSubmitted && this.username.length > 0 && this.password.length > 0;
    const canFillSms: boolean = !this.smsSubmitted && this.smsCode.length > 0;
    let script: string = template;
    script = script.split('__MODE__').join(this.target);
    script = script.split('__ALLOW_NAV__').join(allowNavigation ? 'true' : 'false');
    script = script.split('__USERNAME__').join(JSON.stringify(this.username));
    script = script.split('__PASSWORD__').join(JSON.stringify(this.password));
    script = script.split('__SMS_CODE__').join(JSON.stringify(this.smsCode));
    script = script.split('__CAN_AUTOFILL__').join(canAutofill ? 'true' : 'false');
    script = script.split('__CAN_FILL_SMS__').join(canFillSms ? 'true' : 'false');
    script = script.split('__HEADLESS__').join('false');
    script = script.split('__AUTH_EXITED__').join(this.authExited ? 'true' : 'false');
    return script;
  }

  private parseResult(result: string): CollectorResult | undefined {
    let raw: string = (result ?? '').trim();
    if (raw.length === 0 || raw === 'null' || raw === 'undefined') {
      return undefined;
    }
    if (raw.startsWith('"') && raw.endsWith('"')) {
      try {
        raw = JSON.parse(raw) as string;
      } catch (error) {
        return undefined;
      }
    }
    if (!raw.startsWith('{')) {
      return undefined;
    }
    try {
      return JSON.parse(raw) as CollectorResult;
    } catch (error) {
      return undefined;
    }
  }

  private handleResult(result: CollectorResult | undefined, fromApi: boolean): void {
    if (this.finished) {
      return;
    }
    if (result === undefined) {
      if (fromApi) {
        this.runAuto();
      }
      return;
    }
    const phase: string = result.phase;
    if (phase === 'credentials_pending' &&
      this.credentialsSubmittedAt > 0 &&
      Date.now() - this.credentialsSubmittedAt < Config.CREDENTIAL_REDIRECT_GRACE_MS) {
      this.listener.onStatus('正在验证账号…');
      return;
    }
    const effectivePhase: string = phase === 'credentials_pending' ? 'credentials_required' : phase;

    if (this.target === 'network') {
      if (effectivePhase === 'network_login') {
        this.listener.onStatus('请在页面中输入账号、密码和验证码完成登录');
        return;
      }
      if (effectivePhase === 'network_waiting') {
        this.listener.onStatus('正在读取套餐与余额…');
        return;
      }
      if (effectivePhase === 'network_result') {
        if (Number.isFinite(result.balance)) {
          CampusData.applyNetworkFee(result.balance, result.packageName, result.packagePrice);
          this.finish(true, `网费余额已更新：${result.balance.toFixed(2)} 元`);
        } else {
          this.listener.onStatus('未读取到网费信息，请确认已登录网络自助系统');
        }
        return;
      }
      if (effectivePhase === 'api_unavailable') {
        this.listener.onStatus('正在打开网络自助系统…');
        return;
      }
      this.listener.onStatus('正在读取套餐与余额…');
      return;
    }

    if (this.target === 'bootstrap') {
      if (effectivePhase === 'credentials_valid') {
        this.stop();
        this.listener.onInteractivePassed();
        return;
      }
      this.listener.onStatus('请在统一认证页面完成登录');
      return;
    }

    if (this.target === 'grades' || this.target === 'electricity') {
      if (effectivePhase === 'credentials_required' || effectivePhase === 'credentials_error' ||
        effectivePhase === 'interactive_login' || effectivePhase === 'sms_required' ||
        effectivePhase === 'sms_error') {
        this.stop();
        this.listener.onInteractiveLogin();
        return;
      }
    }

    if (effectivePhase === 'credentials_required' || effectivePhase === 'credentials_error') {
      const explicitError: boolean = effectivePhase === 'credentials_error';
      Store.put(Config.KEY_CREDENTIALS_VERIFIED, false);
      let failureCount: number = 0;
      if (explicitError) {
        failureCount = Store.getNumber(Config.KEY_CREDENTIAL_FAILURE_COUNT, 0) + 1;
        Store.put(Config.KEY_CREDENTIAL_FAILURE_COUNT, failureCount);
      } else {
        Store.put(Config.KEY_CREDENTIAL_FAILURE_COUNT, 0);
      }
      if (failureCount >= 2) {
        this.stop();
        this.listener.onInteractiveLogin();
        return;
      }
      this.stop();
      this.listener.onCredentialsRequired(explicitError);
      return;
    }

    if (effectivePhase === 'credentials_submitting') {
      this.credentialsSubmitted = true;
      this.credentialsSubmittedAt = Date.now();
      this.listener.onStatus('正在登录…');
      return;
    }
    if (effectivePhase === 'sms_required' || effectivePhase === 'sms_error') {
      if (effectivePhase === 'sms_error') {
        this.smsCode = '';
      }
      this.listener.onSmsRequired(effectivePhase === 'sms_error');
      return;
    }
    if (effectivePhase === 'sms_submitting') {
      this.smsSubmitted = true;
      this.listener.onStatus('正在登录…');
      return;
    }
    if (effectivePhase === 'clicked') {
      this.navigationCooldownUntil = Date.now() + Config.NAVIGATION_COOLDOWN_MS;
      this.listener.onStatus('正在打开目标页面…');
      return;
    }
    if (effectivePhase === 'page') {
      this.navigationCooldownUntil = Date.now() + 1500;
      this.listener.onStatus('正在读取数据…');
      return;
    }
    if (effectivePhase === 'waiting' || effectivePhase === 'api_waiting') {
      this.listener.onStatus('正在读取数据…');
      return;
    }
    if (effectivePhase === 'api_unavailable') {
      if (fromApi) {
        this.runAuto();
      }
      return;
    }
    if (effectivePhase === 'target_error') {
      if (fromApi) {
        this.runAuto();
        return;
      }
      this.fail(result.message.length > 0 ? result.message : '接口读取失败，请稍后重试');
      return;
    }
    if (effectivePhase === 'credentials_valid' && this.target === 'validate') {
      Store.put(Config.KEY_CREDENTIALS_VERIFIED, true);
      Store.put(Config.KEY_CREDENTIAL_FAILURE_COUNT, 0);
      this.finish(true, '账号验证成功');
      return;
    }
    if (effectivePhase === 'grades_result' && this.target === 'grades') {
      if (!result.complete) {
        this.fail('成绩数据暂时不完整，请稍后重试');
        return;
      }
      if (result.rows.length === 0) {
        this.fail('未读取到成绩数据');
        return;
      }
      if (result.gpa !== null) {
        this.completeGrades(result.rows, result.gpa);
        return;
      }
      this.pendingGradeRows = result.rows;
      this.portraitStartedAt = Date.now();
      this.navigationCooldownUntil = Date.now() + 2000;
      this.listener.onStatus('正在读取学生画像 GPA…');
      try {
        this.controller.loadUrl(Config.STUDENT_PORTRAIT);
      } catch (error) {
      }
      return;
    }
    if (effectivePhase === 'portrait_data' && this.target === 'grades') {
      if (this.pendingGradeRows.length > 0 && result.gpa !== null) {
        this.completeGrades(this.pendingGradeRows, result.gpa);
      }
      return;
    }
    if (effectivePhase === 'portrait_page' && this.target === 'grades') {
      this.listener.onStatus('正在读取学生画像 GPA…');
      return;
    }
    if (effectivePhase === 'grades_table' && this.target === 'grades') {
      const records: Array<GradeRecord> = [];
      result.cells.forEach((cells: Array<string>) => {
        records.push(GradeRecord.fromCells(cells));
      });
      if (records.length === 0) {
        this.fail('未读取到成绩数据');
        return;
      }
      const message: string = CampusData.applyGradeRecords(records, undefined);
      this.finish(true, message);
      return;
    }
    if (effectivePhase === 'electricity_result') {
      if (Number.isFinite(result.balance)) {
        CampusData.applyElectricity(result.balance);
        this.finish(true, `电费余额已更新：${result.balance.toFixed(2)} 度`);
      }
      return;
    }
  }

  private completeGrades(rows: Array<GradeRowData>, gpa: number | undefined): void {
    const message: string = CampusData.applyGrades(rows, gpa);
    this.finish(true, message);
  }

  private finish(ok: boolean, message: string): void {
    this.stop();
    this.listener.onFinished(ok, message);
  }

  private fail(message: string): void {
    this.finish(false, message);
  }

  private trackAuth(): void {
    try {
      const current: string = this.controller.getUrl();
      if (current.includes('uis.nwpu.edu.cn')) {
        this.authVisited = true;
      } else if (this.authVisited && current.includes(Config.DOMAIN)) {
        this.authExited = true;
      }
    } catch (error) {
    }
  }
}
