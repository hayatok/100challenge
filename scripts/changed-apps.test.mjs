import assert from 'node:assert/strict'
import test from 'node:test'
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { planChanges, detectChanges } from './changed-apps.mjs'
import { selectApps } from './apps.mjs'

const a = { id: '2026-09-06', date: '2026-09-06', sequence: 1, name: 'A' }
const b = { id: '2026-09-06-2', date: '2026-09-06', sequence: 2, name: 'B' }
const c = { id: '2026-09-07', date: '2026-09-07', sequence: 1, name: 'C' }
const catalog = [a, b, c]
const plan = (files, current = catalog, previous = catalog) => planChanges(files, current, previous)

test('one app does not include its same-day sibling', () => {
  assert.deepEqual(plan([`${b.id}/game/creature_art.gd`]).apps, [b.id])
  assert.equal(plan([`${b.id}/game/creature_art.gd`]).full, false)
})
test('multiple changed apps are deduplicated and retain catalog order', () => {
  assert.deepEqual(plan([`${c.id}/a`, `${a.id}/b`, `${a.id}/c`]).apps, [a.id, c.id])
})
test('added and edited catalog entries select only their apps', () => {
  assert.deepEqual(plan(['apps.json'], catalog, [a, b]).apps, [c.id])
  assert.deepEqual(plan(['apps.json'], [a, { ...b, name: 'Updated' }, c]).apps, [b.id])
})
test('removed apps and catalog reordering do not run unrelated apps', () => {
  assert.deepEqual(plan(['apps.json', `${c.id}/package.json`], [a, b]).apps, [])
  assert.deepEqual(plan(['apps.json'], [c, a, b]).apps, [])
})
test('deleting a file in a retained app still checks that app', () => {
  assert.deepEqual(plan([`${b.id}/deleted.gd`]).apps, [b.id])
})
test('unregistered dates are outside the public app runner', () => {
  assert.deepEqual(plan(['2026-09-08/new.gd']).apps, [])
})
for (const file of ['scripts/build-site.mjs', 'scripts/run-apps.mjs', 'scripts/apps.mjs', 'package.json', 'package-lock.json', 'showcase/showcase.js', '.github/workflows/verify.yml', '.github/workflows/deploy-pages.yml']) {
  test(`shared change checks every app: ${file}`, () => {
    assert.equal(plan([file]).full, true)
    assert.deepEqual(plan([file]).apps, catalog.map(app => app.id))
  })
}
test('root tests and shared documentation do not expand app selection', () => {
  assert.deepEqual(plan(['scripts/apps.test.mjs', 'README.md', 'docs/FRONTEND.md']).apps, [])
  assert.deepEqual(plan(['scripts/apps.test.mjs', 'README.md', `${b.id}/README.md`]).apps, [b.id])
  assert.deepEqual(plan([]).apps, [])
})
test('runner defaults to all apps but an explicit empty selection runs none', () => {
  assert.deepEqual(selectApps(catalog, []), catalog)
  assert.deepEqual(selectApps(catalog, ['--apps-json', '[]']), [])
  assert.deepEqual(selectApps(catalog, ['--apps-json', JSON.stringify([b.id])]), [b])
})
test('runner rejects invalid or unknown selections instead of silently skipping', () => {
  for (const args of [['--wrong'], ['--apps-json'], ['--apps-json', '{'], ['--apps-json', '{}'], ['--apps-json', '[12]'], ['--apps-json', '["unknown"]'], ['--apps-json', JSON.stringify([a.id, a.id])]]) {
    assert.throws(() => selectApps(catalog, args))
  }
})

async function repository(t) {
  const root = await mkdtemp(path.join(tmpdir(), 'changed-app-ci-'))
  t.after(() => rm(root, { recursive: true, force: true }))
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
  git('init', '--quiet')
  git('config', 'user.name', 'CI test')
  git('config', 'user.email', 'ci-test@example.invalid')
  const save = async (file, contents) => {
    await mkdir(path.dirname(path.join(root, file)), { recursive: true })
    await writeFile(path.join(root, file), contents)
  }
  await save('apps.json', JSON.stringify(catalog))
  await save(`${a.id}/original.txt`, 'original\n')
  git('add', '.')
  git('commit', '--quiet', '-m', 'base')
  const base = git('rev-parse', 'HEAD')
  const commit = () => { git('add', '-A'); git('commit', '--quiet', '-m', 'change') }
  return { root, git, save, base, commit }
}

test('git diff covers every commit in a push and handles whitespace in paths', async t => {
  const repo = await repository(t)
  await repo.save(`${b.id}/file with\nnewline.txt`, 'one')
  repo.commit()
  await repo.save(`${c.id}/second.txt`, 'two')
  repo.commit()
  assert.deepEqual((await detectChanges(repo.root, repo.base)).apps, [b.id, c.id])
})
test('git rename checks both the old and the new app directories', async t => {
  const repo = await repository(t)
  await mkdir(path.join(repo.root, b.id))
  repo.git('mv', `${a.id}/original.txt`, `${b.id}/renamed.txt`)
  repo.commit()
  assert.deepEqual((await detectChanges(repo.root, repo.base)).apps, [a.id, b.id])
})
test('git catalog comparison supports adding and removing an app', async t => {
  const repo = await repository(t)
  const d = { id: '2026-09-08', date: '2026-09-08', sequence: 1, name: 'D' }
  await repo.save('apps.json', JSON.stringify([a, b, d]))
  repo.commit()
  assert.deepEqual((await detectChanges(repo.root, repo.base)).apps, [d.id])
})
test('missing, invalid and unavailable base commits fall back to all apps', async t => {
  const repo = await repository(t)
  for (const base of [undefined, '', '0'.repeat(40), '--output=bad', 'f'.repeat(40)]) {
    const result = await detectChanges(repo.root, base)
    assert.equal(result.full, true)
    assert.deepEqual(result.apps, catalog.map(app => app.id))
  }
})
test('an invalid base catalog falls back to all current apps', async t => {
  const repo = await repository(t)
  await repo.save('apps.json', '{')
  repo.commit()
  const invalidBase = repo.git('rev-parse', 'HEAD')
  await repo.save('apps.json', JSON.stringify(catalog))
  repo.commit()
  assert.equal((await detectChanges(repo.root, invalidBase)).full, true)
})
test('an invalid current catalog fails before selecting any apps', async t => {
  const repo = await repository(t)
  await repo.save('apps.json', JSON.stringify([{ ...a, sequence: 2 }]))
  await assert.rejects(detectChanges(repo.root, repo.base), /sequence/)
})
