import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const blender = process.env.BLENDER_BIN || 'blender';
const version = spawnSync(blender, ['--version'], {encoding: 'utf8'});
if (version.status !== 0) throw Error('Install Blender (sources were made with 4.3.2), or set BLENDER_BIN.');
console.log(version.stdout.split('\n')[0]);
const {models} = JSON.parse(readFileSync(path.join(root, 'scripts/modeling/models.json'), 'utf8'));
for (const generator of new Set(models.map(model => model.generator))) {
  const result = spawnSync(blender, ['--background', '--factory-startup', '--python', generator], {cwd: root, stdio: 'inherit'});
  if (result.status !== 0) process.exit(result.status || 1);
}
const check = spawnSync('python3', ['scripts/modeling/check_models.py'], {cwd: root, stdio: 'inherit'});
process.exit(check.status || 0);
