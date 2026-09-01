import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { loadApps } from './apps.mjs'

const commands = {
  ci: ['ci'],
  check: ['run', 'check'],
}

const commandName = process.argv[2]
const command = commands[commandName]

if (!command) {
  throw new Error(`Unsupported app command: ${commandName ?? '(missing)'}`)
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const apps = await loadApps(path.join(root, 'apps.json'))

for (const app of apps) {
  console.log(`\nRunning npm ${command.join(' ')} in ${app.id} — ${app.name}`)
  const result = spawnSync('npm', command, {
    cwd: path.join(root, app.id),
    stdio: 'inherit',
    shell: process.platform === 'win32',
  })

  if (result.status !== 0) {
    throw new Error(`npm ${command.join(' ')} failed for ${app.id}`)
  }
}
