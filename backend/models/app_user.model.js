const mongoose = require('mongoose');

const appUserSchema = new mongoose.Schema(
  {
    sipUsername: { type: String, required: true, unique: true, trim: true },
    displayName: { type: String, trim: true, maxlength: 80 },
    lastSessionAt: { type: Date },
  },
  { timestamps: true }
);

module.exports = mongoose.model('AppUser', appUserSchema);
