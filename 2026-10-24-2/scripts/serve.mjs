import {createServer} from 'node:http';
import {createReadStream, existsSync, realpathSync, statSync} from 'node:fs';
import path from 'node:path';
import {root} from './engine.mjs';

const directory = path.join(root, 'dist');
if (!existsSync(path.join(directory, 'index.html'))) throw new Error('No dist/index.html; run npm run build first.');
const portArgument = process.argv.indexOf('--port');
const initialPort = Number(portArgument >= 0 ? process.argv[portArgument + 1] : (process.env.PORT || 4249));
if (!Number.isInteger(initialPort) || initialPort < 0 || initialPort > 65535) throw new Error('Port must be an integer from 0 to 65535.');
let port = initialPort;
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.ico': 'image/x-icon',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.txt': 'text/plain; charset=utf-8',
};
const headers = {
  'Cache-Control': 'no-store',
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Resource-Policy': 'same-origin',
};
const server = createServer((req, res) => {
  if (!['GET', 'HEAD'].includes(req.method)) {
    res.writeHead(405, {...headers, Allow: 'GET, HEAD'}).end('Method not allowed');
    return;
  }
  try {
    const url = new URL(req.url, 'http://localhost');
    let file = path.resolve(directory, '.' + decodeURIComponent(url.pathname));
    if (file !== directory && !file.startsWith(directory + path.sep)) {
      res.writeHead(403, headers).end('Forbidden');
      return;
    }
    if (statSync(file).isDirectory()) file = path.join(file, 'index.html');
    file = realpathSync(file);
    if (!file.startsWith(realpathSync(directory) + path.sep)) {
      res.writeHead(403, headers).end('Forbidden');
      return;
    }
    const info = statSync(file);
    if (!info.isFile()) throw new Error('Not a file');
    res.writeHead(200, {...headers, 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Content-Length': info.size});
    if (req.method === 'HEAD') res.end();
    else {
      const stream = createReadStream(file);
      stream.on('error', () => res.destroy());
      stream.pipe(res);
    }
  } catch {
    res.writeHead(404, headers).end('Not found');
  }
});
server.on('error', error => {
  if (error.code === 'EADDRINUSE' && initialPort !== 0 && port < Math.min(initialPort + 50, 65535)) {
    port += 1;
    server.listen(port, '127.0.0.1');
  } else {
    console.error(error);
    process.exitCode = 1;
  }
});
server.on('listening', () => console.log(`Local: http://127.0.0.1:${server.address().port}/`));
server.listen(port, '127.0.0.1');
