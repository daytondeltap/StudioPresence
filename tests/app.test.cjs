const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { mkdtempSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { spawn } = require('node:child_process');

test('compiled app: IPC handshake and presence/close roundtrip', { timeout: 15000 }, async t => {
  if (process.platform === 'win32') return t.skip('Unix mock IPC test');
  const dir = mkdtempSync(join(tmpdir(), 'studiopresence-ipc-'));
  const commands = [];
  const sockets = new Set();
  const mock = net.createServer(socket => {
    sockets.add(socket);
    socket.on('error', () => {});
    let buffered = Buffer.alloc(0);
    const frame = data => {
      const body = Buffer.from(JSON.stringify(data));
      const head = Buffer.alloc(8); head.writeInt32LE(1, 0); head.writeInt32LE(body.length, 4);
      socket.write(Buffer.concat([head, body]));
    };
    socket.on('data', bytes => {
      buffered = Buffer.concat([buffered, bytes]);
      while (buffered.length >= 8) {
        const opcode = buffered.readInt32LE(0), length = buffered.readInt32LE(4);
        if (buffered.length < length + 8) break;
        const data = JSON.parse(buffered.subarray(8, length + 8));
        buffered = buffered.subarray(length + 8);
        if (opcode === 0) frame({ cmd: 'DISPATCH', evt: 'READY', data: { user: { id: '123', username: 'test' } } });
        else if (opcode === 1) {
          commands.push(data);
          frame({ cmd: data.cmd, nonce: data.nonce, data: {} });
        }
      }
    });
  });
  try {
    await new Promise((resolve, reject) => {
      mock.once('error', reject);
      mock.listen(join(dir, 'discord-ipc-0'), resolve);
    });
  } catch (error) {
    rmSync(dir, { recursive: true, force: true });
    if (error.code === 'EPERM' && !process.env.CI) return t.skip('Environment forbids Unix sockets; CI runs this check');
    throw error;
  }
  const child = process.env.STUDIOPRESENCE_TEST_BINARY
    ? spawn(process.env.STUDIOPRESENCE_TEST_BINARY, [], { env: { ...process.env, XDG_RUNTIME_DIR: dir } })
    : spawn(process.execPath, ['dist/server/index.js'], { env: { ...process.env, XDG_RUNTIME_DIR: dir } });
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill(); await new Promise(resolve => child.once('exit', resolve));
    }
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => mock.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  });
  await new Promise((resolve, reject) => {
    let output = '';
    child.stdout.on('data', data => { output += data; if (output.includes('StudioPresence Started!')) resolve(); });
    child.stderr.on('data', data => { output += data; });
    child.once('error', reject);
    child.once('exit', code => reject(new Error(`app exited ${code}: ${output}`)));
  });
  const send = body => fetch('http://127.0.0.1:4455/', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
  });
  const result = await send({ updateType: 'SET_ACTIVITY', activity: {
    details: 'Editing test (Line 1 / 4)', state: 'Workspace: Audit', timestamps: { start: 1700000000 },
    assets: { large_image: 'modulescript', large_text: 'Editing a MODULE Script', small_image: 'none', small_text: 'none' }
  }});
  assert.equal(result.status, 200);
  assert.equal(commands[0].cmd, 'SET_ACTIVITY');
  assert.equal(commands[0].args.activity.details, 'Editing test (Line 1 / 4)');
  assert.equal(commands[0].args.activity.assets.large_image, 'modulescript');
  assert.equal((await send({ updateType: 'CLOSE' })).status, 200);
  assert.equal(commands[1].args.activity, undefined);
});
