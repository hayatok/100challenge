import http from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
const directory=path.join(root,args.includes('--dist')?'dist':'app');
const portIndex=args.indexOf('--port');
const port=portIndex>=0?Number(args[portIndex+1]):4316;
if(!Number.isInteger(port)||port<0||port>65535)throw new Error('Invalid port');
const mime={'.html':'text/html; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.txt':'text/plain; charset=utf-8'};
const server=http.createServer(async(req,res)=>{
  try {
    if(!['GET','HEAD'].includes(req.method)){res.writeHead(405,{'Allow':'GET, HEAD'});res.end();return;}
    let pathname=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
    if(pathname.endsWith('/'))pathname+='index.html';
    const file=path.resolve(directory,`.${pathname}`);
    if(!file.startsWith(directory+path.sep)){res.writeHead(403);res.end();return;}
    const info=await stat(file);
    if(!info.isFile())throw new Error('Not a file');
    res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream','Content-Length':info.size,'Cache-Control':'no-cache','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; img-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'"});
    res.end(req.method==='HEAD'?undefined:await readFile(file));
  }catch(error){res.writeHead(error.code==='ENOENT'?404:400,{'Content-Type':'text/plain; charset=utf-8'});res.end('このページは見つかりませんでした。');}
});
server.listen(port,'127.0.0.1',()=>{
  const url=`http://127.0.0.1:${server.address().port}/`;
  console.log(`時代のとなりで\n${url}\nLocal files: ${directory}`);
  if(args.includes('--open')){
    if(process.platform==='darwin')execFile('open',[url]);
    else if(process.platform==='win32')execFile('rundll32',['url.dll,FileProtocolHandler',url]);
    else execFile('xdg-open',[url],()=>{});
  }
});
server.on('error',error=>{console.error(error.code==='EADDRINUSE'?`Port ${port} is in use. Try npm run dev -- --port 4317`:error.message);process.exitCode=1;});
function stop(){server.close(()=>process.exit(0));}
process.once('SIGINT',stop);process.once('SIGTERM',stop);
