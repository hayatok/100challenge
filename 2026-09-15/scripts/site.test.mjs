import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../site')
test('description page links resolve locally and the desktop download is explicit', async () => {
  const html = await readFile(path.join(root, 'index.html'), 'utf8')
  assert.match(html, /<html lang="ja">/)
  assert.match(html, /Windows 11/)
  assert.match(html, /試用版/)
  assert.match(
    html,
    /releases\/download\/manual-maker-v0\.1\.3\/manual-maker-0\.1\.3-windows-x64\.zip/,
  )
  assert.doesNotMatch(html, /<script|localhost|127\.0\.0\.1|\/Users\//)
  for (const [, url] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (url.startsWith('./')) assert.ok((await stat(path.join(root, url.slice(2)))).isFile(), url)
    if (url.startsWith('#')) assert.ok(html.includes(`id="${url.slice(1)}"`), url)
  }
  const sample = await readFile(path.join(root, 'sample.html'), 'utf8')
  assert.match(sample, /data:image\/png;base64,/)
  assert.doesNotMatch(sample, /<script|共有前にメールアドレス|\/Users\//)
})
