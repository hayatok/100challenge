import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { root, engineBinary } from './engine.mjs';

const command = process.argv[2];
const dist = path.join(root, 'dist');
const modes = {
  editor: ['--editor'], play: [], import: ['--headless', '--editor', '--import'],
  test: ['--headless','--script','res://tests/campaign.gd'],
  rush: ['--headless','--script','res://tests/rush_rules.gd'],
  arcade: ['--headless','--script','res://tests/rush_voyage.gd'],
  combat: ['--headless','--script','res://combat/test_combat.gd'],
  build: ['--headless','--export-release','Web',path.join(dist,'index.html')]
};
if (!Object.hasOwn(modes, command)) throw new Error('Unknown Godot command');
if (command === 'build') mkdirSync(dist, {recursive: true});
const result = spawnSync(engineBinary(), ['--path',path.join(root,'game'),...modes[command]], {
  encoding:'utf8', maxBuffer:32 * 1024 * 1024,
  stdio: ['editor','play'].includes(command) ? 'inherit' : 'pipe'
});
const log = (result.stdout || '') + (result.stderr || '');
if (result.error || result.status !== 0 || /SCRIPT ERROR:|^ERROR:|^FAIL:/m.test(log)) {
  process.stderr.write(log);
  throw result.error || new Error('Godot ' + command + ' failed');
}
if (['test','combat','rush','arcade'].includes(command)) process.stdout.write(log);
if (command === 'build') {
  for (const name of ['GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']) copyFileSync(path.join(root,name),path.join(dist,name));
  for (const [source,dest] of [['title.jpg','cover.jpg'],['NOTO-OFL.txt','NOTO-OFL.txt']]) {
    copyFileSync(path.join(root,'game','media',source),path.join(dist,dest));
  }
}
console.log('Godot ' + command + ' complete');
