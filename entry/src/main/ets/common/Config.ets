export class Config {
  static readonly EDUCATION_SSO: string = 'https://jwxt.nwpu.edu.cn/student/sso-login';
  static readonly ELECTRICITY_SSO: string =
    'https://yktapp.nwpu.edu.cn/berserker-auth/cas/login/supwisdom?targetUrl=https%3A%2F%2Fyktapp.nwpu.edu.cn%2Fplat';
  static readonly STUDENT_PORTRAIT: string = 'https://jwxt.nwpu.edu.cn/student/for-std/student-portrait';
  static readonly DOMAIN: string = 'nwpu.edu.cn';
  static readonly PREF_NAME: string = 'campus_private';

  static readonly POLL_INTERVAL_MS: number = 1000;
  static readonly MAX_ATTEMPTS: number = 180;
  static readonly PORTRAIT_TIMEOUT_MS: number = 15000;
  static readonly CREDENTIAL_REDIRECT_GRACE_MS: number = 20000;
  static readonly NAVIGATION_COOLDOWN_MS: number = 2500;

  static readonly KEY_GRADES: string = 'grades';
  static readonly KEY_PORTRAIT_GPA: string = 'portrait_gpa';
  static readonly KEY_ELECTRICITY_BALANCE: string = 'electricity_balance';
  static readonly KEY_ELECTRICITY_SOURCE: string = 'electricity_balance_source';
  static readonly KEY_ELECTRICITY_ALERT_ENABLED: string = 'electricity_alert_enabled';
  static readonly KEY_ELECTRICITY_ALERT_THRESHOLD: string = 'electricity_alert_threshold';
  static readonly KEY_ELECTRICITY_ALERT_ACTIVE: string = 'electricity_alert_active';
  static readonly KEY_CREDENTIALS: string = 'login_credentials';
  static readonly KEY_CREDENTIALS_VERIFIED: string = 'credentials_verified';
  static readonly KEY_CREDENTIAL_FAILURE_COUNT: string = 'credential_failure_count';

  static readonly NOTIFICATION_ID_GRADE: number = 1001;
  static readonly NOTIFICATION_ID_ELECTRICITY: number = 1002;
}

export class Theme {
  static readonly primary: string = '#2F80ED';
  static readonly primaryLight: string = '#EAF4FF';
  static readonly background: string = '#F6FAFF';
  static readonly surface: string = '#FFFFFF';
  static readonly ink: string = '#19324D';
  static readonly muted: string = '#5E7185';
  static readonly line: string = '#E5EDF5';
  static readonly green: string = '#219653';
  static readonly orange: string = '#F2994A';
}
