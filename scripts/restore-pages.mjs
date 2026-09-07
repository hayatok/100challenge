import { mkdir, rm, writeFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const execute = (command, args) => execFileSync(command, args, {
  encoding: 'utf8', timeout: 120_000, maxBuffer: 16 * 1024 * 1024,
  stdio: ['ignore', 'pipe', 'pipe'],
})

// Only completed, successful runs of the deployment workflow are trusted.
// Branch/tag caches cannot reliably share outputs between release tags.
export async function restorePages(root, { repository, runId, force = false, executeCommand = execute } = {}) {
  const destination = path.join(root, '.pages-baseline')
  await rm(destination, { recursive: true, force: true })
  if (force) return null
  let phase = 'workflow lookup'
  try {
    if (!/^[\w.-]+\/[\w.-]+$/.test(repository ?? '')) throw new Error('Missing repository')
    const api = endpoint => JSON.parse(executeCommand('gh', ['api', endpoint]))
    // A bounded lookup is sufficient: no usable recent baseline means a full build.
    const { workflow_runs: runs } = api(`repos/${repository}/actions/workflows/deploy-pages.yml/runs?status=success&per_page=20`)
    for (const run of runs) {
      if (String(run.id) === String(runId) || run.status !== 'completed' || run.conclusion !== 'success') continue
      if (!['push', 'workflow_dispatch'].includes(run.event) || run.repository?.full_name !== repository || run.head_repository?.full_name !== repository) continue
      if (!/^[a-f0-9]{40,64}$/i.test(run.head_sha)) continue
      phase = 'artifact lookup'
      const { artifacts } = api(`repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`)
      if (!artifacts.some(artifact => artifact.name === 'github-pages' && !artifact.expired)) continue
      await mkdir(path.join(destination, 'download'), { recursive: true })
      await mkdir(path.join(destination, 'site'), { recursive: true })
      phase = 'artifact download'
      executeCommand('gh', ['run', 'download', String(run.id), '--repo', repository, '--name', 'github-pages', '--dir', path.join(destination, 'download')])
      phase = 'artifact extraction'
      executeCommand('tar', ['-xf', path.join(destination, 'download', 'artifact.tar'), '-C', path.join(destination, 'site')])
      const source = { sha: run.head_sha, runId: run.id }
      // Write provenance only after the download and extraction both succeed.
      await writeFile(path.join(destination, 'source.json'), JSON.stringify(source))
      await rm(path.join(destination, 'download'), { recursive: true, force: true })
      console.log(`Restored Pages run ${run.id} at ${run.head_sha}`)
      return source
    }
    console.log('No retained successful Pages artifact; rebuilding all apps.')
  } catch {
    // Do not expose CLI output (which may contain signed download URLs).
    console.warn(`Pages baseline unavailable during ${phase}; rebuilding all apps.`)
  }
  await rm(destination, { recursive: true, force: true })
  return null
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
  await restorePages(root, { repository: process.env.GITHUB_REPOSITORY, runId: process.env.GITHUB_RUN_ID, force: process.env.FORCE_FULL === 'true' })
}
