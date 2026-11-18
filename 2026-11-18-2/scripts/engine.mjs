import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const version = '4.7.2';
export const linuxBinaryName = `Godot_v${version}-stable_linux.x86_64`;

export function engineBinary() {
  const candidates = process.env.GODOT_BIN ? [process.env.GODOT_BIN] : [
    ...(process.platform === 'darwin' ? ['/Applications/Godot.app/Contents/MacOS/Godot'] : []),
    path.join(root, '.cache', linuxBinaryName),
    'godot',
  ];
  for (const binary of candidates) {
    if (binary.includes(path.sep) && !existsSync(binary)) continue;
    const result = spawnSync(binary, ['--version'], {encoding: 'utf8', timeout: 10000});
    if (result.status === 0 && result.stdout.trim().startsWith(`${version}.stable.`)) return binary;
  }
  throw new Error(`Godot ${version}-stable is required. Run npm run setup or set GODOT_BIN to that version.`);
}
