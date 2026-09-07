import assert from 'node:assert/strict'
import test from 'node:test'
import { mkdtemp, mkdir, writeFile, readFile, rm, stat } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { buildSite } from './build-site.mjs'
import { planPages } from './pages-plan.mjs'
import { restorePages } from './restore-pages.mjs'

const a = { id: '2026-09-06', date: '2026-09-06', sequence: 1, name: 'A' }
const b = { ...a, id: '2026-09-06-2', sequence: 2, name: 'B' }
const c = { ...a, id: '2026-09-07', date: '2026-09-07', name: 'C' }

async function fixture(t) {
  const root = await mkdtemp(path.join(tmpdir(), 'pages-incremental-'))
  t.after(() => rm(root, { recursive: true, force: true }))
  const save = async (file, content) => {
    await mkdir(path.dirname(path.join(root, file)), { recursive: true })
    await writeFile(path.join(root, file), content)
  }
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
  git('init', '--quiet')
  git('config', 'user.name', 'Pages test')
  git('config', 'user.email', 'test@example.invalid')
  await save('.gitignore', '.site/\n.pages-baseline/\n*/dist/\n')
  await save('apps.json', JSON.stringify([a, b]))
  await save('showcase/index.html', 'current showcase')
  for (const app of [a, b]) {
    // Fails if prebuilt assembly accidentally calls build again.
    await save(`${app.id}/package.json`, JSON.stringify({ scripts: { build: 'exit 99' } }))
    await save(`${app.id}/source.txt`, 'old source')
    await save(`${app.id}/dist/index.html`, `${app.name} checked`)
    await save(`.pages-baseline/site/${app.id}/index.html`, `${app.name} previous`)
    await save(`.pages-baseline/site/${app.id}/assets/old.wasm`, `${app.name} wasm`)
  }
  const commit = () => { git('add', '-A'); git('commit', '--quiet', '-m', 'change'); return git('rev-parse', 'HEAD') }
  const base = commit()
  await save('.pages-baseline/source.json', JSON.stringify({ sha: base, runId: 10 }))
  return { root, save, git, commit, base, reuseFrom: path.join(root, '.pages-baseline/site') }
}
const options = (f, apps) => ({ prebuilt: true, args: ['--apps-json', JSON.stringify(apps)], reuseFrom: f.reuseFrom })
const read = (f, file) => readFile(path.join(f.root, file), 'utf8')

test('one changed app uses its checked dist once and preserves the other app byte for byte', async t => {
  const f = await fixture(t)
  await f.save(`${b.id}/source.txt`, 'changed')
  f.commit()
  const plan = await planPages(f.root)
  assert.deepEqual(plan.apps, [b.id])
  await buildSite(f.root, options(f, plan.apps))
  assert.equal(await read(f, `.site/${a.id}/index.html`), 'A previous')
  assert.equal(await read(f, `.site/${a.id}/assets/old.wasm`), 'A wasm')
  assert.equal(await read(f, `.site/${b.id}/index.html`), 'B checked')
  await assert.rejects(stat(path.join(f.root, '.site', b.id, 'assets/old.wasm')), { code: 'ENOENT' })
  assert.equal(await read(f, '.site/index.html'), 'current showcase')
  assert.equal(await read(f, '.site/.nojekyll'), '')
})
test('no changes reuse all apps, without needing local dependencies, package or dist', async t => {
  const f = await fixture(t)
  assert.deepEqual((await planPages(f.root)).apps, [])
  await rm(path.join(f.root, a.id), { recursive: true })
  await rm(path.join(f.root, b.id), { recursive: true })
  await buildSite(f.root, options(f, []))
  assert.equal(await read(f, `.site/${b.id}/index.html`), 'B previous')
})
test('new app builds, removed apps and stale root files disappear', async t => {
  const f = await fixture(t)
  await f.save('apps.json', JSON.stringify([a, c]))
  await f.save(`${c.id}/package.json`, '{}')
  await f.save(`${c.id}/dist/index.html`, 'C checked')
  await f.save('.site/obsolete.js', 'old root')
  await f.save(`.site/${b.id}/index.html`, 'deleted app')
  f.commit()
  const plan = await planPages(f.root)
  assert.deepEqual(plan.apps, [c.id])
  await buildSite(f.root, options(f, plan.apps))
  assert.deepEqual(JSON.parse(await read(f, '.site/apps.json')), [a, c])
  assert.equal(await read(f, `.site/${c.id}/index.html`), 'C checked')
  for (const file of [`.site/${b.id}`, '.site/obsolete.js']) await assert.rejects(stat(path.join(f.root, file)), { code: 'ENOENT' })
})
test('missing baseline app output is rebuilt even with no git changes', async t => {
  const f = await fixture(t)
  await rm(path.join(f.reuseFrom, b.id), { recursive: true })
  assert.deepEqual((await planPages(f.root)).apps, [b.id])
})
test('initial deployment, invalid provenance, missing git base and forced rebuild select every app', async t => {
  const f = await fixture(t)
  assert.deepEqual((await planPages(f.root, { force: true })).apps, [a.id, b.id])
  for (const content of ['{', 'null', JSON.stringify({ sha: 'f'.repeat(40) })]) {
    await f.save('.pages-baseline/source.json', content)
    assert.deepEqual((await planPages(f.root)).apps, [a.id, b.id])
  }
  await rm(path.join(f.root, '.pages-baseline'), { recursive: true })
  assert.deepEqual((await planPages(f.root)).apps, [a.id, b.id])
  await buildSite(f.root, options(f, [a.id, b.id]))
  assert.equal(await read(f, `.site/${a.id}/index.html`), 'A checked')
})
test('shared scripts force all apps; diff spans releases and supports rollback', async t => {
  const f = await fixture(t)
  await f.save(`${a.id}/source.txt`, 'one')
  f.commit()
  await f.save(`${b.id}/source.txt`, 'two')
  const newest = f.commit()
  assert.deepEqual((await planPages(f.root)).apps, [a.id, b.id])
  await f.save('.pages-baseline/source.json', JSON.stringify({ sha: newest }))
  f.git('checkout', '--quiet', f.base)
  assert.deepEqual((await planPages(f.root)).apps, [a.id, b.id])
  await f.save('.pages-baseline/source.json', JSON.stringify({ sha: f.base }))
  await f.save('scripts/shared.mjs', 'shared')
  f.commit()
  assert.equal((await planPages(f.root)).full, true)
})
test('missing inputs or invalid selection fail before replacing the existing site', async t => {
  const f = await fixture(t)
  await f.save('.site/sentinel.txt', 'keep')
  await assert.rejects(buildSite(f.root, { prebuilt: true, args: ['--apps-json', '[]'] }), /reuse-from/)
  await assert.rejects(buildSite(f.root, { ...options(f, []), reuseFrom: path.join(f.root, '.site') }), /outside/)
  await assert.rejects(buildSite(f.root, options(f, ['../outside'])), /registered/)
  await rm(path.join(f.root, a.id, 'dist/index.html'))
  await assert.rejects(buildSite(f.root, options(f, [a.id, b.id])), { code: 'ENOENT' })
  assert.equal(await read(f, '.site/sentinel.txt'), 'keep')
})
test('default local build still invokes npm build for every app', async t => {
  const f = await fixture(t)
  for (const app of [a, b]) {
    await f.save(`${app.id}/package.json`, JSON.stringify({ scripts: { build: 'node build.cjs' } }))
    await f.save(`${app.id}/build.cjs`, "require('fs').writeFileSync('dist/index.html', 'fresh build')")
  }
  await buildSite(f.root)
  assert.equal(await read(f, `.site/${a.id}/index.html`), 'fresh build')
  assert.equal(await read(f, `.site/${b.id}/index.html`), 'fresh build')
})

