import http from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../dist');
const index=process.argv.indexOf('--port');
const port=Number(index>=0?process.argv[index+1]:4316);
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml','.txt':'text/plain','.md':'text/plain; charset=utf-8'};
http.createServer(async(req,res)=>{
  try{
    const url=new URL(req.url,'http://localhost');
    const file=path.resolve(root,'.'+decodeURIComponent(url.pathname));
    if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
    const target=(await stat(file)).isDirectory()?path.join(file,'index.html'):file;
    const body=await readFile(target);
    res.writeHead(200,{'Content-Type':mime[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});res.end(body);
  }catch{res.writeHead(404).end('Not found');}
}).listen(port,'0.0.0.0',()=>console.log(`SHIOGAERI: http://localhost:${port}`));
