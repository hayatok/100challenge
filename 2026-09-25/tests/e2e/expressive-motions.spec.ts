import { expect, test } from '@playwright/test'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test('全36構図の実MP4で動きが見え、6秒で自然につながる',async({page})=>{
  const variants={h1:['sweep','arch','margin'],h2:['fan','gate','stack'],h3:['frame','corner','columns'],h4:['slit','steps','split'],h5:['halo','eclipse','duo'],h6:['trail','mirror','burst'],h7:['tide','crossflow','columnflow'],h8:['stringfan','lens','twist'],h9:['matrix','rift','corona'],h10:['extrude','cascade','vertical'],h11:['concentric','wavefield','tunnel'],h12:['cloud','fracture','scan']}
  const directory=mkdtempSync(join(tmpdir(),'cover-expressive-motions-'))
  await page.goto('/')
  for(const [hero,compositions] of Object.entries(variants))for(const composition of compositions){
    const recipe=JSON.parse(readFileSync(`tests/fixtures/${hero}-square.json`,'utf8'))
    recipe.shape.composition=composition
    await page.locator('input[type=file]').setInputFiles({name:'cover.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(recipe))})
    await expect(page.locator('.candidate')).toHaveCount(1)
    await page.getByRole('button',{name:'書き出す'}).click()
    await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
    await page.getByRole('button',{name:'動画を作る'}).click()
    await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})
    const pending=page.waitForEvent('download')
    await page.getByRole('button',{name:'動画を保存'}).click()
    const download=await pending,file=join(directory,`${hero}-${composition}.mp4`)
    await download.saveAs(file)
    const seam=execFileSync('node',['scripts/check-video-seams.mjs',file],{encoding:'utf8'})
    console.log(seam.trim())
    const width=180,frameBytes=width*width*3
    const frames=execFileSync('ffmpeg',['-loglevel','error','-i',file,'-vf',`scale=${width}:${width}`,'-pix_fmt','rgb24','-f','rawvideo','-'],{maxBuffer:frameBytes*181})
    const difference=(a:number,b:number)=>{let sum=0;for(let i=0;i<frameBytes;i++)sum+=Math.abs(frames[a*frameBytes+i]-frames[b*frameBytes+i]);return sum/frameBytes}
    const motion=Math.max(...[45,90,135].map(frame=>difference(0,frame)))
    console.log(`${hero}-${composition}: motion=${motion.toFixed(2)}/255`)
    expect(motion,`${hero}-${composition} is too close to a still image`).toBeGreaterThan(4)
    await page.getByRole('button',{name:'閉じる'}).click()
  }
  console.log(`Expressive motion artifacts: ${directory}`)
})
