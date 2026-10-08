const { readFileSync, writeFileSync, unlinkSync } = require('node:fs');
const { spawnSync } = require('node:child_process');
const luau = process.argv[2] || 'luau';
const generated = 'tests/standalone/.generated-studio-test.luau';
function run(file) {
  const result = spawnSync(luau, [file], { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Standalone test failed: ${file}`);
}
try {
  run('tests/standalone/core.test.luau');
  writeFileSync(generated, readFileSync('tests/standalone/studio-fixture.luau', 'utf8')
    .replace('-- ENTRY_POINT', readFileSync('src/standalone/main.server.luau', 'utf8')));
  run(generated);
} finally {
  try { unlinkSync(generated); } catch (error) { if (error.code !== 'ENOENT') throw error; }
}
