import assert from 'node:assert/strict'
import test from 'node:test'
import { spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { copyFile, mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile } from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const source = path.dirname(fileURLToPath(import.meta.url))
const manifest = JSON.parse(await readFile(path.join(source, '../hooks.json'), 'utf8'))
const environment = { ...process.env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_NOSYSTEM: '1' }

async function repository(t) {
  const root = await mkdtemp(path.join(os.tmpdir(), '100challenge hooks '))
  const digest = createHash('sha256').update(await realpath(root)).digest('hex').slice(0, 20)
  const cache = path.join(await realpath(os.tmpdir()), `100challenge-quality-${process.getuid?.() ?? 'user'}-${digest}`)
  t.after(() => Promise.all([rm(root, { recursive: true, force: true }), rm(cache, { recursive: true, force: true })]))
  await mkdir(path.join(root, '.codex/hooks'), { recursive: true })
  await copyFile(path.join(source, 'quality.mjs'), path.join(root, '.codex/hooks/quality.mjs'))
  const git = (...args) => {
    const result = spawnSync('git', ['-c', 'user.name=Hook test', '-c', 'user.email=hook@example.invalid', ...args], {
      cwd: root, env: environment, encoding: 'utf8', timeout: 10000,
    })
    assert.equal(result.status, 0, result.stderr)
    return result.stdout
  }
  git('init', '-q')
  await writeFile(path.join(root, 'app.js'), 'export const title = "本日の記録"\n')
  git('add', '.')
  git('commit', '-qm', 'baseline')
  const hook = (name, extra = {}) => {
    const event = { hook_event_name: name, session_id: 'session-1', turn_id: 'turn-1', cwd: root, ...extra }
    const command = manifest.hooks[name][0].hooks[0].command
    const result = spawnSync('sh', ['-c', command], {
      cwd: root, env: environment, input: JSON.stringify(event), encoding: 'utf8', timeout: 15000,
    })
    assert.equal(result.status, 0, result.stderr)
    return JSON.parse(result.stdout)
  }
  return { root, cache, git, hook }
}

test('manifest uses supported command hooks and bounded timeouts', () => {
  assert.deepEqual(Object.keys(manifest.hooks), ['UserPromptSubmit', 'Stop'])
  for (const groups of Object.values(manifest.hooks)) {
    assert.equal(groups.length, 1)
    assert.equal(groups[0].hooks.length, 1)
    assert.equal(groups[0].hooks[0].type, 'command')
    assert.equal(groups[0].hooks[0].timeout, 20)
  }
})

test('no changes need no continuation; committed edits still receive one review', async t => {
  const { root, cache, git, hook } = await repository(t)
  assert.match(hook('UserPromptSubmit').hookSpecificOutput.additionalContext, /実装済み/)
  assert.deepEqual(hook('Stop'), {})
  await writeFile(path.join(root, 'app.js'), 'export const title = "革新的な記録"\n')
  git('add', 'app.js')
  git('commit', '-qm', 'update title')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.match(result.reason, /app\.js/)
  assert.match(result.reason, /generic-copy/)
  assert.match(result.reason, /違反や修正命令ではありません/)
  assert.deepEqual(hook('Stop'), {})
  assert.deepEqual(hook('Stop', { stop_hook_active: true, turn_id: 'continuation-turn' }), {})
  const stateFile = (await readdir(cache)).find(file => file.endsWith('.json'))
  const state = await readFile(path.join(cache, stateFile), 'utf8')
  assert.ok(!state.includes('本日の記録'))
  assert.ok(!git('status', '--porcelain').includes('.quality-state'))
})

test('pre-existing staged and untracked work is ignored, including old candidate lines', async t => {
  const { root, cache, git, hook } = await repository(t)
  await writeFile(path.join(root, 'app.js'), '// TODO: existing work\nexport const title = "作業中"\n')
  git('add', 'app.js')
  await writeFile(path.join(root, 'existing.md'), 'Lorem ipsum\n')
  hook('UserPromptSubmit')
  assert.deepEqual(hook('Stop'), {})
  await writeFile(path.join(root, 'app.js'), '// TODO: existing work\nexport const title = "一覧を開く"\n')
  // Duplicate delivery must not reset the baseline to the just-modified content.
  hook('UserPromptSubmit')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.ok(!result.reason.includes('existing.md'))
  assert.ok(!result.reason.includes('[unfinished]'))
  const stateFile = (await readdir(cache)).find(file => file.endsWith('.json'))
  const state = await readFile(path.join(cache, stateFile), 'utf8')
  assert.ok(!state.includes('existing work'))
  assert.ok(!state.includes('Lorem ipsum'))
})

test('each later human turn can review again, but a stop continuation cannot loop', async t => {
  const { root, hook } = await repository(t)
  hook('UserPromptSubmit')
  await writeFile(path.join(root, 'app.js'), 'export const title = "一覧"\n')
  assert.equal(hook('Stop').decision, 'block')
  hook('UserPromptSubmit', { turn_id: 'continuation-turn' })
  await writeFile(path.join(root, 'app.js'), 'export const title = "記録一覧"\n')
  assert.deepEqual(hook('Stop', { turn_id: 'continuation-turn', stop_hook_active: true }), {})
  hook('UserPromptSubmit', { turn_id: 'turn-2' })
  await writeFile(path.join(root, 'app.js'), 'export const title = "今日の記録"\n')
  assert.equal(hook('Stop', { turn_id: 'turn-2' }).decision, 'block')
})

test('new committed files, renames, deletions, and unusual filenames are included', async t => {
  const { root, git, hook } = await repository(t)
  hook('UserPromptSubmit')
  git('mv', 'app.js', '記録 の一覧.js')
  await writeFile(path.join(root, 'new\nname.html'), '<button onClick={() => {}}>保存</button>\n')
  git('add', '.')
  git('commit', '-qm', 'rename and add')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.match(result.reason, /app\.js/)
  assert.match(result.reason, /記録 の一覧\.js/)
  assert.match(result.reason, /new\\nname\.html/)
  assert.match(result.reason, /empty-handler/)
})

test('a file deleted before the turn stays excluded until it is restored', async t => {
  const { root, hook } = await repository(t)
  await rm(path.join(root, 'app.js'))
  hook('UserPromptSubmit')
  assert.deepEqual(hook('Stop'), {})
  await writeFile(path.join(root, 'app.js'), '// TODO restored\n')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.match(result.reason, /unfinished/)
})

test('subdirectory cwd works; other and embedded repositories are not affected', async t => {
  const { root, hook } = await repository(t)
  await mkdir(path.join(root, 'src'))
  hook('UserPromptSubmit', { cwd: path.join(root, 'src') })
  await writeFile(path.join(root, 'app.js'), 'export const title = "更新"\n')
  assert.equal(hook('Stop', { cwd: path.join(root, 'src') }).decision, 'block')
  const other = await repository(t)
  const script = path.join(root, '.codex/hooks/quality.mjs')
  const result = spawnSync(process.execPath, [script], {
    input: JSON.stringify({ hook_event_name: 'UserPromptSubmit', cwd: other.root, session_id: 'x', turn_id: 'x' }),
    encoding: 'utf8', env: environment,
  })
  assert.deepEqual(JSON.parse(result.stdout), {})
  await mkdir(path.join(root, 'embedded'))
  assert.equal(spawnSync('git', ['init', '-q'], { cwd: path.join(root, 'embedded'), env: environment }).status, 0)
  assert.deepEqual(hook('UserPromptSubmit', { cwd: path.join(root, 'embedded') }), {})
})

test('symlinks, embedded repository contents, ignored files, and secret files are not inspected', async t => {
  const { root, git, hook } = await repository(t)
  const external = await repository(t)
  hook('UserPromptSubmit')
  await symlink(path.join(external.root, 'app.js'), path.join(root, 'external.js'))
  await symlink(external.root, path.join(root, 'external-directory'))
  await mkdir(path.join(root, 'nested'))
  await mkdir(path.join(root, 'nested/.git'))
  await writeFile(path.join(root, 'nested/hidden.js'), '// TODO hidden\n')
  await writeFile(path.join(root, 'auth.json'), '{"secret":"do not print"}')
  await writeFile(path.join(root, '.env.json'), '{"secret":"do not print"}')
  await mkdir(path.join(root, 'node_modules'))
  await writeFile(path.join(root, 'node_modules/hidden.js'), '// TODO dependency\n')
  assert.deepEqual(hook('Stop'), {})
  assert.ok(git('ls-files', '--others', '--exclude-standard').includes('auth.json'))
})

test('large files are reported as uninspected and fixture words are not findings', async t => {
  const { root, hook } = await repository(t)
  await writeFile(path.join(root, 'existing.txt'), 'x'.repeat(300000))
  hook('UserPromptSubmit')
  assert.deepEqual(hook('Stop'), {})
  await writeFile(path.join(root, 'existing.txt'), 'y'.repeat(300000))
  await writeFile(path.join(root, 'sample.test.js'), '// TODO Lorem ipsum\n')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.match(result.reason, /上限により本文の自動検査なし/)
  assert.ok(!result.reason.includes('[unfinished]'))
})

test('a large clean-at-start blob does not suppress findings in other files', async t => {
  const { root, git, hook } = await repository(t)
  await writeFile(path.join(root, 'large.csv'), 'x'.repeat(9 * 1024 * 1024))
  git('add', 'large.csv')
  git('commit', '-qm', 'large baseline')
  hook('UserPromptSubmit')
  await writeFile(path.join(root, 'large.csv'), 'y'.repeat(9 * 1024 * 1024))
  await writeFile(path.join(root, 'app.js'), '// TODO: current turn\n')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.match(result.reason, /large\.csv.*本文の自動検査なし/)
  assert.match(result.reason, /app\.js.*unfinished/)
})

test('many existing data records do not prevent review of a small code change', async t => {
  const { root, hook } = await repository(t)
  await mkdir(path.join(root, 'evidence'))
  await Promise.all(Array.from({ length: 1100 }, (_, index) => writeFile(path.join(root, `evidence/${index}.json`), '{"value":1}\n')))
  assert.ok(hook('UserPromptSubmit').hookSpecificOutput)
  await writeFile(path.join(root, 'app.js'), '// TODO current turn\n')
  const result = hook('Stop')
  assert.equal(result.decision, 'block')
  assert.match(result.reason, /今回の変更1ファイル/)
  assert.match(result.reason, /unfinished/)
  assert.ok(!result.reason.includes('evidence/'))
})

test('missing and corrupt state warn instead of blocking or claiming success', async t => {
  const { root, cache, hook } = await repository(t)
  assert.match(hook('Stop').systemMessage, /検査済みとして扱わない/)
  hook('UserPromptSubmit')
  const file = (await readdir(cache)).find(file => file.endsWith('.json'))
  await writeFile(path.join(cache, file), '{broken')
  assert.equal(hook('Stop').decision, undefined)
  assert.match(hook('Stop').systemMessage, /省略/)
  const invalid = spawnSync(process.execPath, [path.join(root, '.codex/hooks/quality.mjs')], { input: '{broken', encoding: 'utf8' })
  assert.equal(invalid.status, 0)
  assert.match(JSON.parse(invalid.stdout).systemMessage, /省略/)
})

test('a cache directory symlink cannot write outside the project', async t => {
  const { cache, hook } = await repository(t)
  const outside = await mkdtemp(path.join(os.tmpdir(), '100challenge cache '))
  t.after(() => rm(outside, { recursive: true, force: true }))
  await symlink(outside, cache)
  assert.match(hook('UserPromptSubmit').systemMessage, /省略/)
  assert.deepEqual(await readdir(outside), [])
})
