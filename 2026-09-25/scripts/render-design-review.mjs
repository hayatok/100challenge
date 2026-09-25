import { chromium } from '@playwright/test'
import { createServer } from 'vite'
import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root=join(dirname(fileURLToPath(import.meta.url)),'..')
const server=await createServer({root,configFile:join(root,'vite.config.ts'),server:{host:'127.0.0.1',port:0}})
await server.listen()
const address=server.httpServer?.address()
if(!address||typeof address==='string')throw new Error('Vite port unavailable')
const browser=await chromium.launch({channel:'chrome',headless:true})
try{
  const page=await browser.newPage()
  await page.goto(`http://127.0.0.1:${address.port}/`)
  const sheets=await page.evaluate(async()=>{
    const {compositions}=await import('/src/domain/model.ts')
    const {loadFonts}=await import('/src/render/fonts.ts')
    const {compile}=await import('/src/render/layout.ts')
    const {drawScene}=await import('/src/render/draw.ts')
    const {heroRecipes}=await import('/src/fixtures/hero-recipes.ts')
    const results=[]
    for(const [index,base] of heroRecipes().entries()){
      if(index<6)continue
      for(const format of ['square','portrait','english']){
        const width=format==='portrait'?270:360,height=format==='portrait'?480:360
        const sheet=document.createElement('canvas');sheet.width=width*3;sheet.height=height
        const output=sheet.getContext('2d')
        const variants=compositions[base.family]
        for(const [i,composition] of variants.entries()){
          const recipe={...base,format:format==='portrait'?'portrait':'square',brief:format==='english'?{title:'PLAY\nWITH TYPE',subtitle:''}:base.brief,shape:{...base.shape,composition}}
          await loadFonts(recipe)
          const scene=compile(recipe)
          const frame=document.createElement('canvas');frame.width=width;frame.height=height
          drawScene(frame.getContext('2d'),scene,0,width)
          output.drawImage(frame,i*width,0)
        }
        results.push({name:`h${index+1}-${format}-review.png`,data:sheet.toDataURL('image/png').split(',')[1]})
      }
    }
    return results
  })
  const dir=join(root,'docs','verification','artifacts')
  await mkdir(dir,{recursive:true})
  for(const sheet of sheets)await writeFile(join(dir,sheet.name),Buffer.from(sheet.data,'base64'))
  await page.close()
}finally{await browser.close();await server.close()}
