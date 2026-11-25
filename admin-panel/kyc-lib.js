// Shared helpers for the KYC admin page. Plain script in the browser (window.KycLib),
// require-able from Node for tests.
(function (root, factory) {
  const lib = factory();
  if (typeof module === 'object' && module.exports) module.exports = lib;
  else root.KycLib = lib;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // --- DOM builder: never parses HTML ---------------------------------------

  const ATTRIBUTE_PROPS = new Set(['role', 'href', 'type', 'name', 'id', 'title']);
  const PROPERTY_PROPS = new Set(['className', 'value', 'disabled', 'hidden', 'checked']);

  const BLOCKED_TAGS = new Set(['script', 'object', 'embed']);
  const SAFE_SCHEMES = new Set(['http', 'https', 'mailto', 'tel', 'blob']);

  // Allowlist: relative URLs and a few schemes. Browsers strip tabs and newlines
  // inside a scheme, so those are removed before checking.
  const isSafeHref = (value) => {
    const href = String(value)
      .replace(/[\t\n\r]/g, '')
      .replace(/^[\u0000-\u0020]+/, '');
    const match = /^([^/?#:]*):/.exec(href);
    if (!match) return true;
    return SAFE_SCHEMES.has(match[1].toLowerCase());
  };

  const createEl = (doc) =>
    function el(tag, props, ...children) {
      if (BLOCKED_TAGS.has(String(tag).toLowerCase())) throw new Error(`Unsupported tag: ${tag}`);
      const node = doc.createElement(tag);
      for (const [key, value] of Object.entries(props || {})) {
        if (key === 'innerHTML' || key === 'outerHTML') {
          throw new Error(`Unsupported prop: ${key}`);
        }
        if (key === 'on') {
          for (const [type, fn] of Object.entries(value || {})) node.addEventListener(type, fn);
        } else if (key.startsWith('aria-') || key.startsWith('data-') || ATTRIBUTE_PROPS.has(key)) {
          if (key === 'href' && !isSafeHref(value)) throw new Error('Unsafe href');
          node.setAttribute(key, value);
        } else if (PROPERTY_PROPS.has(key)) {
          node[key] = value;
        } else {
          throw new Error(`Unsupported prop: ${key}`);
        }
      }
      for (const child of children.flat()) {
        if (child === null || child === undefined || child === false) continue;
        node.appendChild(typeof child === 'object' ? child : doc.createTextNode(String(child)));
      }
      return node;
    };

  const el = (...args) => createEl(document)(...args);

  // --- Status ----------------------------------------------------------------

  const STATUSES = {
    NOT_STARTED: ['Not started', 'neutral'],
    IN_PROGRESS: ['In progress', 'neutral'],
    PENDING_REVIEW: ['Under review', 'info'],
    APPROVED: ['Verified', 'success'],
    REQUIRES_CORRECTION: ['Needs a correction', 'warning'],
    EXPIRED: ['Expired', 'warning'],
    REJECTED: ['Not approved', 'danger'],
    RESTRICTED: ['Restricted', 'danger'],
  };

  const statusLabel = (code) => (STATUSES[code] ? STATUSES[code][0] : code ? String(code) : '');
  const statusTone = (code) => (STATUSES[code] ? STATUSES[code][1] : 'neutral');

  // --- Dates (local time) ----------------------------------------------------

  const toDate = (iso) => {
    if (iso === null || iso === undefined || iso === '') return null;
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? null : d;
  };

  const formatDate = (iso) => {
    const d = toDate(iso);
    if (!d) return '';
    return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }).format(d);
  };

  const formatDateTime = (iso) => {
    const d = toDate(iso);
    if (!d) return '';
    const parts = {};
    for (const p of new Intl.DateTimeFormat('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).formatToParts(d)) {
      parts[p.type] = p.value;
    }
    const hour = parts.hour === '24' ? '00' : parts.hour;
    return `${parts.day} ${parts.month} ${parts.year}, ${hour}:${parts.minute}`;
  };

  // --- Validation (mirrors backend/kyc/routes/kyc_admin.routes.js) -------------

  const REASON_ERROR = 'Give a reason between 5 and 500 characters.';
  const EXEMPTION_ERROR = 'Choose a date within the next 90 days.';
  const DAY_MS = 86400000;
  const MAX_EXEMPTION_DAYS = 90;

  const validateReason = (text) => {
    if (typeof text !== 'string') return { ok: false, value: null, error: REASON_ERROR };
    let value = text.trim();
    if (value.endsWith('.')) value = value.slice(0, -1).trim();
    if (value.length < 5 || value.length > 500) return { ok: false, value: null, error: REASON_ERROR };
    return { ok: true, value, error: null };
  };

  const validateExemption = ({ until, reason } = {}, now = new Date()) => {
    const errors = {};
    const when = typeof until === 'string' || until instanceof Date ? new Date(until) : null;
    const t = when ? when.getTime() : NaN;
    const start = now.getTime();
    if (Number.isNaN(t) || t <= start || t > start + MAX_EXEMPTION_DAYS * DAY_MS) {
      errors.until = EXEMPTION_ERROR;
    }
    const r = validateReason(reason);
    if (!r.ok) errors.reason = r.error;
    return { ok: Object.keys(errors).length === 0, reason: r.value, errors };
  };

  const DAY_FIELDS = [
    'firstNudgeDays',
    'secondNudgeDays',
    'reminderIntervalDays',
    'warningBeforeDays',
    'enforcementDays',
    'resubmitGraceDays',
  ];

  const validateSettings = (s) => {
    const errors = {};
    const settings = s || {};
    for (const f of DAY_FIELDS) {
      if (!Number.isInteger(settings[f]) || settings[f] < 1 || settings[f] > 365) {
        errors[f] = 'Enter a whole number from 1 to 365.';
      }
    }
    if (typeof settings.remindersEnabled !== 'boolean') {
      errors.remindersEnabled = 'Choose on or off.';
    }
    if (!errors.secondNudgeDays && !errors.firstNudgeDays && settings.secondNudgeDays <= settings.firstNudgeDays) {
      errors.secondNudgeDays = 'The second nudge must come after the first.';
    }
    if (!errors.warningBeforeDays && !errors.enforcementDays && settings.warningBeforeDays >= settings.enforcementDays) {
      errors.warningBeforeDays = 'The warning must come before the enforcement deadline.';
    }
    if (!errors.resubmitGraceDays && !errors.warningBeforeDays && settings.resubmitGraceDays <= settings.warningBeforeDays) {
      errors.resubmitGraceDays = 'The resubmission grace period must be longer than the warning period.';
    }
    return { ok: Object.keys(errors).length === 0, errors };
  };

  // --- API client ------------------------------------------------------------

  class ApiError extends Error {
    constructor(status, message) {
      super(message);
      this.name = 'ApiError';
      this.status = status;
    }
  }

  const GENERIC_ERROR = 'Something went wrong. Please try again.';
  const SESSION_ERROR = 'Your session ended. Sign in again.';
  const NETWORK_ERROR = 'No connection. Check your internet and try again.';

  const parseJson = (text) => {
    if (!text) return null;
    try {
      return JSON.parse(text);
    } catch (err) {
      return undefined;
    }
  };

  const createApi = ({ baseUrl, getToken, onUnauthorized, fetchImpl }) => {
    const doFetch = fetchImpl || ((...args) => fetch(...args));

    let notified = false;
    const unauthorized = () => {
      if (!notified) {
        notified = true;
        if (onUnauthorized) onUnauthorized();
      }
      return new ApiError(401, SESSION_ERROR);
    };

    const send = async (method, path, { body, signal } = {}) => {
      const token = getToken();
      if (!token) throw unauthorized();
      const headers = { Authorization: `Bearer ${token}` };
      const init = { method, headers };
      if (body !== undefined) {
        headers['Content-Type'] = 'application/json';
        init.body = JSON.stringify(body);
      }
      if (signal) init.signal = signal;
      let res;
      try {
        res = await doFetch(`${baseUrl}${path}`, init);
      } catch (err) {
        if (err && err.name === 'AbortError') throw err;
        throw new ApiError(0, NETWORK_ERROR);
      }
      if (res.status === 401) throw unauthorized();
      return res;
    };

    const failure = async (res) => {
      let message = GENERIC_ERROR;
      try {
        const data = parseJson(await res.text());
        if (data && typeof data.message === 'string' && data.message) message = data.message;
      } catch (err) {
        // keep the generic message
      }
      return new ApiError(res.status, message);
    };

    const json = async (method, path, opts) => {
      const res = await send(method, path, opts);
      if (!res.ok) throw await failure(res);
      if (res.status === 204) return null;
      const data = parseJson(await res.text());
      if (data === undefined) throw new ApiError(res.status, GENERIC_ERROR);
      return data;
    };

    return {
      get: (path, { signal } = {}) => json('GET', path, { signal }),
      post: (path, body) => json('POST', path, { body: body === undefined ? {} : body }),
      put: (path, body) => json('PUT', path, { body: body === undefined ? {} : body }),
      blob: async (path, { signal } = {}) => {
        const res = await send('GET', path, { signal });
        if (!res.ok) throw await failure(res);
        return res.blob();
      },
    };
  };

  // --- Session ---------------------------------------------------------------

  const currentRole = () => {
    try {
      const user = JSON.parse(localStorage.getItem('user'));
      return user && typeof user.role === 'string' ? user.role : null;
    } catch (err) {
      return null;
    }
  };

  return {
    el,
    createEl,
    statusLabel,
    statusTone,
    formatDate,
    formatDateTime,
    validateReason,
    validateExemption,
    validateSettings,
    ApiError,
    createApi,
    currentRole,
  };
});
