const mongoose = require('mongoose');

const NOTIFICATION_KINDS = [
  'NUDGE_1',
  'NUDGE_2',
  'REMINDER',
  'WARNING',
  'RESTRICTED',
  'SUBMITTED',
  'APPROVED',
  'REJECTED',
  'CORRECTION_REQUESTED',
  'EXPIRED',
];

// In-app inbox entry. Title and body are rendered server-side from fixed templates.
const notificationSchema = new mongoose.Schema(
  {
    appUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'AppUser', required: true },
    kind: { type: String, enum: NOTIFICATION_KINDS, required: true },
    title: { type: String, required: true },
    body: { type: String, required: true },
    readAt: { type: Date, default: null },
    deliveredVia: { type: [String], default: () => [] },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

notificationSchema.index({ appUserId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
module.exports.NOTIFICATION_KINDS = NOTIFICATION_KINDS;
