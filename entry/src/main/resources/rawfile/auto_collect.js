(function (mode) {
  const allowNavigation = __ALLOW_NAV__;
  const username = __USERNAME__;
  const password = __PASSWORD__;
  const smsCode = __SMS_CODE__;
  const canAutofill = __CAN_AUTOFILL__;
  const canFillSms = __CAN_FILL_SMS__;
  const unifiedAuthExited = __AUTH_EXITED__;
  const headless = __HEADLESS__;
  const collectionMode = mode === "grades" || mode === "electricity";

  const result = (phase, extra) => JSON.stringify(Object.assign({
    phase: phase,
    message: "",
    rows: [],
    cells: [],
    gpa: null,
    balance: Number.NaN,
    complete: true
  }, extra || {}));

  const text = (value) => String(value == null ? "" : value).replace(/\s+/g, " ").trim();
  const visible = (element) => {
    try {
      if (headless) {
        for (let current = element; current; current = current.parentElement) {
          const currentStyle = getComputedStyle(current);
          if (currentStyle.display === "none" || currentStyle.visibility === "hidden") return false;
        }
        return true;
      }
      const style = getComputedStyle(element);
      return style.display !== "none" && style.visibility !== "hidden" && element.getClientRects().length > 0;
    } catch (ignored) {
      return false;
    }
  };

  const documents = [];
  const collectDocuments = (currentWindow) => {
    try {
      const currentDocument = currentWindow.document;
      if (!currentDocument || documents.includes(currentDocument)) return;
      documents.push(currentDocument);
      [...currentDocument.querySelectorAll("iframe")].forEach((frame) => {
        try {
          if (frame.contentWindow && frame.contentDocument) collectDocuments(frame.contentWindow);
        } catch (ignored) {}
      });
    } catch (ignored) {}
  };
  collectDocuments(window);

  const body = text(documents.map((doc) => (doc.body ? doc.body.innerText : "")).join(" "));
  const host = location.hostname;
  const sessionError = /登录信息已失效|登录状态已失效|会话.{0,8}(?:失效|过期)|身份认证已过期/.test(body);

  if ((mode === "validate" || mode === "bootstrap") && unifiedAuthExited) {
    return result("credentials_valid");
  }

  const interactiveVerificationVisible = host === "uis.nwpu.edu.cn" && (
    /当前登录环境异常|安全验证|手机验证码|短信验证码|动态验证码|确认是本人|发送验证请求/.test(body) ||
    documents.some((doc) => [...doc.querySelectorAll(
      '.sw-cas-safe-pop, .van-popup, [class*="mfa" i], [class*="guard" i]'
    )].some((element) => visible(element) &&
      /安全验证|登录环境异常|确认是本人|验证方式|发送验证/.test(text(element.innerText || element.textContent))))
  );
  if (collectionMode && interactiveVerificationVisible) {
    return result("interactive_login");
  }

  const setValue = (input, value) => {
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    setter.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
    input.dispatchEvent(new Event("blur", { bubbles: true }));
  };

  const clickElement = (element) => {
    try {
      element.scrollIntoView({ block: "center", inline: "center" });
    } catch (ignored) {}
    try {
      element.click();
      return true;
    } catch (ignored) {}
    try {
      element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
      return true;
    } catch (ignored) {}
    return false;
  };

  const findButton = (doc, pattern) => [...doc.querySelectorAll("button, input[type=submit], input[type=button]")]
    .find((element) => visible(element) && pattern.test(text(element.innerText || element.value)));

  const clickLeaf = (patterns) => {
    for (const pattern of patterns) {
      for (const doc of documents) {
        const leaf = [...doc.querySelectorAll("a, button, [role=button], li, body *")].find((candidate) =>
          candidate.children.length === 0 &&
          pattern.test(text(candidate.innerText || candidate.textContent || candidate.value || "")));
        if (!leaf) continue;
        const target = leaf.closest("a, button, [role=button], li, .menu-item, .van-grid-item__content, .van-grid-item, .weui-grid") || leaf;
        if (clickElement(target)) return text(leaf.innerText || leaf.textContent || leaf.value || "");
      }
    }
    return "";
  };

  if (mode === "electricity" && host === "yktapp.nwpu.edu.cn" && allowNavigation) {
    if (location.pathname.startsWith("/plat") && location.pathname !== "/plat/login" &&
        /账户余额/.test(body) && !/(?:^|\s)请登录(?:\s|$)/.test(body)) {
      const auth = new URL(location.href).searchParams.get("synjones-auth");
      if (auth) {
        const redirect = "https://yktapp.nwpu.edu.cn/berserker-base/redirect" +
          "?appId=36&type=app&synjones-auth=" + encodeURIComponent(auth) + "&loginFrom=h5";
        location.replace(redirect);
      }
      return result("clicked", { message: "electricity_page" });
    }
    const clicked = clickLeaf([/统一身份认证/, /^统一登录$/, /^更多登录方式$/]);
    if (clicked) return result("clicked", { message: clicked });
  }

  const loginDocument = documents.find((doc) => {
    const documentText = text(doc.body ? doc.body.innerText : "");
    const visiblePassword = [...doc.querySelectorAll('input[type="password"]')].some(visible);
    const visibleInput = [...doc.querySelectorAll("input")].some(visible);
    const authLocation = host !== "jwxt.nwpu.edu.cn" || /login|auth|cas/i.test(location.pathname);
    const authContent = /账号密码|密码登录|统一身份认证|统一认证|请输入.{0,12}(?:账号|用户名|学号|密码)/.test(documentText);
    return visiblePassword && (authLocation || authContent) || visibleInput && authContent;
  });
  const protectedStudentPage = host === "jwxt.nwpu.edu.cn" &&
    /^\/student(?:\/|$)/.test(location.pathname) &&
    !/\/(?:sso-?login|login|logout|error|unauthorized|forbidden)(?:\/|$)/i.test(location.pathname) &&
    !loginDocument && body.length > 0 &&
    !/(?:请先登录|登录信息已失效|会话.{0,8}(?:失效|过期)|身份认证已过期)/.test(body);

  if ((mode === "validate" || mode === "bootstrap") && protectedStudentPage) {
    return result("credentials_valid");
  }

  if (loginDocument && !(mode === "electricity" && host === "yktapp.nwpu.edu.cn")) {
    if (mode === "bootstrap") {
      return result("interactive_login");
    }
    const loginBody = text(loginDocument.body ? loginDocument.body.innerText : "");
    const passwordTab = [...loginDocument.querySelectorAll("body *")].find((element) =>
      element.children.length === 0 && visible(element) && /^(账号密码|密码登录|User-Password)$/i.test(text(element.innerText)));
    if (passwordTab) clickElement(passwordTab);
    const passwordInput = [...loginDocument.querySelectorAll('input[type="password"]')].find(visible);
    const smsField = [...loginDocument.querySelectorAll("input")].find((input) => {
      const descriptor = text([input.name, input.id, input.placeholder, input.type].join(" "));
      return visible(input) && input !== passwordInput && /sms|message|verify|code|验证码|动态码/.test(descriptor);
    });
    const feedback = text([...loginDocument.querySelectorAll(
      '[role="alert"], [aria-live], .error, .error-message, .el-message__content, .ant-message-notice-content, [class*="error" i]'
    )].filter(visible).map((element) => element.innerText || element.textContent || element.value).join(" "));
    const authText = text([loginBody, feedback, passwordInput && passwordInput.validationMessage].join(" "));
    const asksForSms = /短信|手机验证码|动态验证码/.test(loginBody) && smsField;
    if (/(?:验证码|动态码|校验码).{0,8}(?:错误|有误|不正确|无效|已失效|失败)|invalid.{0,8}(?:captcha|verification|sms).{0,8}code/i.test(authText)) {
      return result("sms_error");
    }
    if (asksForSms) {
      if (collectionMode) {
        return result("interactive_login");
      }
      if (canFillSms && smsCode) {
        setValue(smsField, smsCode);
        const submit = findButton(loginDocument, /验证|确认|提交|登录/);
        if (submit) clickElement(submit);
        return result("sms_submitting");
      }
      return result("sms_required");
    }
    const invalidPasswordField = passwordInput && !canAutofill &&
      (passwordInput.getAttribute("aria-invalid") === "true" || /(?:^|\s)(?:error|invalid)(?:\s|$)/i.test(passwordInput.className || ""));
    if (invalidPasswordField ||
        /(?:账号|账户|用户名|用户|学号).{0,12}(?:或|和|\/)?\s*密码.{0,12}(?:错误|有误|不正确|无效|失败)|密码.{0,12}(?:错误|有误|不正确|无效)|(?:错误|无效)的?(?:账号|账户|用户名|用户|学号|密码)|(?:账号|账户|用户名|用户|学号).{0,8}(?:不存在|未注册)|登录失败|认证失败|凭据.{0,8}(?:错误|有误|无效)|invalid.{0,12}(?:username|account|password|credential)|incorrect.{0,12}(?:username|account|password|credential)|bad credentials|authentication failed|credentials you provided.{0,24}authentic|unable to log you in/i.test(authText)) {
      return result("credentials_error");
    }
    const usernameInput = [...loginDocument.querySelectorAll('input[name="username"], #username, input[type="text"], input[type="tel"], input[type="email"]')]
      .find((input) => visible(input) && input !== passwordInput);
    if (canAutofill && username && password && usernameInput && passwordInput) {
      setValue(usernameInput, username);
      setValue(passwordInput, password);
      const submit = findButton(loginDocument, /登录|login|提交/i);
      if (submit) clickElement(submit);
      return result("credentials_submitting");
    }
    if (!canAutofill && usernameInput && passwordInput) {
      return result("credentials_pending");
    }
    return result("credentials_required");
  }

  if ((mode === "validate" || mode === "bootstrap") && host === "jwxt.nwpu.edu.cn"
      && sessionError) {
    return result("credentials_required");
  }

  if ((mode === "validate" || mode === "bootstrap") && host === "jwxt.nwpu.edu.cn") {
    if (location.pathname.includes("sso-login")) {
      window.__aoxiangAssistantSsoArrivedAt = window.__aoxiangAssistantSsoArrivedAt || Date.now();
      if (Date.now() - window.__aoxiangAssistantSsoArrivedAt < 4000 || !allowNavigation) {
        return result("page");
      }
    }
    if (allowNavigation) {
      location.replace(location.origin + "/student/home");
      return result("clicked", { message: "education_home" });
    }
  }

  if (mode === "grades" && host === "jwxt.nwpu.edu.cn") {
    const directPath = "/student/for-std/grade/sheet/";
    const directAttemptsKey = "campus_direct_attempts_" + mode;
    if (location.pathname === "/student/home") {
      const attempts = Number.parseInt(sessionStorage.getItem(directAttemptsKey) || "0", 10);
      if (attempts >= 3) {
        return result("target_error", { message: "接口读取失败" });
      }
      if (!allowNavigation) return result("page");
      sessionStorage.setItem(directAttemptsKey, String(attempts + 1));
      location.replace(location.origin + directPath);
      return result("clicked", { message: "direct_" + mode });
    }
  }

  if (mode === "electricity") {
    const onElectricityPage = host === "yktapp.nwpu.edu.cn" && location.pathname.startsWith("/jfdt/");
    if (onElectricityPage) {
      const parseElectricityValue = (value) => {
        const match = String(value == null ? "" : value).match(/-?\d+(?:\.\d+)?/);
        const parsed = match ? Number.parseFloat(match[0]) : Number.NaN;
        return Number.isFinite(parsed) && parsed >= 0 && parsed < 100000 ? parsed : null;
      };
      const electricityLabels = [
        "剩余电费", "电费余额", "剩余金额", "当前剩余电量", "剩余电量", "电量余额"
      ];
      const valueFromInfo = (info) => {
        if (!info || typeof info !== "object") return null;
        for (const label of electricityLabels) {
          if (!Object.prototype.hasOwnProperty.call(info, label)) continue;
          const parsed = parseElectricityValue(info[label]);
          if (parsed !== null) return parsed;
        }
        for (const entry of Object.entries(info)) {
          const label = entry[0];
          if (!/(?:剩余.*(?:电费|金额|电量)|(?:电费|电量).*余额)/.test(text(label))) continue;
          const parsed = parseElectricityValue(entry[1]);
          if (parsed !== null) return parsed;
        }
        return null;
      };

      const app = document.querySelector("#app");
      const rootVue = app && app.__vue__;
      const components = rootVue ? [rootVue] : [];
      const visited = new Set();
      while (components.length) {
        const component = components.shift();
        if (!component || visited.has(component)) continue;
        visited.add(component);
        const data = component.$data || {};
        const candidates = [
          component.aboutEleric && component.aboutEleric.electricInfo,
          data.aboutEleric && data.aboutEleric.electricInfo,
          component.electricInfo,
          data.electricInfo
        ];
        for (const candidate of candidates) {
          const balance = valueFromInfo(candidate);
          if (balance !== null) return result("electricity_result", { balance: balance });
        }
        (component.$children || []).forEach((child) => components.push(child));
      }

      const electricityContexts = documents.flatMap((doc) => [...doc.querySelectorAll("body *")])
        .filter((element) => {
          const own = text(element.innerText || element.textContent);
          return own.length > 0 && own.length < 240 &&
            /(?:剩余电费|电费余额|剩余金额|当前剩余电量|剩余电量|电量余额)/.test(own) &&
            /\d+(?:\.\d+)?/.test(own);
        });
      for (const element of electricityContexts) {
        const compact = text(element.innerText || element.textContent);
        const direct = compact.match(/(?:当前剩余电量|剩余电量|电量余额)\s*[：:]\s*(-?\d+(?:\.\d+)?)/) ||
          compact.match(/(?:剩余电费|电费余额|剩余金额)\s*[：:]?\s*(?:¥|￥)?\s*(-?\d+(?:\.\d+)?)\s*元/) ||
          compact.match(/(?:¥|￥)?\s*(-?\d+(?:\.\d+)?)\s*(?:元|度)\s*[：:]?\s*(?:剩余电费|电费余额|剩余金额|当前剩余电量|剩余电量|电量余额)/);
        if (direct) {
          const balance = Number.parseFloat(direct[1]);
          if (Number.isFinite(balance) && balance >= 0 && balance < 100000) {
            return result("electricity_result", { balance: balance });
          }
        }
      }
    }

    return result("waiting");
  }

  const onPortraitPage = host === "jwxt.nwpu.edu.cn" && documents.some((doc) =>
    doc.location && doc.location.pathname.includes("/for-std/student-portrait"));
  if (mode === "grades" && onPortraitPage) {
    const parseGpaNumber = (value) => {
      const match = String(value == null ? "" : value).match(/(?:^|[^\d])(\d(?:\.\d{1,4})?)(?:[^\d]|$)/);
      if (!match) return null;
      const parsed = Number.parseFloat(match[1]);
      return Number.isFinite(parsed) && parsed >= 0 && parsed <= 5 ? parsed : null;
    };
    for (const doc of documents) {
      const scoreItems = [...doc.querySelectorAll(".myScore .score-item, .myScore .score-info, .score-content > li")];
      for (const item of scoreItems) {
        const compact = text(item.innerText || item.textContent);
        const match = compact.match(/(\d(?:\.\d{1,4})?)\s*个人\s*GPA/i);
        const gpa = match ? parseGpaNumber(match[1]) : null;
        if (gpa !== null) return result("portrait_data", { gpa: gpa });
      }
    }

    const gpaLabel = /(?:累计|总)?平均(?:学分)?绩点|GPA/i;
    for (const doc of documents) {
      const leaves = [...doc.querySelectorAll("body *")].filter((element) =>
        element.children.length === 0 && gpaLabel.test(text(element.innerText || element.textContent)));
      for (const leaf of leaves) {
        const own = text(leaf.innerText || leaf.textContent);
        const next = text(leaf.nextElementSibling &&
          (leaf.nextElementSibling.innerText || leaf.nextElementSibling.textContent));
        const parent = text(leaf.parentElement &&
          (leaf.parentElement.innerText || leaf.parentElement.textContent));
        const explicit = [own, own + " " + next, parent];
        for (const value of explicit) {
          const match = value.match(/(?:(?:累计|总)?平均(?:学分)?绩点|GPA)\s*[：:]?\s*(\d(?:\.\d{1,4})?)/i);
          const gpa = match ? parseGpaNumber(match[1]) : null;
          if (gpa !== null) return result("portrait_data", { gpa: gpa });
        }
        if (/^(?:(?:累计|总)?平均(?:学分)?绩点|GPA)$/i.test(own)) {
          const gpa = parseGpaNumber(next);
          if (gpa !== null) return result("portrait_data", { gpa: gpa });
        }
      }
    }

    const app = document.querySelector("#app");
    const rootVue = app && app.__vue__;
    const queue = rootVue ? [{ value: rootVue.$data, depth: 0 }] : [];
    const visited = new Set();
    const gpaKey = /^(?:gpa|avgGpa|averageGpa|gradePointAverage|averageGradePoint|平均(?:学分)?绩点)$/i;
    while (queue.length && visited.size < 250) {
      const current = queue.shift();
      const value = current.value;
      if (!value || typeof value !== "object" || visited.has(value) || current.depth > 5 ||
          (typeof Node !== "undefined" && value instanceof Node)) continue;
      visited.add(value);
      let entries = [];
      try {
        entries = Object.entries(value);
      } catch (ignored) {}
      for (const entry of entries) {
        const key = entry[0];
        const child = entry[1];
        if (key.startsWith("$") || key.startsWith("_")) continue;
        if (gpaKey.test(key)) {
          const gpa = parseGpaNumber(child && typeof child === "object"
            ? child.value || child.data || child.text : child);
          if (gpa !== null) return result("portrait_data", { gpa: gpa });
        }
        if (child && typeof child === "object") queue.push({ value: child, depth: current.depth + 1 });
      }
    }
    return result("portrait_page");
  }

  const tables = documents.flatMap((doc) => [...doc.querySelectorAll("table")]).map((table) => {
    const headers = [...table.querySelectorAll("thead th")].map((cell) => text(cell.innerText));
    if (!headers.length) {
      table.querySelectorAll("tr:first-child th").forEach((cell) => headers.push(text(cell.innerText)));
    }
    const bodyRows = table.querySelectorAll("tbody tr");
    const sourceRows = bodyRows.length ? bodyRows : table.querySelectorAll("tr");
    const rows = [...sourceRows].map((row) => {
      const cells = [...row.querySelectorAll("td")].map((cell) => text(cell.innerText));
      const courseName = row.querySelector(".course-name");
      if (courseName && cells.length) cells[0] = text(courseName.innerText);
      return cells;
    }).filter((row) => row.length && row.some(Boolean));
    return { headers: headers, rows: rows };
  }).filter((table) => table.rows.length);

  const gradeRows = [];
  tables.forEach((table) => table.rows.forEach((row) => {
    const credit = Number.parseFloat(row[1]);
    const point = Number.parseFloat(row[2]);
    const score = Number.parseFloat(row[3]);
    const passFail = /^(P|NP|通过|不通过|优秀|良好|中等|及格|不及格)$/i.test(row[3] || "");
    if (row.length >= 4 && row[0] && Number.isFinite(credit) &&
        (Number.isFinite(point) || Number.isFinite(score) || passFail)) {
      gradeRows.push(row);
    }
  }));

  const onGradePage = host === "jwxt.nwpu.edu.cn" && documents.some((doc) =>
    (doc.location && doc.location.pathname.includes("/for-std/grade/sheet")) ||
    text(doc.body ? doc.body.innerText : "").includes("学生成绩"));
  if (onGradePage && gradeRows.length) return result("grades_table", { cells: gradeRows });
  if (onGradePage) return result("page");

  return result("waiting");
})("__MODE__");
