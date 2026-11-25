const lib = require('../../admin-panel/kyc-lib');

const makeFakeDocument = () => {
  const node = (props) => ({
    attributes: {},
    listeners: {},
    children: [],
    ...props,
    setAttribute(k, v) {
      this.attributes[k] = String(v);
    },
    addEventListener(type, fn) {
      this.listeners[type] = fn;
    },
    appendChild(c) {
      this.children.push(c);
      return c;
    },
  });
  return {
    createElement: (tag) => node({ nodeType: 1, tag }),
    createTextNode: (text) => ({ nodeType: 3, textContent: String(text) }),
  };
};

describe('el', () => {
  let el;
  beforeEach(() => {
    el = lib.createEl(makeFakeDocument());
  });

  test('turns markup-looking strings into text nodes, never parsed', () => {
    const evil = '<img src=x onerror=alert(1)>';
    const node = el('div', null, evil);
    expect(node.children).toHaveLength(1);
    expect(node.children[0].nodeType).toBe(3);
    expect(node.children[0].textContent).toBe(evil);
    expect(node.innerHTML).toBeUndefined();
  });

  test('keeps Node children as they are', () => {
    const inner = el('span');
    const node = el('div', {}, inner, 'x');
    expect(node.children[0]).toBe(inner);
    expect(node.children[1].textContent).toBe('x');
  });

  test('sets attributes and properties', () => {
    const fn = () => {};
    const node = el('button', {
      className: 'btn',
      id: 'a',
      type: 'button',
      name: 'n',
      title: 't',
      role: 'dialog',
      'aria-label': 'Close',
      'data-id': 7,
      value: 'v',
      disabled: true,
      hidden: false,
      on: { click: fn },
    });
    expect(node.className).toBe('btn');
    expect(node.value).toBe('v');
    expect(node.disabled).toBe(true);
    expect(node.hidden).toBe(false);
    expect(node.attributes).toMatchObject({
      id: 'a',
      type: 'button',
      name: 'n',
      title: 't',
      role: 'dialog',
      'aria-label': 'Close',
      'data-id': '7',
    });
    expect(node.listeners.click).toBe(fn);
  });

  test('sets form and table attributes used by the KYC page', () => {
    const node = el('input', {
      for: 'q',
      autocomplete: 'off',
      inputmode: 'search',
      spellcheck: 'false',
      scope: 'col',
      tabindex: -1,
      maxLength: 64,
    });
    expect(node.maxLength).toBe(64);
    expect(node.attributes).toMatchObject({
      for: 'q',
      autocomplete: 'off',
      inputmode: 'search',
      spellcheck: 'false',
      scope: 'col',
      tabindex: '-1',
    });
  });

  test('throws for innerHTML, outerHTML and unknown props', () => {
    expect(() => el('div', { innerHTML: '<b>x</b>' })).toThrow();
    expect(() => el('div', { outerHTML: '<b>x</b>' })).toThrow();
    expect(() => el('div', { onclick: () => {} })).toThrow('Unsupported prop: onclick');
  });

  test('rejects unsafe hrefs', () => {
    const bad = [
      'javascript:alert(1)',
      ' JavaScript:alert(1)',
      'JAVASCRIPT:alert(1)',
      'java\tscript:alert(1)',
      'java\nscript:alert(1)',
      'java\rscript:alert(1)',
      '\u0001\u0002javascript:alert(1)',
      'data:text/html,<script>1</script>',
      'vbscript:msgbox(1)',
      'file:///etc/passwd',
    ];
    for (const href of bad) expect(() => el('a', { href })).toThrow('Unsafe href');
  });

  test('accepts relative and allowlisted scheme hrefs', () => {
    const ok = ['/x', 'x.html', '?q=1', '#top', './a:b', 'http://a.b', 'HTTPS://a.b', 'mailto:a@b.c', 'tel:+263', 'blob:http://x/1'];
    for (const href of ok) expect(el('a', { href }).attributes.href).toBe(href);
  });

  test('rejects script, object and embed tags but allows iframe', () => {
    for (const t of ['script', 'object', 'embed']) {
      expect(() => el(t)).toThrow(`Unsupported tag: ${t}`);
    }
    expect(el('iframe').tag).toBe('iframe');
  });

  test('skips null, undefined and false children', () => {
    const node = el('div', null, null, false, undefined, 'a');
    expect(node.children).toHaveLength(1);
  });
});

