// KYC admin page: overview and review queue. Builds every node with KycLib.el(),
// so server and user data only ever reach the page as text.
(function () {
  'use strict';

  const {
    el,
    statusLabel,
    statusTone,
    formatDate,
    formatDateTime,
    validateReason,
    validateExemption,
    createApi,
    currentRole,
  } = window.KycLib;

  const ALLOWED_ROLES = ['super_admin', 'kyc_reviewer'];
  const NO_ACCESS = "You don't have access to this.";
  const PAGE_SIZE = 25;
  const SEARCH_DELAY_MS = 300;
  const MAX_QUERY = 64;
  const SKELETON_ROWS = 6;

  const STATUS_CODES = [
    'PENDING_REVIEW',
    'NOT_STARTED',
    'IN_PROGRESS',
    'APPROVED',
    'REQUIRES_CORRECTION',
    'REJECTED',
    'EXPIRED',
    'RESTRICTED',
  ];

  // Stats field, status filter it applies ('' = all).
  const SECONDARY_COUNTS = [
    ['total', ''],
    ['approved', 'APPROVED'],
    ['notStarted', 'NOT_STARTED'],
    ['inProgress', 'IN_PROGRESS'],
    ['requiresCorrection', 'REQUIRES_CORRECTION'],
    ['rejected', 'REJECTED'],
    ['expired', 'EXPIRED'],
    ['restricted', 'RESTRICTED'],
  ];

  const TABS = [
    { id: 'queue', label: 'Review queue' },
    { id: 'settings', label: 'Settings' },
    { id: 'audit', label: 'Audit log' },
  ];

  const numberFormat = new Intl.NumberFormat('en-GB');
  const formatCount = (n) => numberFormat.format(Number(n) || 0);

  const root = document.getElementById('kycRoot');

  // --- Top bar (works for every role) ----------------------------------------

  const signOut = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    window.location.href = 'login.html';
  };

  const setUpTopBar = () => {
    const logoutButton = document.getElementById('logoutButton');
    if (logoutButton) logoutButton.addEventListener('click', signOut);

    const menuButton = document.getElementById('menuButton');
    if (menuButton) {
      menuButton.setAttribute('aria-expanded', 'false');
      menuButton.addEventListener('click', () => {
        if (typeof window.toggleSidebar === 'function') window.toggleSidebar();
        const sidebar = document.getElementById('sidebar');
        const open = !!(sidebar && sidebar.classList.contains('active'));
        menuButton.setAttribute('aria-expanded', String(open));
      });
    }

    let username = '';
    try {
      const user = JSON.parse(localStorage.getItem('user'));
      if (user && typeof user.username === 'string') username = user.username;
    } catch (err) {
      username = '';
    }
    const info = document.getElementById('userInfo');
    if (info && username) {
      info.replaceChildren(
        el('span', { className: 'avatar', 'aria-hidden': 'true' }, username.charAt(0).toUpperCase()),
        el('span', {}, username)
      );
    }
  };

  setUpTopBar();

  // --- Access gate -------------------------------------------------------------

  let blocked = false;
  let listController = null;

  const renderNoAccess = () => {
    blocked = true;
    if (listController) listController.abort();
    root.replaceChildren(
      el('div', { className: 'kyc-notice', role: 'alert' }, el('p', {}, NO_ACCESS))
    );
  };

  if (!ALLOWED_ROLES.includes(currentRole())) {
    renderNoAccess();
    return;
  }

  const api = createApi({
    baseUrl: `${CONFIG.API_URL}/admin/kyc`,
    getToken: () => localStorage.getItem('token'),
    onUnauthorized: () => sessionEnded(),
  });

  // 401 shows the session notice (see sessionEnded); 403 replaces the page. Anything else gets the view's error state.
  const handleFailure = (err, showError) => {
    if (blocked) return;
    if (err && err.status === 401) return;
    if (err && err.status === 403) {
      renderNoAccess();
      return;
    }
    showError(err && err.message ? err.message : 'Something went wrong. Please try again.');
  };

  // --- URL state ---------------------------------------------------------------

  const readUrl = () => {
    const params = new URLSearchParams(window.location.search);
    const status = params.get('status');
    const page = Number(params.get('page'));
    const tab = params.get('tab');
    return {
      q: (params.get('q') || '').slice(0, MAX_QUERY),
      status: STATUS_CODES.includes(status) ? status : '',
      page: Number.isInteger(page) && page >= 1 ? page : 1,
      tab: TABS.some((t) => t.id === tab) ? tab : 'queue',
    };
  };

  const state = readUrl();

  const writeUrl = (mode) => {
    const params = new URLSearchParams();
    if (state.tab !== 'queue') params.set('tab', state.tab);
    if (state.q) params.set('q', state.q);
    if (state.status) params.set('status', state.status);
    if (state.page > 1) params.set('page', String(state.page));
    const query = params.toString();
    const url = window.location.pathname + (query ? `?${query}` : '');
    if (url === window.location.pathname + window.location.search) return;
    if (mode === 'push') window.history.pushState(null, '', url);
    else window.history.replaceState(null, '', url);
  };

  // --- Small builders ----------------------------------------------------------

  const badge = (code) =>
    el('span', { className: `kyc-badge tone-${statusTone(code)}` }, statusLabel(code));

  const textOrNone = (text) => (text ? text : el('span', { className: 'kyc-muted' }, 'None'));

  const button = (label, onClick, className = 'kyc-btn', props = {}) =>
    el('button', { type: 'button', className, on: { click: onClick }, ...props }, label);

  const skeleton = (className = '') => el('span', { className: `kyc-skeleton ${className}`.trim(), 'aria-hidden': 'true' });

  const liveStatus = el('p', { className: 'kyc-sr-only', role: 'status' });
  const announce = (text) => {
    liveStatus.textContent = text;
  };

  // --- Overview ----------------------------------------------------------------

  const overview = el('section', { className: 'kyc-overview', 'aria-labelledby': 'kyc-overview-title' });
  let stats = null;
  const countButtons = [];

  const syncPressed = () => {
    for (const { node, status } of countButtons) {
      node.setAttribute('aria-pressed', String(state.status === status));
    }
  };

  const renderOverviewLoading = () => {
    overview.setAttribute('aria-busy', 'true');
    countButtons.length = 0;
    overview.replaceChildren(
      el(
        'div',
        { className: 'kyc-primary' },
        el('h2', { className: 'kyc-primary-label', id: 'kyc-overview-title' }, 'Waiting for review'),
        skeleton('kyc-skeleton-number')
      ),
      el(
        'ul',
        { className: 'kyc-secondary', 'aria-hidden': 'true' },
        SECONDARY_COUNTS.map(() => el('li', {}, el('span', { className: 'kyc-count' }, skeleton(), skeleton('kyc-skeleton-label'))))
      )
    );
  };

  const renderOverviewError = (message) => {
    overview.removeAttribute('aria-busy');
    countButtons.length = 0;
    overview.replaceChildren(
      el(
        'div',
        { className: 'kyc-state kyc-state-inline', role: 'alert' },
        el('h2', { className: 'kyc-state-title', id: 'kyc-overview-title' }, "We couldn't load the counts."),
        el('p', {}, message),
        button('Try again', loadStats, 'kyc-btn')
      )
    );
  };

  const renderOverview = () => {
    overview.removeAttribute('aria-busy');
    countButtons.length = 0;
    const items = SECONDARY_COUNTS.map(([field, status]) => {
      const label = status ? statusLabel(status) : 'Total';
      const node = el(
        'button',
        {
          type: 'button',
          className: 'kyc-count',
          'aria-pressed': 'false',
          on: { click: () => setStatus(status) },
        },
        el('span', { className: 'kyc-count-value' }, formatCount(stats[field])),
        el('span', { className: 'kyc-count-label' }, label)
      );
      countButtons.push({ node, status });
      return el('li', {}, node);
    });
    const pending = el(
      'button',
      {
        type: 'button',
        className: 'kyc-link',
        on: { click: () => setStatus('PENDING_REVIEW') },
      },
      'Show them in the queue'
    );
    countButtons.push({ node: pending, status: 'PENDING_REVIEW' });
    overview.replaceChildren(
      el(
        'div',
        { className: 'kyc-primary' },
        el('h2', { className: 'kyc-primary-label', id: 'kyc-overview-title' }, 'Waiting for review'),
        el('p', { className: 'kyc-primary-value' }, formatCount(stats.pendingReview)),
        pending
      ),
      el('ul', { className: 'kyc-secondary', 'aria-label': 'All users by status' }, items)
    );
    syncPressed();
  };

  async function loadStats() {
    renderOverviewLoading();
    try {
      stats = await api.get('/stats');
      if (!blocked) renderOverview();
    } catch (err) {
      handleFailure(err, renderOverviewError);
    }
  }

  // --- Queue -------------------------------------------------------------------

  const searchInput = el('input', {
    type: 'search',
    id: 'kyc-q',
    name: 'q',
    maxLength: MAX_QUERY,
    autocomplete: 'off',
    spellcheck: 'false',
    value: state.q,
  });

  const statusSelect = el(
    'select',
    { id: 'kyc-status', name: 'status' },
    el('option', { value: '' }, 'All statuses'),
    STATUS_CODES.map((code) => el('option', { value: code }, statusLabel(code)))
  );
  statusSelect.value = state.status;

  const toolbar = el(
    'div',
    { className: 'kyc-toolbar' },
    el('div', { className: 'kyc-field kyc-field-search' }, el('label', { for: 'kyc-q' }, 'Search by phone or name'), searchInput),
    el('div', { className: 'kyc-field' }, el('label', { for: 'kyc-status' }, 'Status'), statusSelect)
  );

  const tbody = el('tbody');
  const table = el(
    'table',
    { className: 'kyc-table' },
    el('caption', { className: 'kyc-sr-only' }, 'App users and their KYC status'),
    el(
      'thead',
      {},
      el(
        'tr',
        {},
        el('th', { scope: 'col' }, 'User'),
        el('th', { scope: 'col', className: 'c-registered' }, 'Registered'),
        el('th', { scope: 'col' }, 'Status'),
        el('th', { scope: 'col' }, 'Submitted'),
        el('th', { scope: 'col', className: 'c-reminder' }, 'Last reminder'),
        el('th', { scope: 'col' }, 'Deadline'),
        el('th', { scope: 'col' }, el('span', { className: 'kyc-sr-only' }, 'Actions'))
      )
    ),
    tbody
  );
  const tableWrap = el('div', { className: 'kyc-table-wrap' }, table);
  const stateBox = el('div', { className: 'kyc-state-slot' });

  const prevButton = button('Previous', () => goToPage(state.page - 1), 'kyc-btn');
  const nextButton = button('Next', () => goToPage(state.page + 1), 'kyc-btn');
  const pageText = el('span', { className: 'kyc-page-text' });
  const totalText = el('p', { className: 'kyc-total' });
  const pagination = el(
    'nav',
    { className: 'kyc-pagination', 'aria-label': 'Pages' },
    totalText,
    el('div', { className: 'kyc-pager' }, prevButton, pageText, nextButton)
  );
  pagination.hidden = true;

  const queuePanel = el(
    'section',
    { className: 'kyc-panel', id: 'panel-queue', role: 'tabpanel', 'aria-labelledby': 'tab-queue' },
    overview,
    el('div', { className: 'kyc-queue' }, toolbar, tableWrap, stateBox, pagination)
  );

  const openReview = (user) => {
    // The review panel below listens for this event.
    document.dispatchEvent(new CustomEvent('kyc:review', { detail: { id: user.id } }));
  };

  const isPast = (iso) => {
    const t = new Date(iso).getTime();
    return !Number.isNaN(t) && t <= Date.now();
  };

  const deadlineCell = (iso) => {
    const date = formatDate(iso);
    if (!date) return el('span', { className: 'kyc-muted' }, 'No deadline');
    if (isPast(iso)) return el('span', {}, date, el('span', { className: 'kyc-past' }, 'Passed'));
    return date;
  };

  const userRow = (user) => {
    const hasName = typeof user.displayName === 'string' && user.displayName.trim() !== '';
    const who = hasName ? user.displayName : user.username;
    return el(
      'tr',
      {},
      el(
        'td',
        { className: 'c-user' },
        el('span', { className: hasName ? 'kyc-name' : 'kyc-name kyc-muted' }, hasName ? user.displayName : 'No name'),
        el('span', { className: 'kyc-phone' }, user.username || '')
      ),
      el('td', { className: 'c-registered' }, textOrNone(formatDate(user.registeredAt))),
      el('td', { className: 'c-status' }, badge(user.status)),
      el('td', { className: 'c-submitted' }, textOrNone(formatDateTime(user.submittedAt))),
      el('td', { className: 'c-reminder' }, textOrNone(formatDateTime(user.lastReminderAt))),
      el('td', { className: 'c-deadline' }, el('span', { className: 'kyc-cell-label' }, 'Deadline: '), deadlineCell(user.deadline)),
      el(
        'td',
        { className: 'c-actions' },
        button('Review', () => openReview(user), 'kyc-btn', { 'aria-label': `Review ${who}`, 'data-user-id': user.id })
      )
    );
  };

  const skeletonRow = () =>
    el(
      'tr',
      { className: 'is-skeleton', 'aria-hidden': 'true' },
      el('td', { className: 'c-user' }, skeleton('kyc-skeleton-wide'), skeleton()),
      el('td', { className: 'c-registered' }, skeleton()),
      el('td', { className: 'c-status' }, skeleton()),
      el('td', { className: 'c-submitted' }, skeleton()),
      el('td', { className: 'c-reminder' }, skeleton()),
      el('td', { className: 'c-deadline' }, skeleton()),
      el('td', { className: 'c-actions' }, skeleton('kyc-skeleton-button'))
    );

  const hasFilters = () => state.q.trim() !== '' || state.status !== '';

  const renderListLoading = () => {
    tableWrap.setAttribute('aria-busy', 'true');
    tableWrap.hidden = false;
    stateBox.replaceChildren();
    const rows = [];
    for (let i = 0; i < SKELETON_ROWS; i += 1) rows.push(skeletonRow());
    tbody.replaceChildren(...rows);
    announce('Loading users');
  };

  const renderListError = (message) => {
    tableWrap.removeAttribute('aria-busy');
    tableWrap.hidden = true;
    pagination.hidden = true;
    tbody.replaceChildren();
    stateBox.replaceChildren(
      el(
        'div',
        { className: 'kyc-state', role: 'alert' },
        el('h2', { className: 'kyc-state-title' }, "We couldn't load users."),
        el('p', {}, message),
        button('Try again', loadList, 'kyc-btn kyc-btn-primary')
      )
    );
  };

  const renderEmpty = () => {
    tableWrap.hidden = true;
    pagination.hidden = true;
    tbody.replaceChildren();
    const box = hasFilters()
      ? el(
          'div',
          { className: 'kyc-state' },
          el('h2', { className: 'kyc-state-title' }, 'No users match these filters.'),
          button('Clear filters', clearFilters, 'kyc-btn kyc-btn-primary')
        )
      : el('div', { className: 'kyc-state' }, el('h2', { className: 'kyc-state-title' }, 'No app users yet.'));
    stateBox.replaceChildren(box);
    announce(hasFilters() ? 'No users match these filters.' : 'No app users yet.');
  };

  const renderList = (data) => {
    tableWrap.removeAttribute('aria-busy');
    const items = Array.isArray(data.items) ? data.items : [];
    if (items.length === 0) {
      renderEmpty();
      return;
    }
    stateBox.replaceChildren();
    tableWrap.hidden = false;
    tbody.replaceChildren(...items.map(userRow));

    const totalPages = Math.max(1, Number(data.totalPages) || 1);
    const total = Number(data.total) || items.length;
    const hadFocus = document.activeElement;
    totalText.textContent = `${formatCount(total)} ${total === 1 ? 'user' : 'users'}`;
    pageText.textContent = `Page ${formatCount(state.page)} of ${formatCount(totalPages)}`;
    prevButton.disabled = state.page <= 1;
    nextButton.disabled = state.page >= totalPages;
    pagination.hidden = false;
    // Keep keyboard focus in the pager when the pressed button becomes disabled.
    if (hadFocus === prevButton && prevButton.disabled && !nextButton.disabled) nextButton.focus();
    if (hadFocus === nextButton && nextButton.disabled && !prevButton.disabled) prevButton.focus();
    announce(`${totalText.textContent}. ${pageText.textContent}.`);
  };

  async function loadList() {
    if (blocked) return;
    if (listController) listController.abort();
    const controller = new AbortController();
    listController = controller;
    renderListLoading();

    const params = new URLSearchParams({ page: String(state.page), limit: String(PAGE_SIZE) });
    const term = state.q.trim();
    if (term) params.set('q', term);
    if (state.status) params.set('status', state.status);

    try {
      const data = await api.get(`/users?${params.toString()}`, { signal: controller.signal });
      if (controller !== listController) return;
      listController = null;
      const totalPages = Number(data && data.totalPages) || 0;
      if (data && Array.isArray(data.items) && data.items.length === 0 && totalPages > 0 && state.page > totalPages) {
        state.page = totalPages;
        writeUrl('replace');
        loadList();
        return;
      }
      renderList(data || {});
    } catch (err) {
      if (err && err.name === 'AbortError') return;
      if (controller !== listController) return;
      listController = null;
      handleFailure(err, renderListError);
    }
  }

  // --- Filter actions ----------------------------------------------------------

  let searchTimer = null;

  function setStatus(status) {
    // Keep text typed in the last few hundred ms that the debounce has not applied yet.
    state.q = searchInput.value.slice(0, MAX_QUERY).trim();
    clearTimeout(searchTimer);
    state.status = status;
    state.page = 1;
    statusSelect.value = status;
    syncPressed();
    writeUrl('replace');
    loadList();
  }

  function clearFilters() {
    clearTimeout(searchTimer);
    state.q = '';
    state.status = '';
    state.page = 1;
    searchInput.value = '';
    statusSelect.value = '';
    syncPressed();
    writeUrl('replace');
    loadList();
    searchInput.focus();
  }

  function goToPage(page) {
    if (page < 1 || page === state.page) return;
    state.page = page;
    writeUrl('push');
    loadList();
  }

  searchInput.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      const q = searchInput.value.slice(0, MAX_QUERY);
      if (q === state.q) return;
      state.q = q;
      state.page = 1;
      writeUrl('replace');
      loadList();
    }, SEARCH_DELAY_MS);
  });

  statusSelect.addEventListener('change', () => setStatus(statusSelect.value));

  // --- Tabs --------------------------------------------------------------------

  const placeholderPanel = (id, text) =>
    el(
      'section',
      { className: 'kyc-panel', id: `panel-${id}`, role: 'tabpanel', 'aria-labelledby': `tab-${id}` },
      el('div', { className: 'kyc-state' }, el('p', {}, text))
    );

  const panels = {
    queue: queuePanel,
    settings: placeholderPanel('settings', 'Settings are not available yet.'),
    audit: placeholderPanel('audit', 'The audit log is not available yet.'),
  };

  const tabButtons = TABS.map((t) =>
    el(
      'button',
      {
        type: 'button',
        role: 'tab',
        id: `tab-${t.id}`,
        className: 'kyc-tab',
        'aria-controls': `panel-${t.id}`,
        on: { click: () => selectTab(t.id, true) },
      },
      t.label
    )
  );

  function selectTab(id, push) {
    state.tab = id;
    tabButtons.forEach((b, i) => {
      const selected = TABS[i].id === id;
      b.setAttribute('aria-selected', String(selected));
      b.setAttribute('tabindex', selected ? '0' : '-1');
    });
    for (const [key, panel] of Object.entries(panels)) panel.hidden = key !== id;
    if (push) writeUrl('push');
  }

  const onTabKey = (event) => {
    const index = TABS.findIndex((t) => t.id === state.tab);
    let next = null;
    if (event.key === 'ArrowRight') next = (index + 1) % TABS.length;
    else if (event.key === 'ArrowLeft') next = (index - 1 + TABS.length) % TABS.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = TABS.length - 1;
    if (next === null) return;
    event.preventDefault();
    selectTab(TABS[next].id, true);
    tabButtons[next].focus();
  };

  // --- Review panel ------------------------------------------------------------

  const OBJECT_ID = /^[0-9a-f]{24}$/i;
  const REASON_MAX = 500;
  const MAX_EXEMPTION_DAYS = 90;
  const IMAGE_TYPES = ['image/png', 'image/jpeg'];
  const PDF_TYPE = 'application/pdf';
  const RESTRICTABLE = ['NOT_STARTED', 'IN_PROGRESS', 'REJECTED', 'REQUIRES_CORRECTION', 'EXPIRED'];
  const SESSION_ENDED = 'Your session ended. Sign in again.';
  const REVEAL_PROMPT = 'Reveal ID number? This is recorded in the audit log.';
  const GENERIC = 'Something went wrong. Please try again.';

  const DOC_KINDS = {
    id_front: 'ID card, front',
    id_back: 'ID card, back',
    passport_bio: 'Passport photo page',
    proof_of_residence: 'Proof of residence',
  };
  const ID_TYPES = { national_id: 'National ID', passport: 'Passport' };
  const DECISIONS = {
    pending: 'Waiting for review',
    approved: 'Approved',
    rejected: 'Not approved',
    correction_requested: 'Correction requested',
    expired: 'Expired',
  };
  const EVENT_LABELS = {
    DRAFT_SAVED: 'Draft saved',
    DOCUMENT_UPLOADED: 'Document uploaded',
    SUBMITTED: 'Submitted for review',
    REMINDER_SENT: 'Reminder sent',
    REMINDER_SKIPPED: 'Reminder skipped',
    RESTRICTED: 'Restricted',
    UNRESTRICTED: 'Restriction lifted',
    APPROVED: 'Approved',
    REJECTED: 'Not approved',
    CORRECTION_REQUESTED: 'Correction requested',
    EXPIRED: 'Marked as expired',
    EXEMPTION_GRANTED: 'Exemption granted',
    SETTINGS_CHANGED: 'Settings changed',
    DOCUMENT_VIEWED: 'Document viewed',
    ID_REVEALED: 'ID number revealed',
    MANUAL_REMINDER: 'Reminder sent by a reviewer',
  };

  let dialogSeq = 0;

  // Overlays (panel, dialogs, viewer) close through closeOverlay, which runs the overlay's
  // cleanup straight away. The native close event is queued and can be held back while the page
  // is hidden (for example after a PDF opens in a new tab); object URLs must not wait for it.
  const overlayStack = [];
  const overlayCleanup = new Map();
  const closeOverlay = (dialog) => {
    const i = overlayStack.indexOf(dialog);
    if (i !== -1) overlayStack.splice(i, 1);
    if (dialog.open) dialog.close();
    const cleanup = overlayCleanup.get(dialog);
    overlayCleanup.delete(dialog);
    if (cleanup) cleanup();
  };
  const showOverlay = (dialog, cleanup) => {
    dialog.showModal();
    overlayStack.push(dialog);
    if (cleanup) overlayCleanup.set(dialog, cleanup);
    // Any other way the browser closes it still runs the same cleanup, once.
    dialog.addEventListener(
      'close',
      () => {
        if (!dialog.open) closeOverlay(dialog);
      },
      { once: true }
    );
  };
  // Esc closes only the topmost overlay (a dialog before the panel). Chrome can group close
  // requests for dialogs opened without a user gesture and close several at once, so the key
  // is handled here instead.
  document.addEventListener(
    'keydown',
    (event) => {
      if (event.key !== 'Escape' || overlayStack.length === 0) return;
      event.preventDefault();
      const top = overlayStack[overlayStack.length - 1];
      if (!top.hasAttribute('data-locked')) closeOverlay(top);
    },
    true
  );
  let activeDialog = null;
  let sessionOver = false;

  const messageOf = (err) => (err && err.status === 403 ? NO_ACCESS : (err && err.message) || GENERIC);

  // Date-only strings (YYYY-MM-DD) are calendar days, not instants: read them as local dates.
  const formatDay = (value) => {
    if (typeof value !== 'string' || !value) return '';
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
    if (!m) return value;
    return formatDate(new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  };

  const dayInputValue = (d) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

  const addDays = (d, days) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + days);

  const nameOf = (user) =>
    user && typeof user.displayName === 'string' && user.displayName.trim() !== '' ? user.displayName : null;

  const goToLogin = () => {
    window.location.href = 'login.html';
  };

  const focusIfPossible = (node) => {
    if (node && node.isConnected && typeof node.focus === 'function') {
      node.focus();
      return document.activeElement === node;
    }
    return false;
  };

  // --- Session notice ----------------------------------------------------------

  // A 401 never throws away what the reviewer typed: an open form dialog keeps its text and
  // shows the notice inside itself (so the text can still be selected and copied); otherwise
  // a blocking notice covers the page. Either way the only way on is signing in again.
  function showSessionDialog() {
    const signIn = button('Sign in', goToLogin, 'kyc-btn kyc-btn-primary');
    const dialog = el(
      'dialog',
      { className: 'kyc-dialog', role: 'alertdialog', 'aria-labelledby': 'kyc-session-title', 'data-locked': 'true' },
      el('h2', { className: 'kyc-dialog-title', id: 'kyc-session-title' }, SESSION_ENDED),
      el('div', { className: 'kyc-dialog-actions' }, signIn)
    );
    dialog.addEventListener('cancel', (event) => event.preventDefault());
    document.body.appendChild(dialog);
    showOverlay(dialog, goToLogin);
    signIn.focus();
  }

  function sessionEnded() {
    if (sessionOver) return;
    sessionOver = true;
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    if (activeDialog && activeDialog.dialog.open) activeDialog.showSession();
    else showSessionDialog();
  }

  // --- Panel shell -------------------------------------------------------------

  const review = {
    id: null,
    detail: null,
    controller: null,
    thumbController: new AbortController(),
    thumbs: new Map(),
    urls: new Set(),
  };

  const drawerTitle = el('h2', { className: 'kyc-drawer-title', id: 'kyc-drawer-title', tabindex: -1 });
  const drawerBadge = el('div', { className: 'kyc-drawer-badge' });
  const drawerClose = el('button', { type: 'button', className: 'kyc-btn', on: { click: () => closeOverlay(drawer) } }, 'Close');
  const drawerMessage = el('p', { className: 'kyc-message', role: 'status' });
  const drawerAlert = el('div', { className: 'kyc-message kyc-message-error', role: 'alert' });
  const drawerBody = el('div', { className: 'kyc-drawer-body' });
  const drawerActions = el('div', { className: 'kyc-drawer-actions', role: 'group', 'aria-label': 'Review actions' });
  drawerActions.hidden = true;
  const drawer = el(
    'dialog',
    { className: 'kyc-drawer', 'aria-labelledby': 'kyc-drawer-title' },
    el(
      'header',
      { className: 'kyc-drawer-header' },
      el('div', { className: 'kyc-drawer-heading' }, drawerTitle, drawerBadge),
      drawerClose
    ),
    el('div', { className: 'kyc-drawer-scroll' }, drawerMessage, drawerAlert, drawerBody),
    drawerActions
  );
  document.body.appendChild(drawer);

  const setMessage = (text) => {
    drawerMessage.textContent = text || '';
  };
  const setAlert = (text) => {
    drawerAlert.textContent = text || '';
  };

  const reviewButtonFor = (id) =>
    Array.from(tbody.querySelectorAll('button[data-user-id]')).find((b) => b.getAttribute('data-user-id') === id);

  const drawerCleanup = () => {
    const id = review.id;
    if (review.controller) review.controller.abort();
    review.thumbController.abort();
    for (const url of review.urls) URL.revokeObjectURL(url);
    review.urls.clear();
    review.thumbs = new Map();
    review.controller = null;
    review.id = null;
    review.detail = null;
    drawerTitle.textContent = '';
    drawerBadge.replaceChildren();
    drawerBody.replaceChildren();
    drawerActions.replaceChildren();
    drawerActions.hidden = true;
    setMessage('');
    setAlert('');
    if (sessionOver) return;
    if (!focusIfPossible(reviewButtonFor(id))) focusIfPossible(root);
  };

  function openPanel(id) {
    if (blocked || sessionOver || !OBJECT_ID.test(id)) return;
    if (drawer.open) closeOverlay(drawer);
    review.id = id;
    review.detail = null;
    review.thumbController = new AbortController();
    setMessage('');
    setAlert('');
    showOverlay(drawer, drawerCleanup);
    drawerClose.focus();
    loadDetail();
  }

  document.addEventListener('kyc:review', (event) => {
    const id = event.detail && typeof event.detail.id === 'string' ? event.detail.id : '';
    openPanel(id);
  });

  // After an action and after a 409: the server's state is the truth.
  function refreshAfterChange() {
    loadDetail();
    loadList();
    loadStats();
  }

  // --- Panel content -----------------------------------------------------------

  const renderDetailLoading = () => {
    drawerTitle.textContent = 'Loading user';
    drawerTitle.classList.add('kyc-muted');
    drawerBadge.replaceChildren();
    drawerActions.hidden = true;
    drawerBody.setAttribute('aria-busy', 'true');
    drawerBody.replaceChildren(
      el(
        'div',
        { className: 'kyc-drawer-loading', 'aria-hidden': 'true' },
        skeleton('kyc-skeleton-wide'),
        skeleton(),
        skeleton('kyc-skeleton-wide'),
        skeleton(),
        skeleton('kyc-skeleton-wide')
      )
    );
  };

  const renderDetailError = (message, canRetry) => {
    drawerBody.removeAttribute('aria-busy');
    drawerActions.hidden = true;
    if (!review.detail) drawerTitle.textContent = 'User';
    drawerBody.replaceChildren(
      el(
        'div',
        { className: 'kyc-state', role: 'alert' },
        el('h3', { className: 'kyc-state-title' }, canRetry ? "We couldn't load this user." : message),
        canRetry ? el('p', {}, message) : null,
        canRetry ? button('Try again', () => loadDetail(), 'kyc-btn kyc-btn-primary') : null
      )
    );
  };

  async function loadDetail({ reveal = false } = {}) {
    const id = review.id;
    if (!id) return;
    if (review.controller) review.controller.abort();
    const controller = new AbortController();
    review.controller = controller;
    if (review.detail) drawerBody.setAttribute('aria-busy', 'true');
    else renderDetailLoading();
    let data;
    try {
      const path = `/users/${encodeURIComponent(id)}${reveal ? '?reveal=1' : ''}`;
      data = await api.get(path, { signal: controller.signal });
      if (!data || !data.user) throw new Error(GENERIC);
    } catch (err) {
      if (err && err.name === 'AbortError') return;
      if (controller !== review.controller) return;
      review.controller = null;
      drawerBody.removeAttribute('aria-busy');
      if (err && err.status === 401) return;
      if (err && err.status === 403) {
        review.detail = null;
        renderDetailError(NO_ACCESS, false);
        return;
      }
      // A failed reveal keeps the panel as it was.
      if (reveal && review.detail) setAlert(messageOf(err));
      else renderDetailError(messageOf(err), true);
      return;
    }
    if (controller !== review.controller || review.id !== id) return;
    review.controller = null;
    review.detail = data;
    renderDetail();
  }

  const notGiven = () => el('span', { className: 'kyc-muted' }, 'Not given');

  const factRows = (rows) =>
    rows
      .filter(Boolean)
      .flatMap(([label, value]) => [
        el('dt', {}, label),
        el('dd', {}, value === null || value === undefined || value === '' ? notGiven() : value),
      ]);

  const group = (title, rows) =>
    el(
      'div',
      { className: 'kyc-group' },
      el('h4', { className: 'kyc-group-title' }, title),
      el('dl', { className: 'kyc-facts' }, factRows(rows))
    );

  const factsView = (user) => {
    const exemption = user.exemption && user.exemptUntil ? user.exemption : null;
    const deadline = formatDate(user.deadline);
    const deadlineText = deadline ? `${deadline}${isPast(user.deadline) ? ' (passed)' : ''}` : null;
    return el(
      'section',
      { className: 'kyc-section', 'aria-label': 'Account' },
      el(
        'dl',
        { className: 'kyc-facts' },
        factRows([
          ['Phone', user.username || ''],
          ['Registered', formatDate(user.registeredAt)],
          ['Deadline', deadlineText || el('span', { className: 'kyc-muted' }, 'No deadline')],
          exemption ? ['Exempt until', formatDate(user.exemptUntil)] : null,
          exemption && exemption.reason ? ['Exemption reason', exemption.reason] : null,
          exemption && exemption.grantedBy ? ['Exemption granted by', exemption.grantedBy] : null,
          user.reviewedBy ? ['Last reviewed by', user.reviewedBy] : null,
        ])
      )
    );
  };

  // --- Documents ---------------------------------------------------------------

  // One fetch per document per open panel; the object URLs are revoked when the panel closes.
  const thumbnailUrl = (doc) => {
    if (!review.thumbs.has(doc.id)) {
      const { signal } = review.thumbController;
      const urls = review.urls;
      const promise = api.blob(`/documents/${encodeURIComponent(doc.id)}`, { signal }).then((blob) => {
        if (signal.aborted) throw new DOMException('Aborted', 'AbortError');
        const url = URL.createObjectURL(new Blob([blob], { type: doc.mime }));
        urls.add(url);
        return url;
      });
      promise.catch(() => {});
      review.thumbs.set(doc.id, promise);
    }
    return review.thumbs.get(doc.id);
  };

  const fillThumbnail = async (doc, box) => {
    try {
      const url = await thumbnailUrl(doc);
      box.replaceChildren(el('img', { src: url, alt: '', className: 'kyc-thumb-image' }));
    } catch (err) {
      if (err && (err.name === 'AbortError' || err.status === 401)) return;
      // Let the next render try again.
      review.thumbs.delete(doc.id);
      box.replaceChildren(el('span', { className: 'kyc-thumb-fallback' }, 'No preview'));
    }
  };

  const documentItem = (doc) => {
    const label = DOC_KINDS[doc.kind] || 'Document';
    const open = (event) => openViewer(doc, label, event.currentTarget);
    if (IMAGE_TYPES.includes(doc.mime)) {
      const box = el('span', { className: 'kyc-thumb' }, el('span', { className: 'kyc-skeleton kyc-thumb-skeleton', 'aria-hidden': 'true' }));
      fillThumbnail(doc, box);
      return el(
        'li',
        {},
        el(
          'button',
          { type: 'button', className: 'kyc-doc', 'aria-label': `Open ${label}`, on: { click: open } },
          box,
          el('span', { className: 'kyc-doc-label' }, label)
        )
      );
    }
    const isPdf = doc.mime === PDF_TYPE;
    const openLabel = isPdf ? 'Open PDF' : 'Open';
    return el(
      'li',
      {},
      el(
        'div',
        { className: 'kyc-doc kyc-doc-file' },
        el('span', { className: 'kyc-thumb kyc-thumb-file', 'aria-hidden': 'true' }, isPdf ? 'PDF' : 'File'),
        el('span', { className: 'kyc-doc-label' }, label),
        button(openLabel, open, 'kyc-btn', { 'aria-label': `${openLabel}: ${label}` })
      )
    );
  };

  const documentsGroup = (s) => {
    const docs = Array.isArray(s.documents) ? s.documents : [];
    return el(
      'div',
      { className: 'kyc-group' },
      el('h4', { className: 'kyc-group-title' }, 'Documents'),
      docs.length
        ? el('ul', { className: 'kyc-docs' }, docs.map(documentItem))
        : el('p', { className: 'kyc-muted' }, 'No documents.')
    );
  };

  // --- Submissions -------------------------------------------------------------

  const confirmReveal = (event) => {
    openDialog({
      title: REVEAL_PROMPT,
      text: 'The number stays visible only until you close this panel.',
      confirmLabel: 'Reveal',
      trigger: event.currentTarget,
      run: () => Promise.resolve(),
      success: () => loadDetail({ reveal: true }),
    });
  };

  const identificationGroup = (s) => {
    const id = s.identification || {};
    let number = null;
    if (typeof id.idNumber === 'string' && id.idNumber) {
      number = el('span', { className: 'kyc-id-number' }, id.idNumber);
    } else if (id.idNumberMasked) {
      number = el(
        'span',
        { className: 'kyc-id-row' },
        el('span', { className: 'kyc-id-number' }, id.idNumberMasked),
        button('Reveal', confirmReveal, 'kyc-link kyc-link-inline', { 'aria-label': 'Reveal ID number' })
      );
    }
    return group('Identification', [
      ['ID type', ID_TYPES[id.idType] || id.idType || ''],
      ['ID number', number],
      ['Expiry date', formatDay(id.idExpiry)],
    ]);
  };

  const decisionGroup = (s) =>
    group('Decision', [
      ['Outcome', DECISIONS[s.decision] || s.decision || ''],
      s.decidedBy ? ['Decided by', s.decidedBy] : null,
      s.decidedAt ? ['Decided on', formatDateTime(s.decidedAt)] : null,
      s.reason ? ['Reason', el('span', { className: 'kyc-reason' }, s.reason)] : null,
    ]);

  const submissionBody = (s) => {
    const p = s.personal || {};
    const a = s.address || {};
    return [
      group('Personal details', [
        ['First name', p.firstName],
        ['Last name', p.lastName],
        ['Date of birth', formatDay(p.dateOfBirth)],
        ['Gender', p.gender],
        ['Nationality', p.nationality],
      ]),
      group('Address', [
        ['Address line 1', a.line1],
        ['Address line 2', a.line2],
        ['City', a.city],
        ['Country', a.country],
      ]),
      identificationGroup(s),
      documentsGroup(s),
      decisionGroup(s),
    ];
  };

  const latestView = (s) =>
    el(
      'section',
      { className: 'kyc-section', 'aria-labelledby': 'kyc-latest-title' },
      el(
        'div',
        { className: 'kyc-section-head' },
        el('h3', { className: 'kyc-section-title', id: 'kyc-latest-title' }, `Submission ${s.version}`),
        el('span', { className: 'kyc-section-meta' }, `Submitted ${formatDateTime(s.submittedAt)}`)
      ),
      submissionBody(s)
    );

  // Earlier submissions are built (and their thumbnails fetched) only when opened.
  const earlierView = (s) => {
    const content = el('div', { className: 'kyc-details-body' });
    let built = false;
    const details = el(
      'details',
      { className: 'kyc-details' },
      el(
        'summary',
        {},
        el('span', { className: 'kyc-details-title' }, `Submission ${s.version}`),
        el('span', { className: 'kyc-section-meta' }, `${DECISIONS[s.decision] || s.decision || ''}, ${formatDate(s.submittedAt)}`)
      ),
      content
    );
    details.addEventListener('toggle', () => {
      if (details.open && !built) {
        built = true;
        content.replaceChildren(...submissionBody(s));
      }
    });
    return details;
  };

  const eventDetail = (e) => {
    const data = e.data && typeof e.data === 'object' ? e.data : {};
    const parts = [];
    if (typeof data.until === 'string' && formatDate(data.until)) parts.push(`Until ${formatDate(data.until)}`);
    if (typeof data.reason === 'string' && data.reason && e.type !== 'UNRESTRICTED') parts.push(data.reason);
    return parts.length ? el('p', { className: 'kyc-event-detail' }, parts.join('. ')) : null;
  };

  const eventsView = (events) =>
    el(
      'section',
      { className: 'kyc-section', 'aria-labelledby': 'kyc-events-title' },
      el('h3', { className: 'kyc-section-title', id: 'kyc-events-title' }, 'Recent activity'),
      events.length
        ? el(
            'ol',
            { className: 'kyc-events' },
            events.map((e) =>
              el(
                'li',
                {},
                el('span', { className: 'kyc-event-type' }, EVENT_LABELS[e.type] || e.type || ''),
                el('span', { className: 'kyc-event-meta' }, `${e.actor || 'System'}, ${formatDateTime(e.createdAt)}`),
                eventDetail(e)
              )
            )
          )
        : el('p', { className: 'kyc-muted' }, 'No activity yet.')
    );

  function renderDetail() {
    const { user } = review.detail;
    const submissions = Array.isArray(review.detail.submissions) ? review.detail.submissions : [];
    const events = Array.isArray(review.detail.events) ? review.detail.events : [];
    const focusInside = drawer.contains(document.activeElement) && document.activeElement !== drawerClose;

    drawerBody.removeAttribute('aria-busy');
    const name = nameOf(user);
    drawerTitle.textContent = name || 'No name';
    drawerTitle.classList.toggle('kyc-muted', !name);
    drawerBadge.replaceChildren(badge(user.status));
    const [latest, ...earlier] = submissions;
    drawerBody.replaceChildren(
      factsView(user),
      latest
        ? latestView(latest)
        : el(
            'section',
            { className: 'kyc-section' },
            el('h3', { className: 'kyc-section-title' }, 'Submission'),
            el('p', { className: 'kyc-muted' }, 'Nothing submitted yet.')
          ),
      earlier.length
        ? el(
            'section',
            { className: 'kyc-section', 'aria-labelledby': 'kyc-earlier-title' },
            el('h3', { className: 'kyc-section-title', id: 'kyc-earlier-title' }, 'Earlier submissions'),
            earlier.map(earlierView)
          )
        : null,
      eventsView(events)
    );
    renderActions(user);
    // The focused control may have been replaced; keep focus inside the panel.
    if (focusInside && !drawer.contains(document.activeElement)) drawerTitle.focus();
  }

  // --- Actions -----------------------------------------------------------------

  function renderActions(user) {
    const status = user.underlyingStatus || user.status;
    const items = [];
    if (status === 'PENDING_REVIEW') {
      items.push(
        button('Approve', confirmApprove, 'kyc-btn kyc-btn-primary'),
        button('Request correction', (e) => openReasonDialog('request-correction', e.currentTarget), 'kyc-btn'),
        button('Reject', (e) => openReasonDialog('reject', e.currentTarget), 'kyc-btn')
      );
    }
    if (status === 'APPROVED') {
      items.push(button('Mark expired', (e) => openReasonDialog('expire', e.currentTarget), 'kyc-btn'));
    }
    if (RESTRICTABLE.includes(status)) {
      if (user.deadline) items.push(button('Send reminder', sendReminder, 'kyc-btn'));
      items.push(button('Grant exemption', openExemptionDialog, 'kyc-btn'));
    }
    drawerActions.replaceChildren(...items);
    drawerActions.hidden = items.length === 0;
  }

  const actionDone = (message) => {
    setAlert('');
    setMessage(message);
    refreshAfterChange();
  };

  // Shared modal for confirmations and forms. Field validation runs in `validate`; server
  // errors (and 409 conflicts, which also refresh the panel) show inside the dialog.
  function openDialog({ title, text, confirmLabel, primary = true, fields = [], initialFocus, validate, run, success, trigger }) {
    dialogSeq += 1;
    const titleId = `kyc-dialog-title-${dialogSeq}`;
    const sessionSlot = el('div');
    const formError = el('div', { className: 'kyc-message kyc-message-error', role: 'alert' });
    const confirmButton = el('button', { type: 'submit', className: primary ? 'kyc-btn kyc-btn-primary' : 'kyc-btn kyc-btn-strong' }, confirmLabel);
    const cancelButton = button('Cancel', () => closeOverlay(dialog), 'kyc-btn');
    let busy = false;
    let ended = false;

    const onSubmit = async (event) => {
      event.preventDefault();
      if (busy || ended) return;
      formError.textContent = '';
      const input = validate ? validate() : { ok: true };
      if (!input.ok) return;
      busy = true;
      confirmButton.disabled = true;
      try {
        const result = await run(input);
        busy = false;
        if (dialog.open) closeOverlay(dialog);
        success(result);
      } catch (err) {
        busy = false;
        if (!ended) confirmButton.disabled = false;
        if (err && err.status === 401) return;
        formError.textContent = messageOf(err);
        if (err && err.status === 409) refreshAfterChange();
      }
    };

    const form = el(
      'form',
      { className: 'kyc-dialog-form', on: { submit: onSubmit } },
      el('h2', { className: 'kyc-dialog-title', id: titleId }, title),
      text ? el('p', { className: 'kyc-dialog-text' }, text) : null,
      sessionSlot,
      fields,
      formError,
      el('div', { className: 'kyc-dialog-actions' }, cancelButton, confirmButton)
    );
    form.noValidate = true;
    const dialog = el('dialog', { className: 'kyc-dialog', 'aria-labelledby': titleId }, form);

    const ctx = {
      dialog,
      showSession() {
        ended = true;
        confirmButton.disabled = true;
        const signIn = button('Sign in', goToLogin, 'kyc-btn kyc-btn-primary');
        sessionSlot.replaceChildren(
          el(
            'div',
            { className: 'kyc-session', role: 'alert' },
            el('p', { className: 'kyc-session-title' }, SESSION_ENDED),
            el('p', {}, 'Copy anything you typed before you sign in.'),
            signIn
          )
        );
        signIn.focus();
      },
    };

    const cleanup = () => {
      if (activeDialog === ctx) activeDialog = null;
      dialog.remove();
      if (sessionOver) {
        showSessionDialog();
        return;
      }
      if (!focusIfPossible(trigger) && drawer.open) drawerTitle.focus();
    };

    document.body.appendChild(dialog);
    activeDialog = ctx;
    showOverlay(dialog, cleanup);
    (initialFocus || cancelButton).focus();
  }

  function confirmApprove(event) {
    const id = review.id;
    openDialog({
      title: 'Approve this verification?',
      text: 'The user is told by notification that they are verified.',
      confirmLabel: 'Approve',
      trigger: event.currentTarget,
      run: () => api.post(`/users/${encodeURIComponent(id)}/approve`),
      success: () => actionDone('Approved.'),
    });
  }

  // Textarea with a live count and its own error line, checked with KycLib.validateReason.
  const reasonField = (idBase, hint) => {
    const errorId = `${idBase}-error`;
    const countId = `${idBase}-count`;
    const hintId = `${idBase}-hint`;
    const count = el('p', { className: 'kyc-char-count', id: countId }, `0 of ${REASON_MAX} characters`);
    const error = el('p', { className: 'kyc-field-error', id: errorId });
    const textarea = el('textarea', {
      id: idBase,
      name: 'reason',
      rows: 4,
      'aria-describedby': `${hintId} ${countId} ${errorId}`,
    });
    const clearError = () => {
      textarea.removeAttribute('aria-invalid');
      error.textContent = '';
    };
    textarea.addEventListener('input', () => {
      const n = textarea.value.trim().length;
      count.textContent = `${n} of ${REASON_MAX} characters`;
      count.classList.toggle('is-over', n > REASON_MAX);
      if (textarea.getAttribute('aria-invalid') === 'true' && validateReason(textarea.value).ok) clearError();
    });
    const node = el(
      'div',
      { className: 'kyc-field kyc-field-block' },
      el('label', { for: idBase }, 'Reason'),
      el('p', { className: 'kyc-field-hint', id: hintId }, hint),
      textarea,
      count,
      error
    );
    const check = () => {
      const result = validateReason(textarea.value);
      if (result.ok) clearError();
      else {
        textarea.setAttribute('aria-invalid', 'true');
        error.textContent = result.error;
      }
      return result;
    };
    return { node, textarea, check };
  };

  const REASON_ACTIONS = {
    reject: {
      title: 'Reject this verification',
      hint: 'The user sees this reason in their notification.',
      confirm: 'Reject',
      done: 'Rejected.',
    },
    'request-correction': {
      title: 'Request a correction',
      hint: 'Tell the user what to fix. They see this in their notification.',
      confirm: 'Request correction',
      done: 'Correction requested.',
    },
    expire: {
      title: 'Mark this verification as expired',
      hint: 'Recorded in the audit log. The user is asked to submit updated details.',
      confirm: 'Mark expired',
      done: 'Marked as expired.',
    },
  };

  function openReasonDialog(action, trigger) {
    const id = review.id;
    const config = REASON_ACTIONS[action];
    dialogSeq += 1;
    const field = reasonField(`kyc-reason-${dialogSeq}`, config.hint);
    openDialog({
      title: config.title,
      confirmLabel: config.confirm,
      primary: false,
      fields: [field.node],
      initialFocus: field.textarea,
      trigger,
      validate: () => {
        const result = field.check();
        if (!result.ok) field.textarea.focus();
        return result;
      },
      run: (input) => api.post(`/users/${encodeURIComponent(id)}/${action}`, { reason: input.value }),
      success: () => actionDone(config.done),
    });
  }

  function openExemptionDialog(event) {
    const id = review.id;
    dialogSeq += 1;
    const base = `kyc-exempt-${dialogSeq}`;
    const today = new Date();
    const dateError = el('p', { className: 'kyc-field-error', id: `${base}-date-error` });
    const dateInput = el('input', {
      type: 'date',
      id: `${base}-date`,
      name: 'until',
      min: dayInputValue(addDays(today, 1)),
      max: dayInputValue(addDays(today, MAX_EXEMPTION_DAYS)),
      'aria-describedby': `${base}-date-hint ${base}-date-error`,
    });
    const reason = reasonField(`${base}-reason`, 'Why this user does not need to verify yet. Recorded in the audit log.');
    const dateField = el(
      'div',
      { className: 'kyc-field kyc-field-block' },
      el('label', { for: `${base}-date` }, 'Exempt until'),
      el(
        'p',
        { className: 'kyc-field-hint', id: `${base}-date-hint` },
        `No reminders or restrictions before this date. Up to ${MAX_EXEMPTION_DAYS} days from today.`
      ),
      dateInput,
      dateError
    );
    // The chosen day starts at local midnight, so tomorrow through today + 90 all pass the
    // server's "after now, within 90 days" check.
    const untilIso = () => {
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateInput.value);
      return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])).toISOString() : '';
    };
    dateInput.addEventListener('input', () => {
      if (dateInput.getAttribute('aria-invalid') !== 'true') return;
      if (!validateExemption({ until: untilIso() }).errors.until) {
        dateInput.removeAttribute('aria-invalid');
        dateError.textContent = '';
      }
    });
    openDialog({
      title: 'Grant an exemption',
      confirmLabel: 'Grant exemption',
      primary: false,
      fields: [dateField, reason.node],
      initialFocus: dateInput,
      trigger: event.currentTarget,
      validate: () => {
        const until = untilIso();
        const result = validateExemption({ until, reason: reason.textarea.value });
        if (result.errors.until) {
          dateInput.setAttribute('aria-invalid', 'true');
          dateError.textContent = result.errors.until;
        } else {
          dateInput.removeAttribute('aria-invalid');
          dateError.textContent = '';
        }
        reason.check();
        if (result.errors.until) dateInput.focus();
        else if (result.errors.reason) reason.textarea.focus();
        return { ok: result.ok, until, reason: result.reason };
      },
      run: (input) => api.post(`/users/${encodeURIComponent(id)}/exemption`, { until: input.until, reason: input.reason }),
      success: () => actionDone('Exemption granted.'),
    });
  }

  async function sendReminder(event) {
    const id = review.id;
    const trigger = event.currentTarget;
    trigger.disabled = true;
    setMessage('');
    setAlert('');
    try {
      await api.post(`/users/${encodeURIComponent(id)}/remind`);
      if (review.id === id) actionDone('Reminder sent.');
    } catch (err) {
      trigger.disabled = false;
      if (err && err.status === 401) return;
      if (review.id !== id) return;
      setAlert(messageOf(err));
      if (err && err.status === 409) refreshAfterChange();
    }
  }

  // --- Document viewer -----------------------------------------------------------

  // Chrome will not run its PDF viewer inside an iframe sandboxed with no permissions (checked
  // against the local harness: the frame shows a blocked-content icon), and granting the frame
  // scripts would defeat the sandbox. So a PDF opens from its blob URL in a new tab, with no
  // opener, and the URL is still revoked when this viewer closes.
  const pdfView = (url) =>
    el(
      'div',
      { className: 'kyc-viewer-state' },
      el('p', { className: 'kyc-state-title' }, 'PDFs open in a new tab.'),
      el('p', {}, 'Your browser shows the file in its own PDF viewer.'),
      button('Open PDF in a new tab', () => window.open(url, '_blank', 'noopener'), 'kyc-btn kyc-btn-primary')
    );

  function openViewer(doc, label, trigger) {
    dialogSeq += 1;
    const titleId = `kyc-viewer-title-${dialogSeq}`;
    const isImage = IMAGE_TYPES.includes(doc.mime);
    const isPdf = doc.mime === PDF_TYPE;
    const stage = el('div', { className: 'kyc-viewer-stage' });
    let controller = null;
    let url = null;

    const revoke = () => {
      if (url) {
        URL.revokeObjectURL(url);
        url = null;
      }
    };

    const zoomButton = isImage
      ? button(
          'Zoom in',
          () => {
            const zoomed = !stage.classList.contains('is-zoomed');
            stage.classList.toggle('is-zoomed', zoomed);
            zoomButton.textContent = zoomed ? 'Fit to screen' : 'Zoom in';
            zoomButton.setAttribute('aria-pressed', String(zoomed));
          },
          'kyc-btn',
          { 'aria-pressed': 'false' }
        )
      : null;
    if (zoomButton) zoomButton.hidden = true;
    const closeButton = button('Close', () => closeOverlay(dialog), 'kyc-btn');

    const showError = (message, retry) => {
      stage.classList.remove('is-zoomed');
      if (zoomButton) zoomButton.hidden = true;
      stage.replaceChildren(
        el(
          'div',
          { className: 'kyc-viewer-state', role: 'alert' },
          el('p', { className: 'kyc-state-title' }, "We couldn't open this document."),
          el('p', {}, message),
          retry ? button('Try again', retry, 'kyc-btn kyc-btn-primary') : null
        )
      );
    };

    async function load() {
      if (controller) controller.abort();
      const current = new AbortController();
      controller = current;
      revoke();
      if (zoomButton) zoomButton.hidden = true;
      stage.replaceChildren(
        el(
          'div',
          { className: 'kyc-viewer-state', role: 'status' },
          el('span', { className: 'kyc-spinner', 'aria-hidden': 'true' }),
          el('span', {}, 'Loading document')
        )
      );
      try {
        const blob = await api.blob(`/documents/${encodeURIComponent(doc.id)}`, { signal: current.signal });
        if (current !== controller || !dialog.open) return;
        controller = null;
        if (!isImage && !isPdf) {
          showError('This file type cannot be shown here.', null);
          return;
        }
        // Re-typed from the allowlist, so a blob URL is never created with an HTML type.
        url = URL.createObjectURL(new Blob([blob], { type: isPdf ? PDF_TYPE : doc.mime }));
        if (isImage) {
          stage.replaceChildren(
            el('img', {
              src: url,
              alt: label,
              className: 'kyc-viewer-image',
              on: { error: () => showError('The image could not be displayed.', load) },
            })
          );
          zoomButton.hidden = false;
        } else {
          stage.replaceChildren(pdfView(url));
        }
      } catch (err) {
        if (err && err.name === 'AbortError') return;
        if (current !== controller) return;
        controller = null;
        if (err && err.status === 401) return;
        showError(messageOf(err), load);
      }
    }

    const dialog = el(
      'dialog',
      { className: 'kyc-viewer', 'aria-labelledby': titleId },
      el(
        'header',
        { className: 'kyc-viewer-header' },
        el('h2', { className: 'kyc-viewer-title', id: titleId }, label),
        el('div', { className: 'kyc-viewer-tools' }, zoomButton, closeButton)
      ),
      stage
    );

    const cleanup = () => {
      if (controller) controller.abort();
      controller = null;
      revoke();
      dialog.remove();
      if (sessionOver) return;
      if (!focusIfPossible(trigger) && drawer.open) drawerTitle.focus();
    };

    document.body.appendChild(dialog);
    showOverlay(dialog, cleanup);
    closeButton.focus();
    load();
  }

  // --- Page --------------------------------------------------------------------

  root.replaceChildren(
    el(
      'header',
      { className: 'kyc-header' },
      el('h1', {}, 'KYC'),
      el('p', { className: 'kyc-subtitle' }, 'Check identity documents from app users and track who still needs to verify.')
    ),
    el('div', { className: 'kyc-tabs', role: 'tablist', 'aria-label': 'KYC sections', on: { keydown: onTabKey } }, tabButtons),
    panels.queue,
    panels.settings,
    panels.audit,
    liveStatus
  );

  window.addEventListener('popstate', () => {
    if (blocked) return;
    clearTimeout(searchTimer);
    Object.assign(state, readUrl());
    searchInput.value = state.q;
    statusSelect.value = state.status;
    syncPressed();
    selectTab(state.tab, false);
    loadList();
  });

  selectTab(state.tab, false);
  loadStats();
  loadList();
})();
