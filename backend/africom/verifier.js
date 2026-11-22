const path = require('path');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

const DEFAULT_DEADLINE_MS = 8000;

const packageDefinition = protoLoader.loadSync(
  path.join(__dirname, '..', 'protos', 'users.proto'),
  { keepCase: true, enums: String, defaults: true }
);
const UserService = grpc.loadPackageDefinition(packageDefinition).users.userService;

function config() {
  return {
    host: process.env.AFRICOM_GRPC_HOST || 'wss.durihub.co.zw',
    port: process.env.AFRICOM_GRPC_PORT || '50000',
    secure: process.env.AFRICOM_GRPC_SECURE === 'true',
    packageId: process.env.AFRICOM_PACKAGE_ID || 'org.duri.maswerasei',
    domain: process.env.AFRICOM_DOMAIN || 'localvoip.ai.co.zw',
  };
}

// Resolves 'success' | 'invalid' | 'unavailable'. Never throws.
function checkOnce(cfg, username, password, deadlineMs) {
  return new Promise((resolve) => {
    const creds = cfg.secure
      ? grpc.credentials.createSsl()
      : grpc.credentials.createInsecure();
    const client = new UserService(`${cfg.host}:${cfg.port}`, creds);
    const done = (result) => {
      client.close();
      resolve(result);
    };
    try {
      client.AccountBalance(
        { username, password, package_id: cfg.packageId, domain: cfg.domain },
        { deadline: Date.now() + deadlineMs },
        (err, res) => {
          if (err) return done('unavailable');
          done(res && res.status === 'SUCCESS' ? 'success' : 'invalid');
        }
      );
    } catch (e) {
      done('unavailable');
    }
  });
}

async function realVerify(username, password, options = {}) {
  const cfg = config();
  const deadlineMs = options.deadlineMs || DEFAULT_DEADLINE_MS;

  let outcome = await checkOnce(cfg, username, password, deadlineMs);
  if (outcome === 'success') return { ok: true, username };

  if (outcome === 'invalid' && username.startsWith('+')) {
    const stripped = username.replace(/^\+/, '');
    outcome = await checkOnce(cfg, stripped, password, deadlineMs);
    if (outcome === 'success') return { ok: true, username: stripped };
  }
  return { ok: false, reason: outcome };
}

let impl = realVerify;

function verifyCredentials(username, password, options) {
  return impl(username, password, options);
}

function setVerifierForTests(fn) {
  impl = fn || realVerify;
}

module.exports = { verifyCredentials, setVerifierForTests };
