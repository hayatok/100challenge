import {createServer} from 'node:http';
import {createReadStream,statSync,mkdirSync,appendFileSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../dist');
const port=Number(process.env.PORT||4248);
const qaLog=process.env.TENSAI_QA==='1'?path.resolve(import.meta.dirname,'../.cache/web-qa.jsonl'):null;
if(qaLog)mkdirSync(path.dirname(qaLog),{recursive:true});
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.svg':'image/svg+xml','.png':'image/png','.json':'application/json','.txt':'text/plain; charset=utf-8'};
createServer((req,res)=>{
 if(req.method==='POST'&&req.url==='/__qa'){
  if(!qaLog||req.headers.origin!==`http://127.0.0.1:${port}`||req.headers['content-type']!=='application/json'){res.writeHead(403).end();return;}
  let body='';req.on('data',chunk=>{body+=chunk;if(body.length>65536)req.destroy();});
  req.on('end',()=>{try{const record=JSON.parse(body);if(typeof record.text!=='string'||!['stdout','stderr'].includes(record.kind))throw Error('Invalid record');appendFileSync(qaLog,JSON.stringify({at:new Date().toISOString(),...record})+'\n');res.writeHead(204).end();}catch{res.writeHead(400).end();}});return;
 }
 if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
 try{
  let file=path.resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://localhost').pathname));
  if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  if(statSync(file).isDirectory())file=path.join(file,'index.html');
  const s=statSync(file);res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Content-Length':s.size,'Cache-Control':'no-store'});
  if(req.method==='HEAD')res.end();else createReadStream(file).pipe(res);
 }catch{res.writeHead(404).end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log('TENSAI http://127.0.0.1:'+port+(qaLog?' (local QA log enabled)':'')));
