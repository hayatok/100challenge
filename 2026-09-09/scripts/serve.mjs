import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../dist');
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.ico':'image/x-icon'};
const port=Number(process.env.PORT||4209);
http.createServer(async(req,res)=>{
 try{
  const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const file=['/qa-load-error/','/qa-loading/'].includes(name)?path.join(root,'index.html'):path.resolve(root,'.'+(name.endsWith('/')?name+'index.html':name));
  if(!file.startsWith(root+path.sep))throw Error('outside root');
  const info=await stat(file);if(!info.isFile())throw Error('not file');
  res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'});const payload=await readFile(file);
  // Local visual-QA fixture: leave the real loading UI visible without starting Godot.
  res.end(name==='/qa-loading/'?payload.toString().replace(/<script src="[^"]+" onerror="showLoadError\(\)"><\/script>/,''):payload);
 }catch{res.writeHead(404);res.end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log(`Chibi Grand Prix http://127.0.0.1:${port}/`));
