import { test, expect } from '@playwright/test'
import { readFileSync, mkdtempSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test('36構図×2比率で実PNGを描画できる',async({page})=>{
  const compositions={h1:['sweep','arch','margin'],h2:['fan','gate','stack'],h3:['frame','corner','columns'],h4:['slit','steps','split'],h5:['halo','eclipse','duo'],h6:['trail','mirror','burst'],h7:['tide','crossflow','columnflow'],h8:['stringfan','lens','twist'],h9:['matrix','rift','corona'],h10:['extrude','cascade','vertical'],h11:['concentric','wavefield','tunnel'],h12:['cloud','fracture','scan']} as const
  const directory=mkdtempSync(join(tmpdir(),'cover-compositions-'))
  await page.goto('/')
  for(const [hero,variants] of Object.entries(compositions))for(const format of ['square','portrait'])for(const composition of variants){
    const base=JSON.parse(readFileSync(`tests/fixtures/${hero}-${format}.json`,'utf8'))
    base.shape.composition=composition
    await page.locator('input[type=file]').setInputFiles({name:'cover.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(base))})
    await expect(page.locator('.candidate')).toHaveCount(1)
    await page.getByRole('button',{name:'書き出す'}).click()
    const pending=page.waitForEvent('download')
    await page.getByRole('button',{name:'PNG 1080px'}).click()
    const file=await pending;await file.saveAs(join(directory,`${hero}-${format}-${composition}.png`))
    await page.getByRole('button',{name:'閉じる'}).click()
  }
  console.log(`Composition PNG artifacts: ${directory}`)
})

test('36構図×2比率で英字改行の実PNGを描画できる',async({page})=>{
  const compositions={h1:['sweep','arch','margin'],h2:['fan','gate','stack'],h3:['frame','corner','columns'],h4:['slit','steps','split'],h5:['halo','eclipse','duo'],h6:['trail','mirror','burst'],h7:['tide','crossflow','columnflow'],h8:['stringfan','lens','twist'],h9:['matrix','rift','corona'],h10:['extrude','cascade','vertical'],h11:['concentric','wavefield','tunnel'],h12:['cloud','fracture','scan']} as const
  const directory=mkdtempSync(join(tmpdir(),'cover-english-'))
  await page.goto('/')
  for(const [hero,variants] of Object.entries(compositions))for(const format of ['square','portrait'])for(const composition of variants){
    const base=JSON.parse(readFileSync(`tests/fixtures/${hero}-${format}.json`,'utf8'))
    base.shape.composition=composition
    base.brief.title='PLAY\nWITH TYPE'
    await page.locator('input[type=file]').setInputFiles({name:'cover.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(base))})
    await expect(page.locator('.candidate')).toHaveCount(1)
    await page.getByRole('button',{name:'書き出す'}).click()
    const pending=page.waitForEvent('download')
    await page.getByRole('button',{name:'PNG 1080px'}).click()
    const file=await pending;await file.saveAs(join(directory,`${hero}-${format}-${composition}.png`))
    await page.getByRole('button',{name:'閉じる'}).click()
  }
  console.log(`English composition PNG artifacts: ${directory}`)
})
