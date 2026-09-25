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
  const output=await page.evaluate(async()=>{
    const {families,palettes}=await import('/src/domain/model.ts')
    const {makeRecipe}=await import('/src/domain/generate.ts')
    const {loadFonts}=await import('/src/render/fonts.ts')
    const {compile}=await import('/src/render/layout.ts')
    const {drawScene}=await import('/src/render/draw.ts')
    const {heroRecipes}=await import('/src/fixtures/hero-recipes.ts')
    const specs={weave:['sweep','paper','noto-serif-jp-600'],fold:['fan','night','noto-sans-jp-700'],tile:['frame','blue','noto-sans-jp-700'],slice:['slit','acid','noto-sans-jp-700'],orbit:['eclipse','lilac','noto-serif-jp-600'],echo:['trail','mono','noto-sans-jp-700'],current:['tide','royal','noto-sans-jp-700'],lattice:['stringfan','cinder','noto-sans-jp-700'],glyph:['rift','carbon','noto-sans-jp-700'],monolith:['extrude','obsidian','noto-sans-jp-700'],interference:['concentric','volt','noto-sans-jp-700'],scatter:['cloud','ultramarine','noto-sans-jp-700']}
    const results=[]
    for(const family of families){
      const [composition,paletteId,fontId]=specs[family]
      const recipe=makeRecipe({title:'動く\n言葉',subtitle:''},'square',family,0,250925)
      recipe.color={paletteId,...palettes[paletteId]}
      recipe.type={...recipe.type,fontId,size:'large'}
      recipe.shape={...recipe.shape,composition,density:'medium',tilt:0}
      await loadFonts(recipe)
      const scene=compile(recipe),canvas=document.createElement('canvas')
      canvas.width=480;canvas.height=480
      drawScene(canvas.getContext('2d'),scene,0,480)
      results.push({family,image:canvas.toDataURL('image/webp',.9).split(',')[1]})
    }
    const fixtures=[]
    heroRecipes().slice(3).forEach((recipe,i)=>{
      fixtures.push({filename:`h${i+4}-square.json`,recipe})
      fixtures.push({filename:`h${i+4}-portrait.json`,recipe:{...recipe,id:crypto.randomUUID(),format:'portrait'}})
    })
    return {previews:results,fixtures}
  })
  const directory=join(root,'public','style-previews')
  await mkdir(directory,{recursive:true})
  for(const {family,image} of output.previews)await writeFile(join(directory,`${family}.webp`),Buffer.from(image,'base64'))
  for(const {filename,recipe} of output.fixtures)await writeFile(join(root,'tests','fixtures',filename),JSON.stringify(recipe,null,2)+'\n')
  await page.close()
}finally{await browser.close();await server.close()}
