// KYC admin page: overview, review queue, settings and audit log. Builds every node with KycLib.el(),
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
    validateSettings,
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

  const OBJECT_ID = /^[0-9a-f]{24}$/i;

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
  const AUDIT_TYPES = Object.keys(EVENT_LABELS);
  const eventTypeLabel = (type) => (AUDIT_TYPES.includes(type) ? EVENT_LABELS[type] : String(type || ''));

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
  // Closes every overlay except a locked one (the session notice), topmost first. Closing the
  // review panel and the viewer aborts their requests.
  const closeAllOverlays = () => {
    for (const dialog of [...overlayStack].reverse()) {
      if (!dialog.hasAttribute('data-locked')) closeOverlay(dialog);
    }
  };

  // --- Access gate -------------------------------------------------------------

  let blocked = false;
  let listController = null;
  let statsController = null;
  // Sections defined further down register how to abort their own requests.
  const abortOnBlock = [];

  const renderNoAccess = () => {
    blocked = true;
    closeAllOverlays();
    if (listController) listController.abort();
    if (statsController) statsController.abort();
    for (const abort of abortOnBlock) abort();
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

  // Each tab owns its own query parameters; `page` belongs to whichever tab is open. Values
  // for the other tabs stay in memory.
  const readUrl = () => {
    const params = new URLSearchParams(window.location.search);
    const tabParam = params.get('tab');
    const tab = TABS.some((t) => t.id === tabParam) ? tabParam : 'queue';
    const pageParam = Number(params.get('page'));
    const page = Number.isInteger(pageParam) && pageParam >= 1 ? pageParam : 1;
    if (tab === 'settings') return { tab };
    if (tab === 'audit') {
      const type = params.get('type');
      const user = (params.get('user') || '').trim();
      return {
        tab,
        auditType: AUDIT_TYPES.includes(type) ? type : '',
        auditUser: OBJECT_ID.test(user) ? user.toLowerCase() : '',
        auditPage: page,
      };
    }
    const status = params.get('status');
    return {
      tab,
      q: (params.get('q') || '').slice(0, MAX_QUERY),
      status: STATUS_CODES.includes(status) ? status : '',
      page,
    };
  };

  const state = { q: '', status: '', page: 1, auditType: '', auditUser: '', auditPage: 1, ...readUrl() };

  const writeUrl = (mode) => {
    const params = new URLSearchParams();
    if (state.tab !== 'queue') params.set('tab', state.tab);
    if (state.tab === 'queue') {
      if (state.q) params.set('q', state.q);
      if (state.status) params.set('status', state.status);
      if (state.page > 1) params.set('page', String(state.page));
    } else if (state.tab === 'audit') {
      if (state.auditType) params.set('type', state.auditType);
      if (state.auditUser) params.set('user', state.auditUser);
      if (state.auditPage > 1) params.set('page', String(state.auditPage));
    }
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
    if (blocked) return;
    if (statsController) statsController.abort();
    const controller = new AbortController();
    statsController = controller;
    renderOverviewLoading();
    try {
      const data = await api.get('/stats', { signal: controller.signal });
      if (controller !== statsController) return;
      statsController = null;
      stats = data;
      if (!blocked) renderOverview();
    } catch (err) {
      if (err && err.name === 'AbortError') return;
      if (controller !== statsController) return;
      statsController = null;
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
      const q = searchInput.value.slice(0, MAX_QUERY).trim();
      if (q === state.q) return;
      state.q = q;
      state.page = 1;
      writeUrl('replace');
      loadList();
    }, SEARCH_DELAY_MS);
  });

  statusSelect.addEventListener('change', () => setStatus(statusSelect.value));

  // --- Tabs --------------------------------------------------------------------

  // Settings and audit panels are filled in by their sections below.
  const emptyPanel = (id) =>
    el('section', { className: 'kyc-panel', id: `panel-${id}`, role: 'tabpanel', 'aria-labelledby': `tab-${id}` });

  const panels = {
    queue: queuePanel,
    settings: emptyPanel('settings'),
    audit: emptyPanel('audit'),
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
    const previous = state.tab;
    state.tab = id;
    tabButtons.forEach((b, i) => {
      const selected = TABS[i].id === id;
      b.setAttribute('aria-selected', String(selected));
      b.setAttribute('tabindex', selected ? '0' : '-1');
    });
    for (const [key, panel] of Object.entries(panels)) panel.hidden = key !== id;
    if (push) writeUrl('push');
    if (id === 'settings') showSettings();
    if (id === 'audit') showAudit();
    // Coming back to the queue: settings or other reviewers may have changed it meanwhile.
    if (id === 'queue' && previous !== 'queue') {
      loadStats();
      loadList();
    }
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

  const REASON_MAX = 500;
  const MAX_EXEMPTION_DAYS = 90;
  const IMAGE_TYPES = ['image/png', 'image/jpeg'];
  const PDF_TYPE = 'application/pdf';
  const RESTRICTABLE = ['NOT_STARTED', 'IN_PROGRESS', 'REJECTED', 'REQUIRES_CORRECTION', 'EXPIRED'];
  const SESSION_ENDED = 'Your session ended. Sign in again.';
  const REVEAL_PROMPT = 'Reveal ID number? This is recorded in the audit log.';
  const GENERIC = 'Something went wrong. Please try again.';

  const DOC_KINDS = {
    id_front: 'National ID, front',
    id_back: 'National ID, back',
    passport_bio: 'Passport photo page',
    proof_of_residence: 'Proof of residence',
  };
  const ID_TYPES = { national_id: 'National ID', passport: 'Passport' };
  const GENDERS = { male: 'Male', female: 'Female', other: 'Other' };
  const DECISIONS = {
    pending: 'Under review',
    approved: 'Verified',
    rejected: 'Not approved',
    correction_requested: 'Needs a correction',
    expired: 'Expired',
  };

  let dialogSeq = 0;

  // Esc closes only the topmost overlay (a dialog before the panel). Chrome can group close
  // requests for dialogs opened without a user gesture and close several at once, so the key
  // is handled here instead.
  document.addEventListener(
    'keydown',
    (event) => {
      if (event.isComposing || event.key !== 'Escape' || overlayStack.length === 0) return;
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
        ['Gender', GENDERS[p.gender] || p.gender],
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

  // Runs of DOCUMENT_VIEWED by the same reviewer become one line (newest first, so the first
  // event in a run has the latest time). The audit log keeps every event.
  const groupEvents = (events) => {
    const out = [];
    for (const e of events) {
      const last = out[out.length - 1];
      if (e.type === 'DOCUMENT_VIEWED' && last && last.type === 'DOCUMENT_VIEWED' && last.actor === e.actor) {
        last.count += 1;
      } else {
        out.push({ ...e, count: 1 });
      }
    }
    return out;
  };

  const eventLabel = (e) =>
    e.type === 'DOCUMENT_VIEWED' && e.count > 1
      ? `Documents viewed by ${e.actor || 'System'} (${e.count})`
      : eventTypeLabel(e.type);

  const eventMeta = (e) =>
    e.type === 'DOCUMENT_VIEWED' && e.count > 1
      ? formatDateTime(e.createdAt)
      : `${e.actor || 'System'}, ${formatDateTime(e.createdAt)}`;

  const eventsView = (events, userId) =>
    el(
      'section',
      { className: 'kyc-section', 'aria-labelledby': 'kyc-events-title' },
      el(
        'div',
        { className: 'kyc-section-head' },
        el('h3', { className: 'kyc-section-title', id: 'kyc-events-title' }, 'Recent activity'),
        button('Open in audit log', () => openAuditFor(userId), 'kyc-link kyc-link-inline')
      ),
      events.length
        ? el(
            'ol',
            { className: 'kyc-events' },
            groupEvents(events).map((e) =>
              el(
                'li',
                {},
                el('span', { className: 'kyc-event-type' }, eventLabel(e)),
                el('span', { className: 'kyc-event-meta' }, eventMeta(e)),
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
    // replaceChildren() would turn null into the text "null", so empty sections are dropped first.
    const sections = [
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
      eventsView(events, review.id),
    ];
    drawerBody.replaceChildren(...sections.filter(Boolean));
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
        if (err && err.status === 401) return;
        formError.textContent = messageOf(err);
        if (err && err.status === 409) {
          // Someone else changed this user first, so the action can no longer succeed. Only
          // Close is left; anything typed stays in the form so it can be copied.
          ended = true;
          confirmButton.remove();
          cancelButton.textContent = 'Close';
          cancelButton.focus();
          refreshAfterChange();
          return;
        }
        if (!ended) confirmButton.disabled = false;
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
      el('label', { for: `${base}-date` }, 'Exemption ends on'),
      el(
        'p',
        { className: 'kyc-field-hint', id: `${base}-date-hint` },
        `The exemption ends at the start of this day. Up to ${MAX_EXEMPTION_DAYS} days from today.`
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
      if (review.id === id) {
        actionDone('Reminder sent.');
      } else {
        // The panel closed while the request ran; the reminder still went out.
        loadList();
        loadStats();
      }
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
      el('p', {}, 'The tab stops working after you close this viewer.'),
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
    // An image shows the panel's thumbnail URL, which the panel revokes when it closes.
    let ownsUrl = false;

    const revoke = () => {
      if (url && ownsUrl) URL.revokeObjectURL(url);
      url = null;
      ownsUrl = false;
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

    const showImage = () => {
      stage.replaceChildren(
        el('img', {
          src: url,
          alt: label,
          className: 'kyc-viewer-image',
          on: {
            error: () => {
              // Fetch afresh on retry instead of reusing the URL that failed.
              review.thumbs.delete(doc.id);
              showError('The image could not be displayed.', load);
            },
          },
        })
      );
      zoomButton.hidden = false;
    };

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
        if (isImage) {
          // The panel has already fetched this image for its thumbnail: reuse it, so opening
          // it is not a second download (or a second "Document viewed" audit entry).
          const shared = await thumbnailUrl(doc);
          if (current !== controller || !dialog.open) return;
          controller = null;
          url = shared;
          showImage();
          return;
        }
        const blob = await api.blob(`/documents/${encodeURIComponent(doc.id)}`, { signal: current.signal });
        if (current !== controller || !dialog.open) return;
        controller = null;
        if (!isPdf) {
          showError('This file type cannot be shown here.', null);
          return;
        }
        // Re-typed from the allowlist, so a blob URL is never created with an HTML type.
        url = URL.createObjectURL(new Blob([blob], { type: PDF_TYPE }));
        ownsUrl = true;
        stage.replaceChildren(pdfView(url));
      } catch (err) {
        if (err && err.name === 'AbortError') return;
        if (current !== controller) return;
        controller = null;
        if (isImage) review.thumbs.delete(doc.id);
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

  // --- Settings ------------------------------------------------------------------

  const isSuperAdmin = currentRole() === 'super_admin';
  const RANGE_ERROR = 'Enter a whole number from 1 to 365.';
  const LAUNCH_WORD = 'LAUNCH';
  const ALREADY_LAUNCHED = 'KYC has already been launched.';

  const DAY_SETTINGS = [
    {
      key: 'firstNudgeDays',
      label: 'First reminder (days after start)',
      hint: "Days after a user's KYC period starts before the first reminder.",
    },
    {
      key: 'secondNudgeDays',
      label: 'Second reminder (days)',
      hint: 'Days after the start for the second reminder. Must be later than the first.',
    },
    {
      key: 'reminderIntervalDays',
      label: 'Reminder interval (days)',
      hint: 'Repeat reminders every this many days from the start, including during a resubmission window.',
    },
    {
      key: 'warningBeforeDays',
      label: 'Final warning (days before deadline)',
      hint: 'Must be shorter than the deadline and the resubmission window.',
    },
    {
      key: 'enforcementDays',
      label: 'Deadline (days to complete KYC)',
      hint: "Users who haven't submitted by then are restricted.",
    },
    {
      key: 'resubmitGraceDays',
      label: 'Resubmission window (days)',
      hint: 'Days a user gets to resubmit after a rejection, correction request or expiry.',
    },
  ];
  const DAY_KEYS = DAY_SETTINGS.map((f) => f.key);
  const REMINDERS_LABEL = 'Reminders on';
  const REMINDERS_HINT = 'Turn off to stop sending reminders. Deadlines and restriction still apply.';

  // The ordering rules, worded with this page's labels.
  const ORDER_ERRORS = {
    secondNudgeDays: 'The second reminder must come after the first.',
    warningBeforeDays: 'The final warning must come before the deadline.',
    resubmitGraceDays: 'The resubmission window must be longer than the final warning.',
    remindersEnabled: 'Choose on or off.',
  };

  // Server messages (validateSettings in kyc_admin.routes.js) mapped back to their field.
  const SERVER_ORDER_ERRORS = new Map([
    ['The second nudge must come after the first.', 'secondNudgeDays'],
    ['The warning must come before the enforcement deadline.', 'warningBeforeDays'],
    ['The resubmission grace period must be longer than the warning period.', 'resubmitGraceDays'],
    ['remindersEnabled must be true or false.', 'remindersEnabled'],
  ]);

  const serverFieldError = (message) => {
    const field = SERVER_ORDER_ERRORS.get(message);
    if (field) return { field, text: ORDER_ERRORS[field] };
    const m = /^(\w+) must be a whole number from 1 to 365\.$/.exec(String(message));
    if (m && DAY_KEYS.includes(m[1])) return { field: m[1], text: RANGE_ERROR };
    return null;
  };

  const dayText = (n) => `${formatCount(n)} ${Number(n) === 1 ? 'day' : 'days'}`;

  const settingsView = { data: null, controller: null, saving: false, launching: false, attempted: false };
  abortOnBlock.push(() => {
    if (settingsView.controller) settingsView.controller.abort();
  });

  const settingsStatus = el('p', { className: 'kyc-settings-status' });
  const settingsMessage = el('p', { className: 'kyc-message', tabindex: -1 });
  const settingsAlert = el('div', { className: 'kyc-message kyc-message-error', role: 'alert', tabindex: -1 });
  const settingsBody = el('div', { className: 'kyc-settings-body' });

  const showSettingsMessage = (text) => {
    settingsMessage.textContent = text;
    announce(text);
  };

  // The alert sits above the form, far from the Launch card on small screens: bring it into
  // view and focus it so a failure is seen, not only announced.
  const revealSettingsAlert = () => {
    if (!settingsAlert.isConnected || !settingsAlert.textContent) return;
    settingsAlert.scrollIntoView({ block: 'center' });
    settingsAlert.focus({ preventScroll: true });
  };

  // Editable form (super_admin). Built once so typed values survive a tab switch.
  const settingInputs = {};
  const settingErrors = {};

  const readNumber = (input) => {
    const v = input.value.trim();
    return /^\d+$/.test(v) ? Number(v) : NaN;
  };

  const formValues = () => {
    const values = {};
    for (const key of DAY_KEYS) values[key] = readNumber(settingInputs[key]);
    values.remindersEnabled = settingInputs.remindersEnabled.checked;
    return values;
  };

  const changedKeys = () => {
    if (!settingsView.data) return [];
    const values = formValues();
    return Object.keys(values).filter((k) => values[k] !== settingsView.data[k]);
  };

  const setFieldError = (key, text) => {
    const input = settingInputs[key];
    if (text) input.setAttribute('aria-invalid', 'true');
    else input.removeAttribute('aria-invalid');
    settingErrors[key].textContent = text || '';
  };

  const fieldErrorText = (key, message) => (message === RANGE_ERROR ? RANGE_ERROR : ORDER_ERRORS[key] || message);

  const showFieldErrors = (errors) => {
    for (const key of [...DAY_KEYS, 'remindersEnabled']) {
      setFieldError(key, errors[key] ? fieldErrorText(key, errors[key]) : '');
    }
  };

  const saveButton = el('button', { type: 'submit', className: 'kyc-btn kyc-btn-primary', disabled: true }, 'Save changes');

  const syncSaveButton = () => {
    saveButton.disabled = settingsView.saving || changedKeys().length === 0;
  };

  const onSettingsInput = () => {
    settingsMessage.textContent = '';
    if (settingsView.attempted) showFieldErrors(validateSettings(formValues()).errors);
    syncSaveButton();
    syncLaunch();
  };

  const numberField = (f) => {
    const id = `kyc-set-${f.key}`;
    const input = el('input', {
      type: 'number',
      id,
      name: f.key,
      min: '1',
      max: '365',
      inputmode: 'numeric',
      'aria-describedby': `${id}-hint ${id}-error`,
      on: { input: onSettingsInput },
    });
    const error = el('p', { className: 'kyc-field-error', id: `${id}-error` });
    settingInputs[f.key] = input;
    settingErrors[f.key] = error;
    return el(
      'div',
      { className: 'kyc-field kyc-setting' },
      el('label', { for: id }, f.label),
      el('p', { className: 'kyc-field-hint', id: `${id}-hint` }, f.hint),
      input,
      error
    );
  };

  const remindersField = () => {
    const id = 'kyc-set-remindersEnabled';
    const input = el('input', {
      type: 'checkbox',
      id,
      name: 'remindersEnabled',
      'aria-describedby': `${id}-hint ${id}-error`,
      on: { change: onSettingsInput },
    });
    const error = el('p', { className: 'kyc-field-error', id: `${id}-error` });
    settingInputs.remindersEnabled = input;
    settingErrors.remindersEnabled = error;
    return el(
      'div',
      { className: 'kyc-field kyc-setting kyc-setting-check' },
      el('div', { className: 'kyc-check' }, input, el('label', { for: id }, REMINDERS_LABEL)),
      el('p', { className: 'kyc-field-hint', id: `${id}-hint` }, REMINDERS_HINT),
      error
    );
  };

  const fillForm = (data) => {
    for (const key of DAY_KEYS) settingInputs[key].value = String(data[key]);
    settingInputs.remindersEnabled.checked = data.remindersEnabled === true;
    settingsView.attempted = false;
    showFieldErrors({});
    syncSaveButton();
  };

  async function onSave(event) {
    event.preventDefault();
    if (settingsView.saving || !settingsView.data) return;
    const keys = changedKeys();
    if (keys.length === 0) return;
    const values = formValues();
    const result = validateSettings(values);
    settingsView.attempted = true;
    settingsMessage.textContent = '';
    settingsAlert.textContent = '';
    showFieldErrors(result.errors);
    if (!result.ok) {
      const first = [...DAY_KEYS, 'remindersEnabled'].find((k) => result.errors[k]);
      if (first) settingInputs[first].focus();
      return;
    }
    const body = {};
    for (const k of keys) body[k] = values[k];
    settingsView.saving = true;
    syncSaveButton();
    try {
      const data = await api.put('/settings', body);
      settingsView.saving = false;
      settingsView.data = data;
      fillForm(data);
      renderSettingsStatus();
      syncLaunch();
      showSettingsMessage('Settings saved.');
      settingsMessage.focus();
      // New day settings move deadlines, so the counts and the queue change.
      if (keys.some((k) => DAY_KEYS.includes(k))) {
        loadStats();
        loadList();
      }
    } catch (err) {
      settingsView.saving = false;
      syncSaveButton();
      if (err && err.status === 401) return;
      const mapped = err && err.status === 400 ? serverFieldError(err.message) : null;
      if (mapped) {
        setFieldError(mapped.field, mapped.text);
        settingInputs[mapped.field].focus();
      } else {
        settingsAlert.textContent = messageOf(err);
      }
    }
  }

  const settingsForm = isSuperAdmin
    ? el(
        'form',
        { className: 'kyc-card kyc-settings-form', 'aria-labelledby': 'kyc-settings-title', on: { submit: onSave } },
        el('h2', { className: 'kyc-card-title', id: 'kyc-settings-title' }, 'Reminders and deadline'),
        el('div', { className: 'kyc-settings-grid' }, DAY_SETTINGS.map(numberField)),
        remindersField(),
        el('div', { className: 'kyc-card-actions' }, saveButton)
      )
    : null;
  if (settingsForm) settingsForm.noValidate = true;

  // Read-only list (kyc_reviewer).
  const settingsList = (data) =>
    el(
      'section',
      { className: 'kyc-card', 'aria-labelledby': 'kyc-settings-title' },
      el('h2', { className: 'kyc-card-title', id: 'kyc-settings-title' }, 'Reminders and deadline'),
      el('p', { className: 'kyc-card-note' }, 'Only a super admin can change these.'),
      el(
        'dl',
        { className: 'kyc-settings-list' },
        DAY_SETTINGS.map((f) =>
          el(
            'div',
            { className: 'kyc-settings-item' },
            el('dt', {}, f.label, el('span', { className: 'kyc-field-hint' }, f.hint)),
            el('dd', {}, dayText(data[f.key]))
          )
        ),
        el(
          'div',
          { className: 'kyc-settings-item' },
          el('dt', {}, REMINDERS_LABEL, el('span', { className: 'kyc-field-hint' }, REMINDERS_HINT)),
          el('dd', {}, data.remindersEnabled === true ? 'On' : 'Off')
        )
      )
    );

  function renderSettingsStatus() {
    const data = settingsView.data;
    const launchedOn = data ? formatDate(data.rolloutAt) : '';
    settingsStatus.textContent = launchedOn ? `Launched on ${launchedOn}` : 'KYC is not launched. Nobody has a deadline yet.';
    settingsStatus.classList.toggle('is-launched', !!launchedOn);
  }

  // One launch form for the page's lifetime (super_admin only). It reads the saved settings
  // each time it syncs, so a re-render never detaches it or duplicates it while a request is
  // in flight. Results go to the persistent settings alert and message above the form.
  const launchInput = el('input', {
    type: 'text',
    id: 'kyc-launch-confirm',
    name: 'confirm',
    autocomplete: 'off',
    spellcheck: 'false',
    'aria-describedby': 'kyc-launch-text kyc-launch-hint',
  });
  const launchText = el('p', { className: 'kyc-launch-text', id: 'kyc-launch-text' });
  const launchHint = el('p', { className: 'kyc-field-hint kyc-launch-hint', id: 'kyc-launch-hint' });
  const launchButton = el('button', { type: 'submit', className: 'kyc-btn kyc-btn-strong', disabled: true }, 'Launch KYC');
  const launchConfirmed = () => launchInput.value.trim() === LAUNCH_WORD;

  function syncLaunch() {
    if (!isSuperAdmin) return;
    const data = settingsView.data;
    if (data) {
      launchText.textContent = `Launching starts the ${data.enforcementDays}-day deadline today for everyone who hasn't verified or submitted. Reminders begin, and anyone who hasn't submitted in time will be restricted. This can't be undone.`;
    }
    const dirty = changedKeys().length > 0;
    launchHint.textContent = dirty ? 'Save your changes first.' : '';
    launchButton.disabled = settingsView.launching || dirty || !launchConfirmed();
  }

  async function onLaunch(event) {
    event.preventDefault();
    if (settingsView.launching || !launchConfirmed() || changedKeys().length > 0) return;
    settingsView.launching = true;
    syncLaunch();
    settingsMessage.textContent = '';
    settingsAlert.textContent = '';
    try {
      const updated = await api.post('/settings/launch');
      settingsView.launching = false;
      settingsView.data = updated;
      launchInput.value = '';
      renderSettings();
      showSettingsMessage('KYC launched.');
      settingsMessage.focus();
      // Deadlines exist now, so the counts and the queue change.
      loadStats();
      loadList();
    } catch (err) {
      settingsView.launching = false;
      syncLaunch();
      if (err && err.status === 401) return;
      if (err && err.status === 409) {
        settingsAlert.textContent = err.message || ALREADY_LAUNCHED;
        revealSettingsAlert();
        // The reload re-renders the settings, which moves the alert and drops its focus.
        await loadSettings({ keepMessages: true });
        revealSettingsAlert();
        return;
      }
      settingsAlert.textContent = messageOf(err);
      revealSettingsAlert();
    }
  }

  launchInput.addEventListener('input', syncLaunch);

  const launchForm = isSuperAdmin
    ? el(
        'form',
        { className: 'kyc-card kyc-launch', 'aria-labelledby': 'kyc-launch-title', on: { submit: onLaunch } },
        el('h2', { className: 'kyc-card-title', id: 'kyc-launch-title' }, 'Launch KYC'),
        launchText,
        el(
          'div',
          { className: 'kyc-field kyc-field-block' },
          el('label', { for: 'kyc-launch-confirm' }, `Type ${LAUNCH_WORD} to confirm`),
          launchInput,
          launchHint
        ),
        el('div', { className: 'kyc-card-actions' }, launchButton)
      )
    : null;
  if (launchForm) launchForm.noValidate = true;

  function renderSettings() {
    const data = settingsView.data;
    settingsBody.removeAttribute('aria-busy');
    renderSettingsStatus();
    const parts = [el('div', { className: 'kyc-card kyc-settings-head' }, settingsStatus)];
    parts.push(settingsMessage, settingsAlert);
    parts.push(isSuperAdmin ? settingsForm : settingsList(data));
    if (isSuperAdmin && !data.rolloutAt) parts.push(launchForm);
    settingsBody.replaceChildren(...parts);
    syncLaunch();
  }

  const renderSettingsLoading = () => {
    settingsBody.setAttribute('aria-busy', 'true');
    settingsBody.replaceChildren(
      el(
        'div',
        { className: 'kyc-card kyc-settings-loading', 'aria-hidden': 'true' },
        skeleton('kyc-skeleton-wide'),
        skeleton(),
        skeleton('kyc-skeleton-wide'),
        skeleton()
      )
    );
    announce('Loading settings');
  };

  const renderSettingsError = (message) => {
    settingsBody.removeAttribute('aria-busy');
    settingsBody.replaceChildren(
      el(
        'div',
        { className: 'kyc-card kyc-state', role: 'alert' },
        el('h2', { className: 'kyc-state-title' }, "We couldn't load the settings."),
        el('p', {}, message),
        button('Try again', () => loadSettings(), 'kyc-btn kyc-btn-primary')
      )
    );
  };

  async function loadSettings({ keepMessages = false } = {}) {
    if (blocked) return;
    if (settingsView.controller) settingsView.controller.abort();
    const controller = new AbortController();
    settingsView.controller = controller;
    if (!keepMessages) {
      settingsMessage.textContent = '';
      settingsAlert.textContent = '';
    }
    // Unsaved edits are kept when the settings are reloaded.
    const dirty = isSuperAdmin && changedKeys().length > 0;
    if (!settingsView.data) renderSettingsLoading();
    try {
      const data = await api.get('/settings', { signal: controller.signal });
      if (controller !== settingsView.controller) return;
      settingsView.controller = null;
      if (!data || typeof data !== 'object') throw new Error(GENERIC);
      settingsView.data = data;
      if (isSuperAdmin && !dirty) fillForm(data);
      else if (isSuperAdmin) syncSaveButton();
      renderSettings();
    } catch (err) {
      if (err && err.name === 'AbortError') return;
      if (controller !== settingsView.controller) return;
      settingsView.controller = null;
      handleFailure(err, (message) => {
        if (settingsView.data) {
          settingsAlert.textContent = message;
          revealSettingsAlert();
        } else renderSettingsError(message);
      });
    }
  }

  // Reloaded each time the tab opens, unless there are unsaved changes.
  function showSettings() {
    if (settingsView.launching) return;
    if (settingsView.data && isSuperAdmin && changedKeys().length > 0) return;
    loadSettings();
  }

  panels.settings.append(settingsBody);

  // --- Audit log -----------------------------------------------------------------

  const AUDIT_SUMMARY_KEYS = 8;
  const AUDIT_VALUE_MAX = 200;
  const USER_ID_ERROR = 'Enter a 24-character user ID, or leave it empty.';
  const ISO_INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/;

  const auditView = { controller: null };
  abortOnBlock.push(() => {
    if (auditView.controller) auditView.controller.abort();
  });

  const auditTypeSelect = el(
    'select',
    { id: 'kyc-audit-type', name: 'type' },
    el('option', { value: '' }, 'All events'),
    AUDIT_TYPES.map((t) => el('option', { value: t }, EVENT_LABELS[t]))
  );
  const auditUserInput = el('input', {
    type: 'text',
    id: 'kyc-audit-user',
    name: 'user',
    autocomplete: 'off',
    spellcheck: 'false',
    maxLength: 64,
    'aria-describedby': 'kyc-audit-user-hint kyc-audit-user-error',
  });
  const auditUserError = el('p', { className: 'kyc-field-error', id: 'kyc-audit-user-error' });

  const setUserError = (text) => {
    if (text) auditUserInput.setAttribute('aria-invalid', 'true');
    else auditUserInput.removeAttribute('aria-invalid');
    auditUserError.textContent = text || '';
  };

  const applyAuditFilters = () => {
    const user = auditUserInput.value.trim();
    if (user && !OBJECT_ID.test(user)) {
      setUserError(USER_ID_ERROR);
      auditUserInput.focus();
      return;
    }
    setUserError('');
    state.auditType = auditTypeSelect.value;
    state.auditUser = user.toLowerCase();
    state.auditPage = 1;
    writeUrl('replace');
    loadAudit();
  };

  auditTypeSelect.addEventListener('change', applyAuditFilters);
  auditUserInput.addEventListener('input', () => {
    if (auditUserInput.getAttribute('aria-invalid') !== 'true') return;
    const user = auditUserInput.value.trim();
    if (!user || OBJECT_ID.test(user)) setUserError('');
  });

  const auditFilters = el(
    'form',
    {
      className: 'kyc-toolbar kyc-audit-filters',
      'aria-label': 'Filter events',
      on: {
        submit: (event) => {
          event.preventDefault();
          applyAuditFilters();
        },
      },
    },
    el('div', { className: 'kyc-field' }, el('label', { for: 'kyc-audit-type' }, 'Type'), auditTypeSelect),
    el(
      'div',
      { className: 'kyc-field kyc-field-search' },
      el('label', { for: 'kyc-audit-user' }, 'User ID'),
      el('p', { className: 'kyc-field-hint', id: 'kyc-audit-user-hint' }, 'Optional. The 24-character ID shown on each event.'),
      auditUserInput,
      auditUserError
    ),
    el('div', { className: 'kyc-audit-apply' }, el('button', { type: 'submit', className: 'kyc-btn' }, 'Apply'))
  );
  auditFilters.noValidate = true;

  const auditList = el('ol', { className: 'kyc-audit-list', 'aria-label': 'Events, newest first' });
  const auditStateBox = el('div', { className: 'kyc-state-slot' });
  const auditPrev = button('Previous', () => goToAuditPage(state.auditPage - 1), 'kyc-btn');
  const auditNext = button('Next', () => goToAuditPage(state.auditPage + 1), 'kyc-btn');
  const auditPageText = el('span', { className: 'kyc-page-text' });
  const auditTotal = el('p', { className: 'kyc-total' });
  const auditPagination = el(
    'nav',
    { className: 'kyc-pagination', 'aria-label': 'Event pages' },
    auditTotal,
    el('div', { className: 'kyc-pager' }, auditPrev, auditPageText, auditNext)
  );
  auditPagination.hidden = true;

  const auditHasFilters = () => state.auditType !== '' || state.auditUser !== '';

  const truncate = (text, max) => (text.length > max ? `${text.slice(0, max)}…` : text);

  // Event data is shown as plain "key: value" text; nested values as JSON text.
  const summaryValue = (value) => {
    let text;
    if (value === null || value === undefined) text = String(value);
    else if (typeof value === 'object') {
      try {
        text = JSON.stringify(value);
      } catch (err) {
        text = '(unreadable)';
      }
    } else if (typeof value === 'string' && ISO_INSTANT.test(value) && formatDateTime(value)) {
      text = formatDateTime(value);
    } else text = String(value);
    return truncate(text, AUDIT_VALUE_MAX);
  };

  const dataSummary = (data) => {
    if (!data || typeof data !== 'object' || Array.isArray(data)) return null;
    const entries = Object.entries(data);
    if (entries.length === 0) return null;
    const shown = entries.slice(0, AUDIT_SUMMARY_KEYS);
    const rest = entries.length - shown.length;
    return el(
      'ul',
      { className: 'kyc-audit-data' },
      shown.map(([key, value]) =>
        el('li', {}, el('span', { className: 'kyc-audit-key' }, `${truncate(key, 60)}: `), summaryValue(value))
      ),
      rest > 0 ? el('li', { className: 'kyc-muted' }, `and ${rest} more`) : null
    );
  };

  const auditRow = (e) =>
    el(
      'li',
      { className: 'kyc-audit-row' },
      el(
        'div',
        { className: 'kyc-audit-head' },
        el('span', { className: 'kyc-audit-type' }, eventTypeLabel(e.type)),
        el('span', { className: 'kyc-audit-time' }, formatDateTime(e.createdAt))
      ),
      el(
        'p',
        { className: 'kyc-audit-meta' },
        el('span', {}, `By ${e.actor || 'system'}`),
        typeof e.appUserId === 'string' && e.appUserId
          ? el('span', {}, 'User ', el('code', { className: 'kyc-audit-user' }, e.appUserId))
          : null
      ),
      dataSummary(e.data)
    );

  const renderAuditLoading = () => {
    auditList.setAttribute('aria-busy', 'true');
    auditList.hidden = false;
    auditStateBox.replaceChildren();
    const rows = [];
    for (let i = 0; i < SKELETON_ROWS; i += 1) {
      rows.push(el('li', { className: 'kyc-audit-row', 'aria-hidden': 'true' }, skeleton('kyc-skeleton-wide'), skeleton()));
    }
    auditList.replaceChildren(...rows);
    announce('Loading events');
  };

  const renderAuditError = (message) => {
    auditList.removeAttribute('aria-busy');
    auditList.hidden = true;
    auditList.replaceChildren();
    auditPagination.hidden = true;
    auditStateBox.replaceChildren(
      el(
        'div',
        { className: 'kyc-state', role: 'alert' },
        el('h2', { className: 'kyc-state-title' }, "We couldn't load the audit log."),
        el('p', {}, message),
        button('Try again', loadAudit, 'kyc-btn kyc-btn-primary')
      )
    );
  };

  const clearAuditFilters = () => {
    auditTypeSelect.value = '';
    auditUserInput.value = '';
    setUserError('');
    applyAuditFilters();
    auditTypeSelect.focus();
  };

  const renderAuditEmpty = () => {
    auditList.hidden = true;
    auditList.replaceChildren();
    auditPagination.hidden = true;
    const text = auditHasFilters() ? 'No events match these filters.' : 'No events yet.';
    auditStateBox.replaceChildren(
      el(
        'div',
        { className: 'kyc-state' },
        el('h2', { className: 'kyc-state-title' }, text),
        auditHasFilters() ? button('Clear filters', clearAuditFilters, 'kyc-btn kyc-btn-primary') : null
      )
    );
    announce(text);
  };

  const renderAudit = (data) => {
    auditList.removeAttribute('aria-busy');
    const items = Array.isArray(data.items) ? data.items : [];
    if (items.length === 0) {
      renderAuditEmpty();
      return;
    }
    auditStateBox.replaceChildren();
    auditList.hidden = false;
    auditList.replaceChildren(...items.map(auditRow));
    const totalPages = Math.max(1, Number(data.totalPages) || 1);
    const total = Number(data.total) || items.length;
    const hadFocus = document.activeElement;
    auditTotal.textContent = `${formatCount(total)} ${total === 1 ? 'event' : 'events'}`;
    auditPageText.textContent = `Page ${formatCount(state.auditPage)} of ${formatCount(totalPages)}`;
    auditPrev.disabled = state.auditPage <= 1;
    auditNext.disabled = state.auditPage >= totalPages;
    auditPagination.hidden = false;
    if (hadFocus === auditPrev && auditPrev.disabled && !auditNext.disabled) auditNext.focus();
    if (hadFocus === auditNext && auditNext.disabled && !auditPrev.disabled) auditPrev.focus();
    announce(`${auditTotal.textContent}. ${auditPageText.textContent}.`);
  };

  async function loadAudit() {
    if (blocked) return;
    if (auditView.controller) auditView.controller.abort();
    const controller = new AbortController();
    auditView.controller = controller;
    renderAuditLoading();
    const params = new URLSearchParams({ page: String(state.auditPage) });
    if (state.auditType) params.set('type', state.auditType);
    if (state.auditUser) params.set('appUserId', state.auditUser);
    try {
      const data = await api.get(`/audit?${params.toString()}`, { signal: controller.signal });
      if (controller !== auditView.controller) return;
      auditView.controller = null;
      const totalPages = Number(data && data.totalPages) || 0;
      if (data && Array.isArray(data.items) && data.items.length === 0 && totalPages > 0 && state.auditPage > totalPages) {
        state.auditPage = totalPages;
        writeUrl('replace');
        loadAudit();
        return;
      }
      renderAudit(data || {});
    } catch (err) {
      if (err && err.name === 'AbortError') return;
      if (controller !== auditView.controller) return;
      auditView.controller = null;
      handleFailure(err, renderAuditError);
    }
  }

  function goToAuditPage(page) {
    if (page < 1 || page === state.auditPage) return;
    state.auditPage = page;
    writeUrl('push');
    loadAudit();
  }

  function showAudit() {
    auditTypeSelect.value = state.auditType;
    auditUserInput.value = state.auditUser;
    setUserError('');
    loadAudit();
  }

  // From a user's review panel: close it and show that user's events.
  function openAuditFor(userId) {
    if (blocked || typeof userId !== 'string' || !OBJECT_ID.test(userId)) return;
    if (drawer.open) closeOverlay(drawer);
    state.auditType = '';
    state.auditUser = userId.toLowerCase();
    state.auditPage = 1;
    selectTab('audit', true);
    focusIfPossible(tabButtons[TABS.findIndex((t) => t.id === 'audit')]);
  }

  panels.audit.append(el('div', { className: 'kyc-queue' }, auditFilters, auditList, auditStateBox, auditPagination));

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
    // The panel, dialogs and viewer belong to the page being left.
    closeAllOverlays();
    clearTimeout(searchTimer);
    const previousTab = state.tab;
    Object.assign(state, readUrl());
    if (state.tab === 'queue') {
      searchInput.value = state.q;
      statusSelect.value = state.status;
      syncPressed();
      if (previousTab !== 'queue') loadStats();
      loadList();
    }
    selectTab(state.tab, false);
  });

  selectTab(state.tab, false);
  loadStats();
  loadList();
})();
