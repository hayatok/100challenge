import {createServer} from 'node:http';
import {createReadStream,statSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../dist');
const port=Number(process.env.PORT||4197);
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.svg':'image/svg+xml','.png':'image/png','.otf':'font/otf'};
const server=createServer((req,res)=>{
 try{
  const url=new URL(req.url,'http://localhost');
  let file=path.resolve(root,'.'+decodeURIComponent(url.pathname));
  if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403).end('Forbidden');return;}
  if(statSync(file).isDirectory())file=path.join(file,'index.html');
  const info=statSync(file);
  res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Content-Length':info.size,'Cache-Control':'no-store'});
  createReadStream(file).pipe(res);
 }catch{res.writeHead(404).end('Not found');}
});
server.listen(port,'127.0.0.1',()=>console.log('Local: http://127.0.0.1:'+port+'/'));
