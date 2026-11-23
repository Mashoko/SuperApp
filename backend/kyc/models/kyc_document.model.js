const mongoose = require('mongoose');

const KYC_DOCUMENT_KINDS = ['id_front', 'id_back', 'passport_bio', 'proof_of_residence'];

const kycDocumentSchema = new mongoose.Schema(
  {
    appUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'AppUser',
      required: true,
      index: true,
    },
    kind: { type: String, enum: KYC_DOCUMENT_KINDS, required: true },
    storageKey: { type: String, required: true },
    // Sniffed from the bytes, never taken from the client's Content-Type.
    mime: { type: String, required: true },
    size: { type: Number, required: true },
    sha256: { type: String, required: true },
    // null while the document belongs to the draft.
    submissionId: { type: mongoose.Schema.Types.ObjectId, ref: 'KycSubmission', default: null },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

module.exports = mongoose.model('KycDocument', kycDocumentSchema);
module.exports.KYC_DOCUMENT_KINDS = KYC_DOCUMENT_KINDS;
