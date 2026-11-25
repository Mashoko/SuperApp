const path = require('path');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const verifier = require('../africom/verifier');

const def = protoLoader.loadSync(path.join(__dirname, '..', 'protos', 'users.proto'), {
  keepCase: true,
  enums: String,
  defaults: true,
});
const users = grpc.loadPackageDefinition(def).users;

let server;
let handler;
let port;
const seen = [];

const bind = (srv) =>
  new Promise((resolve, reject) => {
    srv.bindAsync('127.0.0.1:0', grpc.ServerCredentials.createInsecure(), (err, p) =>
      err ? reject(err) : resolve(p)
    );
  });

const ENV_KEYS = ['AFRICOM_GRPC_HOST', 'AFRICOM_GRPC_PORT', 'AFRICOM_GRPC_SECURE'];

beforeAll(async () => {
  server = new grpc.Server();
  server.addService(users.userService.service, {
    AccountBalance: (call, cb) => handler(call, cb),
  });
  port = await bind(server);
  process.env.AFRICOM_GRPC_HOST = '127.0.0.1';
  process.env.AFRICOM_GRPC_SECURE = 'false';
});

afterAll(async () => {
  ENV_KEYS.forEach((k) => delete process.env[k]);
  await new Promise((r) => server.tryShutdown(() => r()));
});

beforeEach(() => {
  seen.length = 0;
  process.env.AFRICOM_GRPC_PORT = String(port);
  handler = (call, cb) => {
    seen.push(call.request);
    cb(null, { status: 'SUCCESS' });
  };
});

describe('verifyCredentials', () => {
  test('returns ok for SUCCESS status', async () => {
    const r = await verifier.verifyCredentials('263770000000', 'secret');
    expect(r).toEqual({ ok: true, username: '263770000000' });
    expect(seen[0]).toMatchObject({
      username: '263770000000',
      password: 'secret',
      package_id: 'org.duri.maswerasei',
      domain: 'localvoip.ai.co.zw',
    });
  });

  test('returns invalid for ERROR status', async () => {
    handler = (call, cb) => cb(null, { status: 'ERROR' });
    const r = await verifier.verifyCredentials('263770000000', 'bad');
    expect(r).toEqual({ ok: false, reason: 'invalid' });
  });

  test('retries without plus and returns stripped username', async () => {
    handler = (call, cb) => {
      seen.push(call.request);
      cb(null, { status: call.request.username === '263770000000' ? 'SUCCESS' : 'ERROR' });
    };
    const r = await verifier.verifyCredentials('+263770000000', 'secret');
    expect(r).toEqual({ ok: true, username: '263770000000' });
    expect(seen.map((s) => s.username)).toEqual(['+263770000000', '263770000000']);
  });

  test('treats server-side gRPC faults as unavailable, not invalid', async () => {
    handler = (call, cb) => cb({ code: grpc.status.INTERNAL, message: 'boom' });
    const r = await verifier.verifyCredentials('+263770000000', 'secret');
    expect(r).toEqual({ ok: false, reason: 'unavailable' });
  });

  test('returns unavailable when server is down', async () => {
    const tmp = new grpc.Server();
    const closedPort = await bind(tmp);
    await new Promise((r) => tmp.tryShutdown(() => r()));
    process.env.AFRICOM_GRPC_PORT = String(closedPort);
    const r = await verifier.verifyCredentials('263770000000', 'secret', { deadlineMs: 1500 });
    expect(r).toEqual({ ok: false, reason: 'unavailable' });
  });

  test('setVerifierForTests swaps and restores the implementation', async () => {
    verifier.setVerifierForTests(async () => ({ ok: false, reason: 'invalid' }));
    expect(await verifier.verifyCredentials('x', 'y')).toEqual({ ok: false, reason: 'invalid' });
    verifier.setVerifierForTests(null);
    expect((await verifier.verifyCredentials('263770000000', 's')).ok).toBe(true);
  });
});
