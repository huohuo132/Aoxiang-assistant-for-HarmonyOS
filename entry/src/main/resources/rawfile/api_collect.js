(function (mode) {
  const allowNavigation = __ALLOW_NAV__;
  const host = location.hostname;
  const path = location.pathname;
  const stateKey = "__aoxiangAssistantApiState_" + mode;

  const result = (phase, extra) => JSON.stringify(Object.assign({
    phase: phase,
    message: "",
    rows: [],
    cells: [],
    gpa: null,
    balance: NaN,
    packageName: "",
    packagePrice: NaN,
    complete: true
  }, extra || {}));
  const state = () => window[stateKey];
  const setState = (value) => {
    window[stateKey] = value;
    return value;
  };

  const FETCH_TIMEOUT_MS = 12000;

  const fetchResponse = async (url, options) => {
    const controller = typeof AbortController === "function" ? new AbortController() : null;
    const timer = controller ? setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS) : null;
    try {
      return await fetch(url, Object.assign({}, options || {}, {
        credentials: "include",
        cache: "no-store",
        signal: controller ? controller.signal : undefined
      }));
    } finally {
      if (timer) clearTimeout(timer);
    }
  };

  const fetchText = async (url) => {
    const response = await fetchResponse(url);
    if (!response.ok) throw new Error("HTTP " + response.status + " " + url);
    return response.text();
  };

  const fetchJson = async (url) => {
    const response = await fetchResponse(url, {
      headers: { Accept: "application/json" }
    });
    if (!response.ok) throw new Error("HTTP " + response.status + " " + url);
    return response.json();
  };

  const decodeJavascriptString = (value) => {
    const normalized = String(value || "").replace(/\\'/g, "'");
    return JSON.parse('"' + normalized + '"');
  };

  const extractSemesters = (html) => {
    const match = String(html || "").match(
      /(?:var|const|let)\s+semesters\s*=\s*JSON\.parse\(\s*'([\s\S]*?)'\s*\)/);
    if (!match) throw new Error("Semester data unavailable");
    const semesters = JSON.parse(decodeJavascriptString(match[1]));
    if (!Array.isArray(semesters) || !semesters.length) {
      throw new Error("No semester data");
    }
    return semesters;
  };

  const extractStudentId = (html) => {
    const source = String(html || "");
    const hidden = source.match(/id=["']studentId["'][^>]*value=["']([^"']+)["']/i) ||
      source.match(/value=["']([^"']+)["'][^>]*id=["']studentId["']/i);
    if (hidden && hidden[1]) return hidden[1];
    const variable = source.match(/(?:var|const|let)\s+studentId\s*=\s*["']?([^;"'\s]+)["']?\s*;/);
    return variable && variable[1] ? variable[1] : "";
  };

  const fetchStudentId = async () => {
    const studentInfo = await fetchJson("/student/for-std/student-portrait/getStdInfo");
    return String(studentInfo && studentInfo.student && studentInfo.student.id || "");
  };

  const firstNonEmpty = (values) => {
    for (const value of values) {
      const trimmed = String(value == null ? "" : value).trim();
      if (trimmed) return trimmed;
    }
    return "";
  };

  const cleanDetail = (raw) => {
    let value = String(raw == null ? "" : raw);
    for (let pass = 0; pass < 2; pass++) {
      value = value.replace(/&nbsp;/g, " ")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&#x27;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&");
      value = value.replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, " ");
    }
    return value.replace(/\\n/g, " ").replace(/\\r/g, " ").replace(/\s+/g, " ").trim();
  };

  const gradeRowFrom = (grade) => {
    if (!grade || grade.published === false) return null;
    const course = grade.course || {};
    const name = firstNonEmpty([course.nameZh, grade.lessonNameZh]);
    if (!name) return null;
    const rawPoint = grade.gp;
    const point = (rawPoint === null || rawPoint === undefined) ? null : Number(rawPoint);
    const gaGrade = (grade.gaGrade === null || grade.gaGrade === undefined) ? "" : String(grade.gaGrade);
    const detail = (grade.gradeDetail === null || grade.gradeDetail === undefined) ? "" : cleanDetail(grade.gradeDetail);
    return {
      course: name,
      credits: Number(course.credits) || 0,
      point: (point !== null && Number.isFinite(point)) ? point : null,
      grade: gaGrade,
      detail: detail
    };
  };

  const normalizeGrades = (responses) => {
    const rows = [];
    if (!Array.isArray(responses)) return rows;
    responses.forEach((response) => {
      const semesterGrades = response && response.semesterId2studentGrades;
      if (!semesterGrades) return;
      Object.keys(semesterGrades).forEach((semesterId) => {
        const grades = semesterGrades[semesterId];
        if (!Array.isArray(grades)) return;
        grades.forEach((grade) => {
          const row = gradeRowFrom(grade);
          if (row) rows.push(row);
        });
      });
    });
    return rows;
  };

  const GPA_KEYS = ["gpa", "avggpa", "averagegpa", "studentgpa", "cumulativegpa",
    "gradepointaverage", "averagegradepoint", "平均绩点", "平均学分绩点", "累计平均学分绩点"];

  const isGpaKey = (key) => {
    const normalized = String(key == null ? "" : key).replace(/[\s_\-]/g, "").toLowerCase();
    return GPA_KEYS.indexOf(normalized) >= 0;
  };

  const parseGpa = (raw) => {
    const match = String(raw == null ? "" : raw).match(/(?:^|[^0-9])(\d(?:\.\d{1,4})?)(?:[^0-9]|$)/);
    if (!match) return null;
    const value = Number.parseFloat(match[1]);
    return Number.isFinite(value) && value >= 0 && value <= 5 ? value : null;
  };

  const gpaFromObject = (object) => {
    if (!object || typeof object !== "object") return null;
    for (const key of Object.keys(object)) {
      if (isGpaKey(key)) {
        const value = parseGpa(object[key]);
        if (value !== null) return value;
      }
    }
    return null;
  };

  const findGpa = (value, depth) => {
    if (value === null || value === undefined || depth > 6) return null;
    if (Array.isArray(value)) {
      for (const item of value) {
        const found = findGpa(item, depth + 1);
        if (found !== null) return found;
      }
      return null;
    }
    if (typeof value !== "object") return null;
    const direct = gpaFromObject(value);
    if (direct !== null) return direct;
    for (const key of Object.keys(value)) {
      const found = findGpa(value[key], depth + 1);
      if (found !== null) return found;
    }
    return null;
  };

  const extractGpa = (response) => {
    const direct = gpaFromObject(response && response.stdGpaRankDto);
    if (direct !== null) return direct;
    return findGpa(response, 0);
  };

  const balanceFromInfo = (info) => {
    if (!info || typeof info !== "object") return null;
    const keys = ["当前剩余电量", "剩余电量", "电费余额", "剩余电费"];
    for (const key of keys) {
      if (!Object.prototype.hasOwnProperty.call(info, key)) continue;
      const match = String(info[key] == null ? "" : info[key]).match(/-?\d+(?:\.\d+)?/);
      const value = match ? Number.parseFloat(match[0]) : Number.NaN;
      if (Number.isFinite(value) && value >= 0 && value < 100000) return value;
    }
    return null;
  };

  const collectGrades = async () => {
    const sheetHtml = await fetchText("/student/for-std/grade/sheet/");
    const studentId = extractStudentId(sheetHtml) || await fetchStudentId();
    if (!studentId) throw new Error("Student id unavailable");
    const semesters = extractSemesters(sheetHtml);
    const gradeResponses = [];
    let failedSemesters = 0;
    for (let offset = 0; offset < semesters.length; offset += 4) {
      const batch = semesters.slice(offset, offset + 4).filter((semester) =>
        semester && semester.id);
      const responses = await Promise.all(batch.map(async (semester) => {
        try {
          return await fetchJson(
            "/student/for-std/grade/sheet/info/" + encodeURIComponent(studentId) +
            "?semester=" + encodeURIComponent(semester.id));
        } catch (ignored) {
          failedSemesters++;
          return null;
        }
      }));
      responses.forEach((response) => {
        if (response) gradeResponses.push(response);
      });
    }
    if (!gradeResponses.length) throw new Error("No grade response");
    let gpaResponse = null;
    try {
      gpaResponse = await fetchJson(
        "/student/for-std/student-portrait/getMyGpa?studentAssoc=" + encodeURIComponent(studentId));
    } catch (ignored) {}
    return {
      phase: "grades_result",
      message: "",
      rows: normalizeGrades(gradeResponses),
      cells: [],
      gpa: extractGpa(gpaResponse),
      balance: Number.NaN,
      complete: failedSemesters === 0
    };
  };

  const electricInfoFromVue = (rootVue) => {
    const queue = rootVue ? [rootVue] : [];
    const visited = new Set();
    while (queue.length && visited.size < 100) {
      const component = queue.shift();
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
        if (candidate && typeof candidate === "object" &&
            Object.prototype.hasOwnProperty.call(candidate, "当前剩余电量")) {
          return candidate;
        }
      }
      (component.$children || []).forEach((child) => queue.push(child));
    }
    return null;
  };

  const launch = (collector) => {
    const current = state();
    if (current && current.status === "done") return JSON.stringify(current.result);
    if (current && current.status === "error") {
      return result("target_error", { message: current.message || "接口读取失败" });
    }
    if (current && current.status === "loading") return result("api_waiting");
    const next = setState({ status: "loading", startedAt: Date.now() });
    collector().then((value) => {
      next.status = "done";
      next.result = value;
    }).catch((error) => {
      next.status = "error";
      next.message = String(error && error.message || error || "接口读取失败");
    });
    return result("api_waiting");
  };

  if (mode === "grades") {
    if (host !== "jwxt.nwpu.edu.cn") return result("api_unavailable");
    if (path === "/student/home" && allowNavigation) {
      location.replace(location.origin + "/student/for-std/grade/sheet/");
      return result("clicked", { message: "direct_api_grades" });
    }
    if (!path.includes("/student/for-std/grade/sheet")) return result("api_unavailable");
    return launch(collectGrades);
  }

  if (mode === "electricity") {
    if (host !== "yktapp.nwpu.edu.cn") return result("api_unavailable");
    if (path.startsWith("/plat")) {
      const token = new URL(location.href).searchParams.get("synjones-auth") ||
        sessionStorage.getItem("access_token") || "";
      if (token && allowNavigation) {
        const target = location.origin + "/jfdt/charge/feeitem/toAppitem" +
          "?feeitemid=182&synjones-auth=" + encodeURIComponent(token) +
          "&appId=36&loginFrom=h5&type=app";
        location.replace(target);
        return result("clicked", { message: "direct_electricity_api" });
      }
      return result("api_unavailable");
    }
    if (!path.startsWith("/jfdt/")) return result("api_unavailable");
    const app = document.querySelector("#app");
    const vue = app && app.__vue__;
    const info = electricInfoFromVue(vue);
    if (!info) return result("api_waiting");
    const balance = balanceFromInfo(info);
    return balance !== null
      ? result("electricity_result", { balance: balance })
      : result("api_waiting");
  }

  const text = (value) => String(value == null ? "" : value).replace(/\s+/g, " ").trim();

  const pageText = (root) => {
    const source = root && root.body ? root.body.innerText : "";
    return text(source);
  };

  // 只接受紧跟在标签后面的金额，且排除“50元包月不限量”这类套餐文案
  const amountAtHead = (raw) => {
    const source = String(raw == null ? "" : raw).replace(/,/g, "");
    const match = source.match(/^[\s:：¥￥]*(-?\d+(?:\.\d+)?)\s*(.*)$/);
    if (!match) return null;
    const value = Number.parseFloat(match[1]);
    if (!Number.isFinite(value) || value < 0 || value >= 1000000) return null;
    if (/^元\s*包/.test(match[2])) return null;
    return value;
  };

  const balanceFromDom = () => {
    const labels = ["账户总余额", "帐户总余额", "账户余额", "帐户余额", "账户金额", "可用余额",
      "剩余金额", "账户费用", "余额"];
    const nodes = document.querySelectorAll("td, th, dd, dt, span, div, p, li, label, b, strong, h1, h2, h3");
    for (const node of nodes) {
      const raw = text(node.innerText || node.textContent || "");
      if (!raw) continue;
      if (labels.indexOf(raw.replace(/[:：]\s*$/, "")) < 0) continue;
      const next = node.nextElementSibling;
      if (next) {
        const fromNext = amountAtHead(text(next.innerText || next.textContent || ""));
        if (fromNext !== null) return fromNext;
      }
      const parent = node.parentElement;
      if (parent) {
        const fromParent = amountAtHead(text(parent.innerText || parent.textContent || "").replace(raw, ""));
        if (fromParent !== null) return fromParent;
      }
    }
    return null;
  };

  const balanceFromText = (source) => {
    const keys = ["账户总余额", "帐户总余额", "账户余额", "帐户余额", "账户金额", "可用余额",
      "剩余金额", "余额"];
    for (const key of keys) {
      let from = 0;
      while (from < source.length) {
        const index = source.indexOf(key, from);
        if (index < 0) break;
        const value = amountAtHead(source.slice(index + key.length, index + key.length + 20));
        if (value !== null) return value;
        from = index + key.length;
      }
    }
    return null;
  };

  const packageFromText = (source) => {
    const match = source.match(/(\d{1,3})\s*元\s*包\s*(月不限量|月|(\d{1,4})\s*GB|(\d{1,4})\s*G)/i);
    if (!match) return null;
    const price = Number.parseFloat(match[1]);
    if (!Number.isFinite(price) || price <= 0) return null;
    const traffic = match[2].replace(/\s+/g, "");
    return { name: price + "元包" + traffic, price: price };
  };

  if (mode === "network") {
    if (host !== "zizhu.nwpu.edu.cn") return result("api_unavailable");
    const loginForm = document.querySelector("#login-form") ||
      document.querySelector('form[action="/login"]') ||
      document.querySelector('input[name="LoginForm[username]"]');
    if (loginForm) return result("network_login");
    const body = pageText(document);
    if (!body) return result("network_waiting");
    const balance = balanceFromDom();
    const resolved = balance !== null ? balance : balanceFromText(body);
    if (resolved === null) {
      const current = state();
      if (allowNavigation && path !== "/home" && !(current && current.redirected)) {
        setState({ redirected: true });
        location.replace(location.origin + "/home");
        return result("clicked", { message: "direct_network_home" });
      }
      return result("network_waiting");
    }
    const pkg = packageFromText(body);
    return result("network_result", {
      balance: resolved,
      packageName: pkg ? pkg.name : "",
      packagePrice: pkg ? pkg.price : NaN
    });
  }

  return result("api_unavailable");
})("__MODE__");
