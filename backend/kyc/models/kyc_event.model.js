const mongoose = require('mongoose');

const KYC_EVENT_TYPES = [
  'DRAFT_SAVED',
  'DOCUMENT_UPLOADED',
  'SUBMITTED',
  'REMINDER_SENT',
  'REMINDER_SKIPPED',
  'RESTRICTED',
  'UNRESTRICTED',
  'APPROVED',
  'REJECTED',
  'CORRECTION_REQUESTED',
  'EXPIRED',
  'EXEMPTION_GRANTED',
  'SETTINGS_CHANGED',
  'DOCUMENT_VIEWED',
  'ID_REVEALED',
  'MANUAL_REMINDER',
];

// Audit trail. `data` must never hold ID numbers, document bytes, tokens or passwords.
const kycEventSchema = new mongoose.Schema(
  {
    appUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'AppUser', index: true },
    // 'system', 'user', or the staff username.
    actor: { type: String, required: true },
    type: { type: String, enum: KYC_EVENT_TYPES, required: true },
    data: { type: mongoose.Schema.Types.Mixed, default: () => ({}) },
    idempotencyKey: { type: String, unique: true, sparse: true },
  },
  { timestamps: { createdAt: true, updatedAt: false }, minimize: false }
);

kycEventSchema.statics.record = function record({ appUserId, actor = 'user', type, data = {} }) {
  return this.create({ appUserId, actor, type, data });
};

module.exports = mongoose.model('KycEvent', kycEventSchema);
module.exports.KYC_EVENT_TYPES = KYC_EVENT_TYPES;