describe('status helpers', () => {
  const cases = {
    NOT_STARTED: ['Not started', 'neutral'],
    IN_PROGRESS: ['In progress', 'neutral'],
    PENDING_REVIEW: ['Under review', 'info'],
    APPROVED: ['Verified', 'success'],
    REQUIRES_CORRECTION: ['Needs a correction', 'warning'],
    EXPIRED: ['Expired', 'warning'],
    REJECTED: ['Not approved', 'danger'],
    RESTRICTED: ['Restricted', 'danger'],
  };
  test.each(Object.entries(cases))('%s', (code, [label, tone]) => {
    expect(lib.statusLabel(code)).toBe(label);
    expect(lib.statusTone(code)).toBe(tone);
  });
  test('unknown codes fall back', () => {
    expect(lib.statusTone('WHAT')).toBe('neutral');
    expect(lib.statusLabel('WHAT')).toBe('WHAT');
    expect(lib.statusLabel(null)).toBe('');
  });
});

describe('dates', () => {
  test('empty for null and invalid', () => {
    for (const f of [lib.formatDate, lib.formatDateTime]) {
      expect(f(null)).toBe('');
      expect(f(undefined)).toBe('');
      expect(f('')).toBe('');
      expect(f('not a date')).toBe('');
    }
  });
  test('formats in local time', () => {
    const pad = (n) => String(n).padStart(2, '0');
    const local = (d) => `${d.getHours() === 24 ? '00' : pad(d.getHours())}:${pad(d.getMinutes())}`;
    const d = new Date(2026, 10, 5, 9, 5);
    expect(lib.formatDate(d.toISOString())).toBe('5 November 2026');
    expect(lib.formatDateTime(d.toISOString())).toBe(`5 Nov 2026, ${local(d)}`);
    expect(lib.formatDateTime(d.toISOString())).toBe('5 Nov 2026, 09:05');
    const midnight = new Date(2026, 10, 5, 0, 5);
    expect(lib.formatDateTime(midnight.toISOString())).toBe('5 Nov 2026, 00:05');
  });
});

describe('validateReason', () => {
  test('trims and strips one trailing full stop', () => {
    expect(lib.validateReason('  Blurry photo.  ')).toEqual({ ok: true, value: 'Blurry photo', error: null });
    expect(lib.validateReason('Blurry photo..').value).toBe('Blurry photo.');
  });
  test('bounds', () => {
    const msg = 'Give a reason between 5 and 500 characters.';
    expect(lib.validateReason('abcd')).toEqual({ ok: false, value: null, error: msg });
    expect(lib.validateReason('abcd.').ok).toBe(false);
    expect(lib.validateReason('abcde').ok).toBe(true);
    expect(lib.validateReason('a'.repeat(500)).ok).toBe(true);
    expect(lib.validateReason('a'.repeat(501)).ok).toBe(false);
    expect(lib.validateReason(null).ok).toBe(false);
    expect(lib.validateReason(12345).ok).toBe(false);
  });
});

describe('validateExemption', () => {
  const now = new Date('2026-11-25T12:00:00Z');
  const day = 86400000;
  const msg = 'Choose a date within the next 90 days.';
  const reason = 'Travelling abroad';
  test('accepts a future date within 90 days, inclusive at 90', () => {
    const r = lib.validateExemption({ until: new Date(now.getTime() + 90 * day).toISOString(), reason }, now);
    expect(r.ok).toBe(true);
    expect(r.reason).toBe(reason);
  });
  test('rejects past, now, beyond 90 days, invalid', () => {
    for (const until of [
      new Date(now.getTime() - 1).toISOString(),
      now.toISOString(),
      new Date(now.getTime() + 90 * day + 1).toISOString(),
      'garbage',
      '',
      null,
    ]) {
      const r = lib.validateExemption({ until, reason }, now);
      expect(r.ok).toBe(false);
      expect(r.errors.until).toBe(msg);
    }
  });
  test('reason error', () => {
    const r = lib.validateExemption({ until: new Date(now.getTime() + day).toISOString(), reason: 'no' }, now);
    expect(r.ok).toBe(false);
    expect(r.errors.reason).toBe('Give a reason between 5 and 500 characters.');
    expect(r.errors.until).toBeUndefined();
  });
});

