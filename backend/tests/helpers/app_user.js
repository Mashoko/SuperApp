const AppUser = require('../../models/app_user.model');
const { signAppToken } = require('../../middleware/auth.middleware');

// Inserts an AppUser directly (bypassing Mongoose timestamps so a past createdAt sticks)
// and returns it with a signed app session token.
async function createAppUserWithToken({ sipUsername, createdAt = new Date(), kyc = {} }) {
  const { insertedId } = await AppUser.collection.insertOne({
    sipUsername,
    kyc: { status: 'NOT_STARTED', cycle: 0, lastReminderStage: null, ...kyc },
    createdAt,
    updatedAt: createdAt,
  });
  const appUser = await AppUser.findById(insertedId);
  return { appUser, token: signAppToken(appUser) };
}

module.exports = { createAppUserWithToken };
