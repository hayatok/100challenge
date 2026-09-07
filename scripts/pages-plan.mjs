import { appendFile, readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { loadApps } from './apps.mjs'
import { detectChanges } from './changed-apps.mjs'

export async function planPages(root, { force = false } = {}) {
  const apps = await loadApps(path.join(root, 'apps.json'))
  const all = reason => ({ apps: apps.map(app => app.id), full: true, reason })
  if (force) return all('Forced full rebuild')
  let source
  try {
    source = JSON.parse(await readFile(path.join(root, '.pages-baseline/source.json'), 'utf8'))
  } catch {
    return all('No usable Pages baseline')
  }
  const plan = await detectChanges(root, source?.sha)
  const selected = new Set(plan.apps)
  for (const app of apps) {
    if (selected.has(app.id)) continue
    try {
      if (!(await stat(path.join(root, '.pages-baseline/site', app.id, 'index.html'))).isFile()) throw new Error('Not a file')
    } catch {
      selected.add(app.id)
    }
  }
  return { ...plan, apps: apps.filter(app => selected.has(app.id)).map(app => app.id), base: source?.sha, runId: source?.runId }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
  const plan = await planPages(root, { force: process.env.FORCE_FULL === 'true' })
  console.log(JSON.stringify(plan, null, 2))
  if (process.env.GITHUB_OUTPUT) await appendFile(process.env.GITHUB_OUTPUT, `apps=${JSON.stringify(plan.apps)}\nfull=${plan.full}\n`)
  if (process.env.GITHUB_STEP_SUMMARY) {
    const total = (await loadApps(path.join(root, 'apps.json'))).length
    await appendFile(process.env.GITHUB_STEP_SUMMARY, `## Pages build plan\n\n- Baseline: ${plan.runId ?? 'none'} (${plan.base ?? 'full rebuild'})\n- Check/build: ${plan.apps.length}/${total}\n- Reuse: ${total - plan.apps.length}/${total}\n- Reason: ${plan.reason}\n\n${plan.apps.map(id => `- ${id}`).join('\n')}\n`)
  }
}
