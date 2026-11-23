const mongoose = require('mongoose');

const DECISIONS = ['pending', 'approved', 'rejected', 'correction_requested', 'expired'];

const kycSubmissionSchema = new mongoose.Schema(
  {
    appUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'AppUser', required: true },
    // 1-based per user.
    version: { type: Number, required: true, min: 1 },
    personal: {
      firstName: String,
      lastName: String,
      dateOfBirth: String,
      gender: String,
      nationality: String,
    },
    address: {
      line1: String,
      line2: String,
      city: String,
      country: String,
    },
    identification: {
      idType: { type: String, enum: ['national_id', 'passport'] },
      idNumberEnc: String,
      idExpiry: String,
    },
    phone: { type: String, required: true },
    documentIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'KycDocument' }],
    submittedAt: { type: Date, required: true },
    decision: { type: String, enum: DECISIONS, default: 'pending' },
    decidedBy: String,
    decidedAt: Date,
    reason: String,
  },
  { timestamps: true }
);

// Also guards against two concurrent submits creating the same version.
kycSubmissionSchema.index({ appUserId: 1, version: 1 }, { unique: true });

module.exports = mongoose.model('KycSubmission', kycSubmissionSchema);
module.exports.KYC_DECISIONS = DECISIONS;
