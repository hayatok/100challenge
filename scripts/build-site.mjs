import { cp, mkdir, rm, stat, writeFile } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { loadApps } from './apps.mjs'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const output = path.join(root, '.site')
const appsFile = path.join(root, 'apps.json')
const apps = await loadApps(appsFile)

await rm(output, { recursive: true, force: true })
await mkdir(output, { recursive: true })
await cp(path.join(root, 'showcase'), output, { recursive: true })
await cp(appsFile, path.join(output, 'apps.json'))
await writeFile(path.join(output, '.nojekyll'), '')

for (const app of apps) {
  const appRoot = path.join(root, app.id)
  const appPackage = path.join(appRoot, 'package.json')

  try {
    await stat(appPackage)
  } catch {
    throw new Error(`Missing package.json for ${app.id}`)
  }

  console.log(`\nBuilding ${app.id} — ${app.name}`)
  const result = spawnSync('npm', ['run', 'build'], {
    cwd: appRoot,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  })

  if (result.status !== 0) {
    throw new Error(`Build failed for ${app.id}`)
  }

  await cp(path.join(appRoot, 'dist'), path.join(output, app.id), { recursive: true })
}

console.log(`\nShowcase ready: ${output}`)
