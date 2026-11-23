const mongoose = require('mongoose');

const SINGLETON_KEY = 'singleton';

const DEFAULTS = Object.freeze({
  firstNudgeDays: 1,
  secondNudgeDays: 7,
  reminderIntervalDays: 14,
  warningBeforeDays: 4,
  enforcementDays: 60,
  resubmitGraceDays: 14,
  remindersEnabled: true,
});

const dayCount = (def) => ({ type: Number, min: 0, default: def });

const kycSettingsSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, default: SINGLETON_KEY, immutable: true },
    firstNudgeDays: dayCount(DEFAULTS.firstNudgeDays),
    secondNudgeDays: dayCount(DEFAULTS.secondNudgeDays),
    reminderIntervalDays: { type: Number, min: 1, default: DEFAULTS.reminderIntervalDays },
    warningBeforeDays: dayCount(DEFAULTS.warningBeforeDays),
    enforcementDays: { type: Number, min: 1, default: DEFAULTS.enforcementDays },
    resubmitGraceDays: { type: Number, min: 1, default: DEFAULTS.resubmitGraceDays },
    remindersEnabled: { type: Boolean, default: DEFAULTS.remindersEnabled },
    // Null until a super_admin launches KYC (POST /api/admin/kyc/settings/launch). Until
    // then nobody has a deadline, reminders or restriction. Set once, never changed.
    rolloutAt: { type: Date, default: null },
  },
  { timestamps: true }
);

// Returns the settings singleton, creating it with defaults on first call. Never sets
// rolloutAt: launching is an explicit admin step. The upsert is atomic, so concurrent
// first calls create one document.
kycSettingsSchema.statics.getSettings = async function getSettings() {
  const query = { key: SINGLETON_KEY };
  try {
    return await this.findOneAndUpdate(
      query,
      { $setOnInsert: { ...DEFAULTS, rolloutAt: null } },
      { upsert: true, new: true, setDefaultsOnInsert: false }
    );
  } catch (err) {
    // A racing upsert can lose on the unique index; the winner's document is there.
    if (err && err.code === 11000) return this.findOne(query);
    throw err;
  }
};

const KycSettings = mongoose.model('KycSettings', kycSettingsSchema);

module.exports = KycSettings;
module.exports.KYC_SETTINGS_DEFAULTS = DEFAULTS;