describe('validateSettings', () => {
  const good = {
    firstNudgeDays: 3,
    secondNudgeDays: 7,
    reminderIntervalDays: 7,
    warningBeforeDays: 7,
    enforcementDays: 30,
    resubmitGraceDays: 14,
    remindersEnabled: true,
  };
  test('valid', () => {
    expect(lib.validateSettings(good)).toEqual({ ok: true, errors: {} });
  });
  test.each([0, 366, 1.5, '3', null])('day field out of range: %p', (v) => {
    const r = lib.validateSettings({ ...good, reminderIntervalDays: v });
    expect(r.ok).toBe(false);
    expect(Object.keys(r.errors)).toEqual(['reminderIntervalDays']);
  });
  test('remindersEnabled must be boolean', () => {
    const r = lib.validateSettings({ ...good, remindersEnabled: 'yes' });
    expect(Object.keys(r.errors)).toEqual(['remindersEnabled']);
  });
  test('second nudge after first', () => {
    const r = lib.validateSettings({ ...good, secondNudgeDays: 3 });
    expect(r.errors.secondNudgeDays).toBe('The second nudge must come after the first.');
  });
  test('warning before enforcement', () => {
    const r = lib.validateSettings({ ...good, warningBeforeDays: 30 });
    expect(r.errors.warningBeforeDays).toBe('The warning must come before the enforcement deadline.');
  });
  test('grace longer than warning', () => {
    const r = lib.validateSettings({ ...good, resubmitGraceDays: 7 });
    expect(r.errors.resubmitGraceDays).toBe(
      'The resubmission grace period must be longer than the warning period.'
    );
  });
});

