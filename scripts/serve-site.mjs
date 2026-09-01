import { createReadStream } from 'node:fs'
import { stat } from 'node:fs/promises'
import { createServer } from 'node:http'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../.site')
const port = Number(process.env.SHOWCASE_PORT || 4173)
const mimeTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
}

createServer(async (request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname)
  let filePath = path.join(root, pathname)

  if (!filePath.startsWith(root)) {
    response.writeHead(403).end('Forbidden')
    return
  }

  try {
    if ((await stat(filePath)).isDirectory()) filePath = path.join(filePath, 'index.html')
    const file = await stat(filePath)
    response.writeHead(200, {
      'Content-Type': mimeTypes[path.extname(filePath)] || 'application/octet-stream',
      'Content-Length': file.size,
    })
    createReadStream(filePath).pipe(response)
  } catch {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('Not found')
  }
}).listen(port, '127.0.0.1', () => {
  console.log(`Showcase: http://127.0.0.1:${port}/`)
})
