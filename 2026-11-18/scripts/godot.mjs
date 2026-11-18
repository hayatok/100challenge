import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { root, engineBinary } from './engine.mjs';

const command = process.argv[2];
const project = path.join(root, 'game');
const dist = path.join(root, 'dist');
const engine = engineBinary();
const modes = {
  editor: ['--editor'],
  play: [],
  import: ['--headless', '--editor', '--import'],
  test: ['--headless', '--script', 'res://race/tests/simulation_test.gd'],
  models: ['--headless', '--script', path.join(root, 'modeling', 'test_import.gd')],
  build: ['--headless', '--export-release', 'Web', path.join(dist, 'index.html')],
};
if (!Object.hasOwn(modes, command)) throw new Error('Unknown Godot command');
if (command === 'build') mkdirSync(dist, { recursive: true });
const interactive = command === 'editor' || command === 'play';
const result = spawnSync(engine, ['--path', project, ...modes[command]], {
  stdio: interactive ? 'inherit' : 'pipe',
  encoding: 'utf8',
  maxBuffer: 32 * 1024 * 1024,
});
const output = (result.stdout ?? '') + (result.stderr ?? '');
if (result.error || result.status !== 0 || /SCRIPT ERROR:|^ERROR:|^FAIL:/m.test(output)) {
  process.stderr.write(output);
  throw result.error || new Error('Godot ' + command + ' failed');
}
if (command === 'test' || command === 'models') process.stdout.write(output);
if (command === 'build') {
  copyFileSync(path.join(project, 'media', 'cover.jpg'), path.join(dist, 'cover.jpg'));
  for (const name of ['GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt']) {
    copyFileSync(path.join(root, name), path.join(dist, name));
  }
  copyFileSync(path.join(project, 'media', 'NOTO-OFL.txt'), path.join(dist, 'NOTO-OFL.txt'));
}
console.log('Godot ' + command + ' complete');
