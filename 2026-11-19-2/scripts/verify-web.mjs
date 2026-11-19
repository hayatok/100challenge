import { createHash } from 'node:crypto'
import { cp, readFile, readdir, rm } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { Script } from 'node:vm'
import { gunzipSync } from 'node:zlib'

const title = '避難指令'
const utf8 = new TextDecoder('utf-8', { fatal: true })
const dataMagic = Buffer.from('UnityWebData1.0\0')
const wasmMagic = Buffer.from([0, 97, 115, 109, 1, 0, 0, 0])
const hashedFile = /^Build\/([0-9a-f]{32})(?:\.[a-z0-9]+)+$/i

function requireValid(ok, description) {
  if (!ok) throw new Error(description)
}

function readText(bytes, file) {
  try {
    return utf8.decode(bytes)
  } catch (error) {
    throw new Error(`${file} must be valid UTF-8`, { cause: error })
  }
}

function buildReference(html, expression, label, suffix) {
  const ref = html.match(expression)?.[1]
  requireValid(ref && hashedFile.test(ref) && ref.endsWith(suffix),
    `Expected a hashed ${label} in index.html (Build/*${suffix})`)
  return ref
}

function checkWebData(data) {
  requireValid(data.length > dataMagic.length + 4 && data.subarray(0, dataMagic.length).equals(dataMagic),
    'The decompressed data is not a UnityWebData1.0 archive')
  let cursor = dataMagic.length + 4
  const headerEnd = data.readUInt32LE(dataMagic.length)
  requireValid(headerEnd > cursor && headerEnd <= data.length, 'Invalid Unity data header length')

  while (cursor < headerEnd) {
    requireValid(headerEnd - cursor >= 12, 'Truncated Unity data entry')
    const offset = data.readUInt32LE(cursor)
    const size = data.readUInt32LE(cursor + 4)
    const nameLength = data.readUInt32LE(cursor + 8)
    cursor += 12
    requireValid(nameLength > 0 && cursor + nameLength <= headerEnd &&
      offset >= headerEnd && offset + size <= data.length, 'Invalid Unity data archive entry')
    cursor += nameLength
  }
}

