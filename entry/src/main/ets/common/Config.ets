export class Config {
  static readonly EDUCATION_SSO: string = 'https://jwxt.nwpu.edu.cn/student/sso-login';
  static readonly ELECTRICITY_SSO: string =
    'https://yktapp.nwpu.edu.cn/berserker-auth/cas/login/supwisdom?targetUrl=https%3A%2F%2Fyktapp.nwpu.edu.cn%2Fplat';
  static readonly STUDENT_PORTRAIT: string = 'https://jwxt.nwpu.edu.cn/student/for-std/student-portrait';
  static readonly NETWORK_PORTAL: string = 'https://zizhu.nwpu.edu.cn:8900/home';
  static readonly NETWORK_HOST: string = 'zizhu.nwpu.edu.cn';
  static readonly DOMAIN: string = 'nwpu.edu.cn';
  static readonly PREF_NAME: string = 'campus_private';

  static readonly CALENDAR_ACCOUNT_NAME: string = 'AoxiangAssistant';
  static readonly CALENDAR_DISPLAY_NAME: string = '翱翔助手';

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
  static readonly KEY_NETWORK_BALANCE: string = 'network_balance';
  static readonly KEY_NETWORK_PACKAGE_NAME: string = 'network_package_name';
  static readonly KEY_NETWORK_PACKAGE_PRICE: string = 'network_package_price';
  static readonly KEY_NETWORK_LEAD_DAYS: string = 'network_lead_days';
  static readonly KEY_NETWORK_ALERT_ENABLED: string = 'network_alert_enabled';
  static readonly KEY_NETWORK_ALERT_ACTIVE: string = 'network_alert_active';
  static readonly KEY_NETWORK_UPDATED_AT: string = 'network_updated_at';
  static readonly KEY_NETWORK_CALENDAR_EVENT_ID: string = 'network_calendar_event_id';
  static readonly KEY_CREDENTIALS: string = 'login_credentials';
  static readonly KEY_CREDENTIALS_VERIFIED: string = 'credentials_verified';
  static readonly KEY_CREDENTIAL_FAILURE_COUNT: string = 'credential_failure_count';

  static readonly NOTIFICATION_ID_GRADE: number = 1001;
  static readonly NOTIFICATION_ID_ELECTRICITY: number = 1002;
  static readonly NOTIFICATION_ID_NETWORK: number = 1003;
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
