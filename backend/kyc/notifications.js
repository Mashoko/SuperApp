const Notification = require('./models/notification.model');

const TEMPLATES = Object.freeze({
  NUDGE_1: {
    title: 'Verify your number',
    body: 'POTRAZ rules require us to confirm who owns each number. It takes about 5 minutes. Complete it before {deadline}.',
  },
  NUDGE_2: {
    title: 'Your KYC is still open',
    body: 'Finish your KYC before {deadline} to keep calling, shopping and paying without interruption.',
  },
  REMINDER: {
    title: 'Reminder: complete your KYC',
    body: 'Your KYC verification is still outstanding. Complete it before {deadline}.',
  },
  WARNING: {
    title: 'Your account will be limited soon',
    body: 'Complete your KYC before {deadline}. After that, calls, shopping, payments and posts will be paused until you verify.',
  },
  RESTRICTED: {
    title: 'Your account is limited',
    body: 'We have paused calls, shopping, payments and posts because your KYC is not complete. Emergency calls still work. Complete KYC to restore access.',
  },
  SUBMITTED: {
    title: 'KYC received',
    body: 'We are reviewing your details. You can keep using the app while we check them.',
  },
  APPROVED: {
    title: 'You are verified',
    body: 'Your KYC has been approved. Thank you.',
  },
  REJECTED: {
    title: 'KYC not approved',
    body: 'Reason: {reason}. Please correct your details and submit again before {deadline}.',
  },
  CORRECTION_REQUESTED: {
    title: 'KYC needs a correction',
    body: '{reason}. Please update your details and submit again before {deadline}.',
  },
  EXPIRED: {
    title: 'Please renew your KYC',
    body: 'Your verified details have expired. Submit updated details before {deadline}.',
  },
});

// e.g. "22 January 2027", always in UTC.
const formatDeadline = (date) =>
  new Date(date).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  });

const FORMATTERS = {
  deadline: (value) => {
    const d = value instanceof Date ? value : new Date(value);
    if (value == null || Number.isNaN(d.getTime())) throw new Error('Notification deadline is missing.');
    return formatDeadline(d);
  },
  reason: (value) => {
    if (typeof value !== 'string' || !value.trim()) throw new Error('Notification reason is missing.');
    return value.trim();
  },
};

const fill = (text, vars) =>
  text.replace(/\{(\w+)\}/g, (_, name) => {
    const format = FORMATTERS[name];
    if (!format) throw new Error('Unknown notification variable.');
    return format(vars[name]);
  });

// Returns { title, body } for a kind; throws on an unknown kind or a missing variable.
const render = (kind, vars = {}) => {
  const template = Object.prototype.hasOwnProperty.call(TEMPLATES, kind) ? TEMPLATES[kind] : null;
  if (!template) throw new Error('Unknown notification kind.');
  return { title: fill(template.title, vars), body: fill(template.body, vars) };
};

// The stored document is the in-app inbox, so in-app delivery needs no extra work.
const inAppChannel = { name: 'in_app', send: async () => {} };

// Delivery channels, each { name, send(notification) }. Push or email can be added here.
const channels = [inAppChannel];

// Renders the template, runs each channel, then stores the notification with the channels
// that succeeded. A failing channel is logged (name only) and left out of deliveredVia.
const notify = async (appUserId, kind, vars = {}) => {
  const { title, body } = render(kind, vars);
  const notification = new Notification({ appUserId, kind, title, body });
  const delivered = [];
  for (const channel of channels) {
    try {
      await channel.send(notification);
      delivered.push(channel.name);
    } catch (err) {
      console.error('Notification channel failed:', channel.name, err?.name);
    }
  }
  notification.deliveredVia = delivered;
  await notification.save();
  return notification;
};

module.exports = { TEMPLATES, channels, formatDeadline, notify, render };
