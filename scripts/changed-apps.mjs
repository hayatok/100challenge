import { appendFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { appIdPattern, loadApps } from './apps.mjs'

export function planChanges(paths, apps, previousApps) {
  const selected = new Set()
  const previous = new Map(previousApps.map(app => [app.id, app]))
  const ids = new Set(apps.map(app => app.id))
  for (const file of paths) {
    const directory = file.split('/')[0]
    if (appIdPattern.test(directory)) {
      if (ids.has(directory)) selected.add(directory)
    } else if (file === 'apps.json') {
      for (const app of apps) {
        if (JSON.stringify(previous.get(app.id)) !== JSON.stringify(app)) selected.add(app.id)
      }
    } else if (!file.endsWith('.md') && !/^scripts\/[^/]+\.test\.mjs$/.test(file)) {
      return { apps: [...ids], full: true, reason: `Shared change: ${file}` }
    }
  }
  return { apps: apps.filter(app => selected.has(app.id)).map(app => app.id), full: false, reason: 'Changed app directories and catalog entries' }
}

export async function detectChanges(root, base) {
  const apps = await loadApps(path.join(root, 'apps.json'))
  const all = reason => ({ apps: apps.map(app => app.id), full: true, reason })
  // Only a commit ID is accepted; never interpret event data as git options or shell code.
  if (!/^[a-f0-9]{40,64}$/i.test(base ?? '') || /^0+$/.test(base)) return all('No usable base commit')
  const git = args => spawnSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 })
  const diff = git(['diff', '--name-only', '--no-renames', '-z', base, 'HEAD', '--'])
  const catalog = git(['show', `${base}:apps.json`])
  if (diff.status !== 0 || catalog.status !== 0) return all('Base commit or catalog is unavailable')
  let previous
  try { previous = JSON.parse(catalog.stdout) } catch { return all('Base catalog is invalid') }
  if (!Array.isArray(previous) || previous.some(app => !app || !appIdPattern.test(app.id))) return all('Base catalog is invalid')
  // --no-renames includes both the removed and added paths of a moved file.
  return planChanges(diff.stdout.split('\0').filter(Boolean), apps, previous)
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
  const plan = await detectChanges(root, process.argv[2])
  console.log(JSON.stringify(plan, null, 2))
  if (process.env.GITHUB_OUTPUT) {
    await appendFile(process.env.GITHUB_OUTPUT, `apps=${JSON.stringify(plan.apps)}\nfull=${plan.full}\n`)
  }
}