describe('createApi', () => {
  const jsonRes = (status, body) => ({
    ok: status >= 200 && status < 300,
    status,
    text: async () => (body === undefined ? '' : JSON.stringify(body)),
    blob: async () => 'BLOB',
  });
  const make = (impl) => {
    const fetchImpl = jest.fn(impl);
    const onUnauthorized = jest.fn();
    const api = lib.createApi({
      baseUrl: 'http://x/api',
      getToken: () => 'tok',
      onUnauthorized,
      fetchImpl,
    });
    return { api, fetchImpl, onUnauthorized };
  };

  test('get adds bearer, passes signal, returns JSON', async () => {
    const { api, fetchImpl } = make(async () => jsonRes(200, { a: 1 }));
    const signal = {};
    await expect(api.get('/kyc/stats', { signal })).resolves.toEqual({ a: 1 });
    const [url, opts] = fetchImpl.mock.calls[0];
    expect(url).toBe('http://x/api/kyc/stats');
    expect(opts.method).toBe('GET');
    expect(opts.headers.Authorization).toBe('Bearer tok');
    expect(opts.signal).toBe(signal);
  });

  test('post and put send JSON bodies', async () => {
    const { api, fetchImpl } = make(async () => jsonRes(200, { ok: 1 }));
    await api.post('/p', { reason: 'r' });
    await api.put('/q', { n: 2 });
    const [, post] = fetchImpl.mock.calls[0];
    expect(post.method).toBe('POST');
    expect(post.headers['Content-Type']).toBe('application/json');
    expect(post.body).toBe('{"reason":"r"}');
    expect(fetchImpl.mock.calls[1][1].method).toBe('PUT');
  });

  test('204 and empty bodies give null', async () => {
    const { api } = make(async () => jsonRes(204));
    await expect(api.post('/p', {})).resolves.toBeNull();
  });

  test('401 calls onUnauthorized and throws ApiError', async () => {
    const { api, onUnauthorized } = make(async () => jsonRes(401, { message: 'Bad token' }));
    const err = await api.get('/x').catch((e) => e);
    expect(err).toBeInstanceOf(lib.ApiError);
    expect(err.status).toBe(401);
    expect(err.message).toBe('Your session ended. Sign in again.');
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  test('409 surfaces the server message', async () => {
    const { api, onUnauthorized } = make(async () =>
      jsonRes(409, { message: 'This KYC is not waiting for review.' })
    );
    const err = await api.post('/x', {}).catch((e) => e);
    expect(err.status).toBe(409);
    expect(err.message).toBe('This KYC is not waiting for review.');
    expect(onUnauthorized).not.toHaveBeenCalled();
  });

  test('2xx with a non-JSON body throws a generic ApiError', async () => {
    const { api } = make(async () => ({ ok: true, status: 200, text: async () => '<html>' }));
    const err = await api.get('/x').catch((e) => e);
    expect(err).toBeInstanceOf(lib.ApiError);
    expect(err.status).toBe(200);
    expect(err.message).toBe('Something went wrong. Please try again.');
  });

  test('onUnauthorized fires once across concurrent 401s', async () => {
    const { api, onUnauthorized } = make(async () => jsonRes(401, {}));
    const errs = await Promise.all([api.get('/a').catch((e) => e), api.get('/b').catch((e) => e)]);
    expect(errs.map((e) => e.message)).toEqual(['Your session ended. Sign in again.', 'Your session ended. Sign in again.']);
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  test('missing token: no network call, no header, session error', async () => {
    const fetchImpl = jest.fn();
    const onUnauthorized = jest.fn();
    const api = lib.createApi({ baseUrl: 'http://x', getToken: () => null, onUnauthorized, fetchImpl });
    const err = await api.get('/x').catch((e) => e);
    expect(err.status).toBe(401);
    expect(err.message).toBe('Your session ended. Sign in again.');
    expect(fetchImpl).not.toHaveBeenCalled();
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  test('non-JSON error body falls back to generic message', async () => {
    const { api } = make(async () => ({
      ok: false,
      status: 500,
      text: async () => '<html>',
      blob: async () => null,
    }));
    const err = await api.get('/x').catch((e) => e);
    expect(err.message).toBe('Something went wrong. Please try again.');
  });

  test('network failure becomes ApiError(0)', async () => {
    const { api } = make(async () => {
      throw new TypeError('fetch failed');
    });
    const err = await api.get('/x').catch((e) => e);
    expect(err).toBeInstanceOf(lib.ApiError);
    expect(err.status).toBe(0);
    expect(err.message).toBe('No connection. Check your internet and try again.');
  });

  test('aborts are rethrown untouched', async () => {
    const abort = Object.assign(new Error('aborted'), { name: 'AbortError' });
    const { api } = make(async () => {
      throw abort;
    });
    await expect(api.get('/x')).rejects.toBe(abort);
  });

  test('blob returns the blob, passes signal, and throws on non-2xx', async () => {
    const { api, fetchImpl } = make(async () => jsonRes(200));
    const signal = {};
    await expect(api.blob('/kyc/documents/1', { signal })).resolves.toBe('BLOB');
    expect(fetchImpl.mock.calls[0][1].signal).toBe(signal);
    expect(fetchImpl.mock.calls[0][1].headers.Authorization).toBe('Bearer tok');

    const bad = make(async () => jsonRes(404, { message: 'Document not found.' }));
    const err = await bad.api.blob('/kyc/documents/2').catch((e) => e);
    expect(err.status).toBe(404);
    expect(err.message).toBe('Document not found.');
  });
});

describe('currentRole', () => {
  const setStorage = (value) => {
    global.localStorage = { getItem: () => value };
  };
  afterEach(() => {
    delete global.localStorage;
  });
  test('reads role', () => {
    setStorage(JSON.stringify({ role: 'kyc_reviewer' }));
    expect(lib.currentRole()).toBe('kyc_reviewer');
  });
  test('null when absent, malformed or roleless', () => {
    setStorage(null);
    expect(lib.currentRole()).toBeNull();
    setStorage('{nope');
    expect(lib.currentRole()).toBeNull();
    setStorage('{}');
    expect(lib.currentRole()).toBeNull();
    setStorage('null');
    expect(lib.currentRole()).toBeNull();
  });
  test('null when localStorage is missing', () => {
    expect(lib.currentRole()).toBeNull();
  });
});
