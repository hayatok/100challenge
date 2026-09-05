import { readFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { loadApps } from './apps.mjs'

const commands = {
  // Bound registry/audit outages without disabling npm's audit request.
  ci: ['ci', '--fetch-timeout=15000', '--fetch-retries=1', '--fetch-retry-mintimeout=1000', '--fetch-retry-maxtimeout=3000'],
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

  // Optional app-owned tooling, such as Godot and its export templates.
  if (commandName === 'ci') {
    const pkg = JSON.parse(await readFile(path.join(root, app.id, 'package.json'), 'utf8'))
    if (pkg.scripts?.setup) {
      const setup = spawnSync('npm', ['run', 'setup'], { cwd: path.join(root, app.id), stdio: 'inherit', shell: process.platform === 'win32' })
      if (setup.status !== 0) throw new Error(`Setup failed for ${app.id}`)
    }
  }
}