const successfulRun = { id: 10, head_sha: 'a'.repeat(40), status: 'completed', conclusion: 'success', event: 'push', repository: { full_name: 'owner/repo' }, head_repository: { full_name: 'owner/repo' } }

test('restore skips failed, foreign, current and expired runs and extracts a retained Pages tar', async t => {
  const f = await fixture(t)
  const tar = path.join(f.root, 'fixture.tar')
  execFileSync('tar', ['-cf', tar, '-C', f.reuseFrom, '.'])
  const calls = []
  const restored = await restorePages(f.root, { repository: 'owner/repo', runId: 99, executeCommand(command, args) {
    calls.push([command, ...args])
    if (args[0] === 'api' && args[1].includes('/workflows/')) return JSON.stringify({ workflow_runs: [
      { ...successfulRun, id: 99 }, { ...successfulRun, id: 98, conclusion: 'failure' },
      { ...successfulRun, id: 97, head_repository: { full_name: 'fork/repo' } },
      { ...successfulRun, id: 96 }, successfulRun,
    ] })
    if (args[0] === 'api') return JSON.stringify({ artifacts: [{ name: 'github-pages', expired: args[1].includes('/96/') }] })
    if (args[0] === 'run') return execFileSync('cp', [tar, path.join(args.at(-1), 'artifact.tar')])
    return execFileSync(command, args)
  } })
  assert.deepEqual(restored, { sha: successfulRun.head_sha, runId: 10 })
  assert.equal(await read(f, `.pages-baseline/site/${a.id}/assets/old.wasm`), 'A wasm')
  assert.equal(calls.filter(call => call[1] === 'run').length, 1)
  assert.equal(calls.some(call => call[2]?.includes('/97/artifacts')), false)
})
test('restore failures and expired artifacts clear stale provenance and fall back to full', async t => {
  const f = await fixture(t)
  for (const failAt of ['lookup', 'download', 'extract', 'expired']) {
    await f.save('.pages-baseline/source.json', JSON.stringify({ sha: f.base }))
    const result = await restorePages(f.root, { repository: 'owner/repo', executeCommand(command, args) {
      if (failAt === 'lookup') throw new Error('API unavailable')
      if (args[0] === 'api' && args[1].includes('/workflows/')) return JSON.stringify({ workflow_runs: [successfulRun] })
      if (args[0] === 'api') return JSON.stringify({ artifacts: [{ name: 'github-pages', expired: failAt === 'expired' }] })
      if (args[0] === 'run' && failAt === 'extract') return ''
      throw new Error('Download or tar failed')
    } })
    assert.equal(result, null)
    assert.deepEqual((await planPages(f.root)).apps, [a.id, b.id])
  }
})
test('forced full rebuild does not contact GitHub and clears the baseline', async t => {
  const f = await fixture(t)
  await restorePages(f.root, { force: true, executeCommand() { assert.fail('Unexpected network call') } })
  assert.deepEqual((await planPages(f.root)).apps, [a.id, b.id])
})
