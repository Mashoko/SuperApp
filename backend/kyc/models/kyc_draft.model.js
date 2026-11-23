const mongoose = require('mongoose');

// One resumable draft per user. `data` mirrors the submission shape; the ID number is
// kept only as `identification.idNumberEnc` (never plaintext).
const kycDraftSchema = new mongoose.Schema(
  {
    appUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'AppUser',
      required: true,
      unique: true,
    },
    data: { type: mongoose.Schema.Types.Mixed, default: () => ({}) },
  },
  { timestamps: true, minimize: false }
);

module.exports = mongoose.model('KycDraft', kycDraftSchema);
