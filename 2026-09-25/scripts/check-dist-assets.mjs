import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { basename, join } from 'node:path'

const assets=join(process.cwd(),'dist','assets')
let checked=0
const missing=[]
for(const file of readdirSync(assets).filter(name=>name.endsWith('.css'))){
  const css=readFileSync(join(assets,file),'utf8')
  for(const [,raw] of css.matchAll(/url\(([^)]+)\)/g)){
    const url=raw.replace(/^['"]|['"]$/g,'')
    if(url.startsWith('data:')||url.startsWith('http:')||url.startsWith('https:'))continue
    checked++
    const target=join(assets,basename(url.split('?')[0]))
    if(!existsSync(target))missing.push(`${file}: ${url}`)
  }
}
if(missing.length){console.error(`Missing ${missing.length} of ${checked} CSS assets:\n${missing.slice(0,10).join('\n')}`);process.exitCode=1}
else console.log(`CSS assets verified: ${checked} references, none missing.`)
