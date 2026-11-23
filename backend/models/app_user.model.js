const mongoose = require('mongoose');
const { KYC_STATUSES } = require('../kyc/schedule');

const kycSchema = new mongoose.Schema(
  {
    status: { type: String, enum: KYC_STATUSES, default: 'NOT_STARTED' },
    cycle: { type: Number, min: 0, default: 0 },
    cycleStartedAt: { type: Date },
    startedAt: { type: Date },
    submittedAt: { type: Date },
    verifiedAt: { type: Date },
    reviewedBy: { type: String, trim: true },
    rejectionReason: { type: String, trim: true },
    correctionNotes: { type: String, trim: true },
    restrictedAt: { type: Date },
    lastReminderAt: { type: Date },
    lastReminderStage: { type: String, default: null },
    exemption: {
      until: { type: Date },
      reason: { type: String, trim: true },
      grantedBy: { type: String, trim: true },
    },
    lastUpdatedAt: { type: Date },
  },
  { _id: false }
);

const appUserSchema = new mongoose.Schema(
  {
    sipUsername: { type: String, required: true, unique: true, trim: true },
    displayName: { type: String, trim: true, maxlength: 80 },
    lastSessionAt: { type: Date },
    kyc: { type: kycSchema, default: () => ({}) },
  },
  { timestamps: true }
);

module.exports = mongoose.model('AppUser', appUserSchema);
