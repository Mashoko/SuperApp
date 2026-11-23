// Deletes one user's KYC data. Dry run by default; pass --apply to delete.
//   node scripts/kyc-purge-user.js <sipUsername> [--apply]
// Removes the draft, documents (rows and stored files), submissions and notifications.
// Audit events are kept with their `data` emptied. AppUser.kyc is left untouched so the
// status history stays intact. Output is counts only: never names, ids or document content.
// Not scheduled; run by hand when the retention period (see docs/kyc.md) has passed.
const { canonicalUsername } = require('../lib/phone');

const loadModels = () => ({
  AppUser: require('../models/app_user.model'),
  KycDraft: require('../kyc/models/kyc_draft.model'),
  KycDocument: require('../kyc/models/kyc_document.model'),
  KycSubmission: require('../kyc/models/kyc_submission.model'),
  KycEvent: require('../kyc/models/kyc_event.model'),
  Notification: require('../kyc/models/notification.model'),
});

// Assumes mongoose is already connected. Resolves { found, applied, counts }.
async function purgeUser(sipUsername, { apply = false } = {}) {
  const { AppUser, KycDraft, KycDocument, KycSubmission, KycEvent, Notification } = loadModels();
  const appUser = await AppUser.findOne({ sipUsername: canonicalUsername(sipUsername) })
    .select('_id')
    .lean();
  if (!appUser) return { found: false, applied: false, counts: null };

  const appUserId = appUser._id;
  const counts = {
    drafts: await KycDraft.countDocuments({ appUserId }),
    documents: await KycDocument.countDocuments({ appUserId }),
    submissions: await KycSubmission.countDocuments({ appUserId }),
    notifications: await Notification.countDocuments({ appUserId }),
    events: await KycEvent.countDocuments({ appUserId }),
  };
  if (!apply) return { found: true, applied: false, counts };

  const { deleteStored } = require('../kyc/storage');
  // File first, then its row, so a failure part-way can simply be re-run.
  const docs = await KycDocument.find({ appUserId }).select('_id storageKey').lean();
  for (const doc of docs) {
    await deleteStored(doc.storageKey);
    await KycDocument.deleteOne({ _id: doc._id });
  }
  await KycDraft.deleteMany({ appUserId });
  await KycSubmission.deleteMany({ appUserId });
  await Notification.deleteMany({ appUserId });
  // Keep type, actor and createdAt; drop whatever the event carried.
  await KycEvent.updateMany({ appUserId }, { $set: { data: {} } });

  return { found: true, applied: true, counts };
}

async function main(argv) {
  const args = argv.slice(2);
  const apply = args.includes('--apply');
  const [sipUsername] = args.filter((a) => a !== '--apply');
  if (!sipUsername || !process.env.MONGO_URI) {
    process.stderr.write('Usage: MONGO_URI=... node scripts/kyc-purge-user.js <sipUsername> [--apply]\n');
    process.exitCode = 1;
    return;
  }

  const mongoose = require('mongoose');
  await mongoose.connect(process.env.MONGO_URI);
  try {
    const result = await purgeUser(sipUsername, { apply });
    if (!result.found) {
      process.stdout.write('No user with that username.\n');
      return;
    }
    process.stdout.write(`${apply ? 'Purged' : 'Dry run (nothing deleted)'}:\n`);
    for (const [name, n] of Object.entries(result.counts)) process.stdout.write(`  ${name}: ${n}\n`);
    if (!apply) process.stdout.write('Run again with --apply to delete.\n');
  } finally {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
  main(process.argv).catch((err) => {
    process.stderr.write(`Purge failed: ${err?.name}\n`);
    process.exit(1);
  });
}

module.exports = { purgeUser };
