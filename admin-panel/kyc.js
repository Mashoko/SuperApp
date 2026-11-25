// KYC admin page: overview and review queue. Builds every node with KycLib.el(),
// so server and user data only ever reach the page as text.
(function () {
  'use strict';

  const { el, statusLabel, statusTone, formatDate, formatDateTime, createApi, currentRole } = window.KycLib;

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
    onUnauthorized: signOut,
  });

  // 401 is already redirecting; 403 replaces the page. Anything else gets the view's error state.
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
    // The review panel (next task) listens for this event.
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
        button('Review', () => openReview(user), 'kyc-btn', { 'aria-label': `Review ${who}` })
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
