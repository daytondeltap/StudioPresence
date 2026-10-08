const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createBridge, parseActivity, MAX_BODY_BYTES } = require('../src/server/bridge.ts');
const activity = (details = 'Developing') => ({ updateType: 'SET_ACTIVITY', activity: {
  details, state: 'Workspace: Test', timestamps: { start: 1700000000 },
  assets: { large_image: 'studio', large_text: 'StudioPresence', small_image: 'playtesticon', small_image_key: 'Testing' }
}});
async function fixture(t, rejectRPC = false) {
  const calls = [];
  const rpc = { setActivity: async a => { if (rejectRPC) throw new Error('offline'); calls.push(a); },
    clearActivity: async () => { if (rejectRPC) throw new Error('offline'); calls.push(null); } };
  // Reserve an ephemeral port to configure the expected Host.
  const reserve = http.createServer();
  await new Promise(resolve => reserve.listen(0, '127.0.0.1', resolve));
  const port = reserve.address().port;
  await new Promise(resolve => reserve.close(resolve));
  const server = createBridge(rpc, port);
  await new Promise(resolve => server.listen(port, '127.0.0.1', resolve));
  t.after(() => { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); });
  const send = (body, headers = {}, method = 'POST', path = '/', chunked = false) => new Promise((resolve, reject) => {
    const data = typeof body === 'string' ? body : JSON.stringify(body);
    const req = http.request({ host: '127.0.0.1', port, method, path, headers: {
      'Content-Type': 'application/json', ...(chunked ? {} : { 'Content-Length': Buffer.byteLength(data) }), ...headers
    }}, res => { res.resume(); res.on('end', () => resolve(res.statusCode)); });
    req.on('error', reject);
    req.end(data);
  });
  return { send, calls, server };
}
test('normal activity fields, legacy thumbnail and CLOSE preserved', async t => {
  const { send, calls, server } = await fixture(t);
  assert.equal(server.address().address, '127.0.0.1');
  assert.equal(await send(activity()), 200);
  assert.equal(calls[0].details, 'Developing');
  assert.equal(calls[0].smallImageText, 'Testing');
  assert.equal(calls[0].startTimestamp, 1700000000);
  assert.equal(await send({ updateType: 'CLOSE' }), 200);
  assert.equal(calls[1], null);
});
test('Testing debounce stays active; CLOSE bypasses it', async t => {
  const { send, calls } = await fixture(t);
  assert.equal(await send(activity('Testing')), 200);
  assert.equal(await send(activity()), 200);
  assert.equal(calls.length, 1);
  assert.equal(await send({ updateType: 'CLOSE' }), 200);
  assert.equal(calls[1], null);
});
test('malformed JSON or schema cannot clear activity or crash the bridge', async t => {
  const { send, calls } = await fixture(t);
  for (const input of ['{', 'null', '[]', '{}', { updateType: 'SET_ACTIVITY', activity: {} },
    { updateType: 'SET_ACTIVITY', activity: { ...activity().activity, timestamps: { start: -1 } } },
    activity('x'.repeat(129)), activity('bad\x1btext')]) assert.equal(await send(input), 400);
  assert.equal(calls.length, 0);
  assert.equal(await send(activity()), 200);
});
test('untrusted origins, DNS-rebinding Host, methods, routes and media types rejected', async t => {
  const { send, calls } = await fixture(t);
  assert.equal(await send(activity(), { Origin: 'https://evil.example' }), 403);
  assert.equal(await send(activity(), { 'Sec-Fetch-Site': 'cross-site' }), 403);
  assert.equal(await send(activity(), { Host: 'evil.example:4455' }), 403);
  assert.equal(await send(activity(), {}, 'GET'), 405);
  assert.equal(await send(activity(), {}, 'OPTIONS'), 405);
  assert.equal(await send(activity(), {}, 'POST', '/other'), 404);
  assert.equal(await send(activity(), { 'Content-Type': 'text/plain' }), 415);
  assert.equal(await send(activity(), { 'Content-Encoding': 'gzip' }), 415);
  assert.equal(calls.length, 0);
});
test('oversized declared and chunked requests rejected; bridge recovers', async t => {
  const { send, calls } = await fixture(t);
  assert.equal(await send('x'.repeat(MAX_BODY_BYTES + 1)), 413);
  assert.equal(await send('x'.repeat(MAX_BODY_BYTES + 1), {}, 'POST', '/', true), 413);
  assert.equal(calls.length, 0);
  assert.equal(await send(activity()), 200);
});
test('Discord rejection returns 503 and does not leave requests hanging', async t => {
  const { send } = await fixture(t, true);
  assert.equal(await send(activity()), 503);
  assert.equal(await send({ updateType: 'CLOSE' }), 503);
});
test('unknown request fields never reach RPC', () => {
  const input = activity();
  input.activity.command = 'some command';
  input.activity.assets.url = 'https://evil.example';
  const parsed = parseActivity(input);
  assert.equal(parsed.command, undefined);
  assert.equal(parsed.url, undefined);
});
