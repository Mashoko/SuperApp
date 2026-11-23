const mongoose = require('mongoose');

// Lease for background jobs so only one instance runs a job at a time.
const jobLockSchema = new mongoose.Schema({
  name: { type: String, required: true, unique: true },
  holder: { type: String, required: true },
  expiresAt: { type: Date, required: true },
});

module.exports = mongoose.model('JobLock', jobLockSchema);
