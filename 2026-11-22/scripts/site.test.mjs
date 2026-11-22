import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile, stat } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const site = fileURLToPath(new URL('../site/', import.meta.url))

test('archive names its final state and exact Windows release', async () => {
  const html = await readFile(path.join(site, 'index.html'), 'utf8')
  assert.match(html, /<html lang="ja">/)
  for (const text of ['金星の一夜', '失敗作', '開発終了', 'Windows x64', 'v1.9.0', '145,137,866 bytes', 'Kinsei.exe', 'ZIPをすべて展開']) {
    assert.ok(html.includes(text), text)
  }
  assert.match(html, /href="https:\/\/github.com\/hayatok\/100challenge\/releases\/download\/release-kinsei-v1\.9\.0\/Kinsei-Windows-v1\.9\.0\.zip"/)
  assert.doesNotMatch(html, /<script|localhost|127\.0\.0\.1|C:\\/i)
  for (const [, url] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (url.startsWith('./')) assert.ok((await stat(path.join(site, url))).isFile(), url)
    if (url.startsWith('#')) assert.ok(html.includes(`id="${url.slice(1)}"`), url)
  }
})

test('cover is a small WebP and the page keeps layout and focus rules', async () => {
  const cover = await readFile(path.join(site, 'cover.webp'))
  assert.equal(cover.toString('ascii', 0, 4), 'RIFF')
  assert.equal(cover.toString('ascii', 8, 12), 'WEBP')
  assert.ok(cover.length < 200_000, `${cover.length} bytes`)
  const css = await readFile(path.join(site, 'styles.css'), 'utf8')
  assert.match(css, /:focus-visible/)
  assert.match(css, /@media \(max-width: 720px\)/)
})