export async function verifyWebPlayer(source) {
  const read = file => readFile(path.join(source, file))
  const [index, worker, manifestBytes] = await Promise.all(['index.html', 'offline.js', 'game.webmanifest'].map(read))
  const html = readText(index, 'index.html')
  const offline = readText(worker, 'offline.js')
  requireValid(/<meta\s+charset=["']utf-8["']/i.test(html) && html.includes(`<title>${title}</title>`),
    'index.html must declare UTF-8 and use the game title')
  requireValid(!html.includes('{{{') && !offline.includes('{{{'), 'Unexpanded Unity template expression')
  requireValid(/serviceWorker\.register\(\s*['"]offline\.js['"]\s*\)/.test(html),
    'index.html must register offline.js')
  requireValid(/<link\b[^>]*\brel=["']manifest["'][^>]*\bhref=["']game\.webmanifest["']/i.test(html),
    'index.html must link to the packaged web manifest')
  const manifest = JSON.parse(readText(manifestBytes, 'game.webmanifest'))
  requireValid(manifest.name === title && manifest.start_url === './' && manifest.scope === './' &&
    manifest.display === 'standalone' && Array.isArray(manifest.icons), 'Invalid game.webmanifest')
  const icons = [192, 512].map(size => ({ size, name: `train-${size}.png` }))
  for (const { size, name } of icons) {
    requireValid(manifest.icons.some(icon => icon.src === name && icon.type === 'image/png' &&
      icon.sizes === `${size}x${size}`), `Manifest has no entry for ${name}`)
    const png = await read(name)
    requireValid(png.length >= 33 && png.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')) &&
      png.toString('ascii', 12, 16) === 'IHDR' && png.readUInt32BE(16) === size &&
      png.readUInt32BE(20) === size, `Invalid dimensions or PNG signature for ${name}`)
  }
  const loader = buildReference(html, /<script\b[^>]*\bsrc=["']([^"']+)["']/i, 'loader', '.loader.js')
  const data = buildReference(html, /\bdataUrl\s*:\s*['"]([^'"]+)['"]/, 'data', '.data.unityweb')
  const framework = buildReference(html, /\bframeworkUrl\s*:\s*['"]([^'"]+)['"]/, 'framework', '.framework.js.unityweb')
  const code = buildReference(html, /\bcodeUrl\s*:\s*['"]([^'"]+)['"]/, 'WebAssembly module', '.wasm.unityweb')
  const references = [loader, data, framework, code]
  requireValid(new Set(references).size === references.length, 'Unity build references must be distinct')

  const buildFiles = await readdir(path.join(source, 'Build'), { withFileTypes: true })
  requireValid(buildFiles.length === references.length &&
    buildFiles.every(file => file.isFile() && references.includes(`Build/${file.name}`)),
    'Build must contain exactly the four runtime files selected by index.html')
  for (const license of ['HTS-Mei.txt', 'NotoSansJP-OFL.txt']) {
    const file = `StreamingAssets/Licenses/${license}`
    requireValid(readText(await read(file), file).trim().length > 0, `Missing license text in ${file}`)
  }
  const precache = offline.match(/\bconst\s+assets\s*=\s*\[([^\]]*)\]/)?.[1] ?? ''
  const entries = [...precache.matchAll(/['"]([^'"]+)['"]/g)].map(match => match[1])
  const expected = ['index.html','game.webmanifest','train-192.png','train-512.png', ...references]
  requireValid(entries.length === expected.length && expected.every(asset => entries.includes(asset)),
    'The service worker precache must reference index.html and the same Unity files as index.html')
  requireValid(/\baddEventListener\(\s*['"]install['"]/.test(offline) &&
    /\bcache\.addAll\(assets\)/.test(offline) && /\baddEventListener\(\s*['"]fetch['"]/.test(offline),
    'offline.js must cache the build on install and handle fetches')
  new Script(offline, { filename: 'offline.js' })

  for (const ref of references) {
    const file = await read(ref)
    const compressed = ref.endsWith('.unityweb')
    if (compressed) requireValid(file[0] === 0x1f && file[1] === 0x8b && file[2] === 8,
      `Expected Unity gzip compression in ${ref}`)
    const bytes = compressed ? gunzipSync(file) : file
    const contentHash = createHash('md5').update(bytes).digest('hex')
    requireValid(contentHash === ref.match(hashedFile)[1].toLowerCase(), `Content hash does not match ${ref}`)
    if (ref === code) {
      requireValid(bytes.length > wasmMagic.length && bytes.subarray(0, wasmMagic.length).equals(wasmMagic) &&
        WebAssembly.validate(bytes),
        'The decompressed code is not a valid WebAssembly module')
    } else if (ref === data) {
      checkWebData(bytes)
    } else {
      const js = readText(bytes, ref)
      requireValid(js.trim().length > 0, `Missing JavaScript runtime in ${ref}`)
      if (ref === loader) requireValid(/\bcreateUnityInstance\b/.test(js), 'Unity loader is missing createUnityInstance')
      new Script(js, { filename: ref })
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const root = fileURLToPath(new URL('../', import.meta.url))
  const args = process.argv.slice(2)
  if (args.length === 2 && args[0] === '--verify-only') {
    await verifyWebPlayer(path.resolve(args[1]))
    console.log('Verified Unity Web player.')
  } else if (args.length === 0) {
    const source = path.join(root, 'web-player')
    const output = path.join(root, 'dist')
    await verifyWebPlayer(source)
    await rm(output, { recursive: true, force: true })
    await cp(source, output, { recursive: true })
    console.log('Verified Unity Web player and copied it to dist.')
  } else {
    throw new Error('Usage: node scripts/verify-web.mjs [--verify-only BUILD_DIRECTORY]')
  }
}
