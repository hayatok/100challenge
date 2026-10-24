import {spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, copyFileSync, readFileSync, chmodSync, renameSync, rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import os from 'node:os';
import path from 'node:path';
import {root, version, engineBinary, linuxBinaryName} from './engine.mjs';

const cache = path.join(root, '.cache');
const base = `https://github.com/godotengine/godot/releases/download/${version}-stable/`;
mkdirSync(cache, {recursive: true});

function run(binary, args) {
  const result = spawnSync(binary, args, {stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${binary} failed (${result.signal || result.status}).`);
}

function fetchFile(name) {
  const target = path.join(cache, name);
  if (!existsSync(target)) {
    const partial = `${target}.partial`;
    run('curl', ['--fail', '--location', '--retry', '2', '--connect-timeout', '20', base + name, '--output', partial]);
    renameSync(partial, target);
  }
  return target;
}

function verifiedDownload(name) {
  const sums = readFileSync(fetchFile('SHA512-SUMS.txt'), 'utf8');
  const entry = sums.split(/\r?\n/).map(line => line.trim().split(/\s+/)).find(parts => parts[1]?.replace(/^\*/, '') === name);
  const expected = entry?.[0]?.toLowerCase();
  if (!expected || !/^[a-f0-9]{128}$/.test(expected)) throw new Error(`No official SHA512 entry for ${name}.`);
  const archive = fetchFile(name);
  const actual = createHash('sha512').update(readFileSync(archive)).digest('hex');
  if (actual !== expected) {
    rmSync(archive);
    throw new Error(`Official SHA512 mismatch for ${name}; the invalid cached archive was removed.`);
  }
  console.log(`Verified official SHA512: ${name}`);
  return archive;
}

try {
  engineBinary();
} catch (error) {
  if (process.env.GODOT_BIN || process.platform !== 'linux' || process.arch !== 'x64') throw error;
  run('unzip', ['-oq', verifiedDownload(`${linuxBinaryName}.zip`), '-d', cache]);
  chmodSync(path.join(cache, linuxBinaryName), 0o755);
  engineBinary();
}

const userData = process.platform === 'darwin' ? path.join(os.homedir(), 'Library/Application Support')
  : process.platform === 'win32' ? (process.env.APPDATA || path.join(os.homedir(), 'AppData/Roaming'))
  : (process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local/share'));
const templates = path.join(userData, process.platform === 'linux' ? 'godot' : 'Godot', 'export_templates', `${version}.stable`);
const names = ['web_nothreads_debug.zip', 'web_nothreads_release.zip', 'version.txt'];
if (!names.every(name => existsSync(path.join(templates, name)))) {
  const archive = verifiedDownload(`Godot_v${version}-stable_export_templates.tpz`);
  run('unzip', ['-oq', archive, ...names.map(name => `templates/${name}`), '-d', cache]);
  mkdirSync(templates, {recursive: true});
  for (const name of names) copyFileSync(path.join(cache, 'templates', name), path.join(templates, name));
}
console.log(`Godot ${version} and single-thread Web templates are ready.`);
