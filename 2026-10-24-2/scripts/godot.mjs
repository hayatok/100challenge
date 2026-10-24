import {spawn, spawnSync} from 'node:child_process';
import {mkdirSync, copyFileSync, readdirSync, existsSync} from 'node:fs';
import path from 'node:path';
import {root, engineBinary, version} from './engine.mjs';

const binary = engineBinary();
const mode = process.argv[2];
const project = path.join(root, 'game');
const dist = path.join(root, 'dist');

function run(args, timeout = 180000) {
  const result = spawnSync(binary, ['--headless', '--path', project, ...args], {
    encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  if (output) process.stdout.write(output);
  if (result.error) throw result.error;
  // GDScript can log a fatal script error and still make the engine exit 0.
  if (result.status !== 0 || /SCRIPT ERROR|ERROR:|FAIL/.test(output)) {
    throw new Error(`Godot task failed: ${args.join(' ')} (${result.signal || result.status}).`);
  }
}

function importProject() {
  run(['--editor', '--import'], 300000);
}

function findTests(directory) {
  return readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) return findTests(file);
    return entry.isFile() && entry.name.endsWith('_test.gd') ? [file] : [];
  }).sort();
}

function testProject() {
  const tests = findTests(path.join(project, 'tests'));
  if (!tests.length) throw new Error('No game/tests/**/*_test.gd tests were found.');
  for (const test of tests) {
    const resource = 'res://' + path.relative(project, test).split(path.sep).join('/');
    console.log(`Testing ${resource}`);
    run(['--script', resource]);
  }
  console.log(`${tests.length} Godot test scripts passed.`);
}

function buildProject() {
  mkdirSync(dist, {recursive: true});
  run(['--export-release', 'Web', path.join(dist, 'index.html')], 300000);
  for (const extension of ['html', 'js', 'wasm', 'pck']) {
    if (!existsSync(path.join(dist, `index.${extension}`))) throw new Error(`Missing Web output: index.${extension}`);
  }
  const licenses = path.join(dist, 'licenses');
  mkdirSync(licenses, {recursive: true});
  for (const [source, target] of [
    ['docs/licenses/GODOT-LICENSE.txt', 'GODOT-LICENSE.txt'],
    ['game/assets/fonts/NOTO-LICENSE.txt', 'NOTO-LICENSE.txt'],
    ['game/assets/fonts/DEJAVU-LICENSE.txt', 'DEJAVU-LICENSE.txt'],
  ]) copyFileSync(path.join(root, source), path.join(licenses, target));
  copyFileSync(path.join(root, 'docs/verification/rework/web-carve-release.jpg'), path.join(dist, 'thumbnail.jpg'));
  console.log(`Godot ${version}: single-thread Web build ready at dist/index.html`);
}

if (mode === 'editor' || mode === 'play') {
  const child = spawn(binary, ['--path', project, ...(mode === 'editor' ? ['--editor'] : [])], {stdio: 'inherit'});
  child.on('error', error => { console.error(error); process.exitCode = 1; });
  child.on('exit', code => { process.exitCode = code ?? 1; });
} else if (['import', 'test', 'build', 'check'].includes(mode)) {
  importProject();
  if (mode === 'test' || mode === 'check') testProject();
  if (mode === 'build' || mode === 'check') buildProject();
} else {
  throw new Error(`Unknown mode: ${mode}. Use editor, play, import, test, build, or check.`);
}
