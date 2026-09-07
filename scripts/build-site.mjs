import { cp, mkdir, rm, stat, writeFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { fileURLToPath, pathToFileURL } from 'node:url'
import path from 'node:path'
import { loadApps, selectApps } from './apps.mjs'

export async function buildSite(root, { prebuilt = false, args = [], reuseFrom } = {}) {
  const output = path.join(root, '.site')
  const appsFile = path.join(root, 'apps.json')
  const apps = await loadApps(appsFile)
  const selected = new Set(selectApps(apps, args).map(app => app.id))
  if (selected.size < apps.length && !reuseFrom) throw new Error('Unselected apps require --reuse-from')
  if (reuseFrom && (path.resolve(reuseFrom) === output || path.resolve(reuseFrom).startsWith(`${output}${path.sep}`))) {
    throw new Error('Reuse source must be outside .site')
  }

  // Validate every input before removing the old site. Never silently omit an app.
  for (const app of apps) {
    const source = selected.has(app.id) ? path.join(root, app.id, 'dist') : path.join(reuseFrom, app.id)
    if (!selected.has(app.id) || prebuilt) {
      if (!(await stat(path.join(source, 'index.html'))).isFile()) throw new Error(`Missing index.html for ${app.id}`)
    }
  }

  await rm(output, { recursive: true, force: true })
  await mkdir(output, { recursive: true })
  await cp(path.join(root, 'showcase'), output, { recursive: true })
  await cp(appsFile, path.join(output, 'apps.json'))
  await writeFile(path.join(output, '.nojekyll'), '')

  for (const app of apps) {
    if (!selected.has(app.id)) {
      console.log(`Reusing ${app.id} — ${app.name}`)
      await cp(path.join(reuseFrom, app.id), path.join(output, app.id), { recursive: true })
      continue
    }
    const appRoot = path.join(root, app.id)
    const appPackage = path.join(appRoot, 'package.json')

    try {
      await stat(appPackage)
    } catch {
      throw new Error(`Missing package.json for ${app.id}`)
    }

    if (!prebuilt) {
      console.log(`\nBuilding ${app.id} — ${app.name}`)
      const result = spawnSync('npm', ['run', 'build'], {
        cwd: appRoot,
        stdio: 'inherit',
        shell: process.platform === 'win32',
      })

      if (result.status !== 0) {
        throw new Error(`Build failed for ${app.id}`)
      }
    }

    await cp(path.join(appRoot, 'dist'), path.join(output, app.id), { recursive: true })
  }

  console.log(`\nShowcase ready: ${output}`)
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
  const args = process.argv.slice(2)
  const prebuiltIndex = args.indexOf('--prebuilt')
  const prebuilt = prebuiltIndex !== -1
  if (prebuilt) args.splice(prebuiltIndex, 1)
  const reuseIndex = args.indexOf('--reuse-from')
  let reuseFrom
  if (reuseIndex !== -1) {
    if (!args[reuseIndex + 1] || args[reuseIndex + 1].startsWith('--')) throw new Error('Missing --reuse-from directory')
    reuseFrom = path.resolve(args[reuseIndex + 1])
    args.splice(reuseIndex, 2)
  }
  await buildSite(root, { prebuilt, args, reuseFrom })
}
