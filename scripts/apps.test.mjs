import assert from 'node:assert/strict'
import test from 'node:test'
import { appIdPattern, loadApps } from './apps.mjs'

test('accepts the first and subsequent apps for a date', () => {
  assert.equal(appIdPattern.test('2026-09-01'), true)
  assert.equal(appIdPattern.test('2026-09-01-2'), true)
  assert.equal(appIdPattern.test('2026-09-01-12'), true)
})

test('rejects unsupported directory names', () => {
  assert.equal(appIdPattern.test('2026-09-01-1'), false)
  assert.equal(appIdPattern.test('2026-09-01-copy'), false)
  assert.equal(appIdPattern.test('app-2026-09-01'), false)
})

test('loads the current app catalog', async () => {
  const apps = await loadApps(new URL('../apps.json', import.meta.url))
  assert.equal(apps.length, 4)
  assert.equal(apps[0].id, '2026-09-01')
  assert.equal(apps[1].id, '2026-09-02')
  assert.equal(apps[2].id, '2026-09-02-2')
  assert.equal(apps[3].id, '2026-09-02-3')
})
