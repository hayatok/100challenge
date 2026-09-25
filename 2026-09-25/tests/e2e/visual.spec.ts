import { test, expect } from '@playwright/test'
import { execFileSync } from 'node:child_process'
import { mkdtempSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test('生成したMP4をChromeで実際に再生できる',async({page})=>{
  await page.goto('/')
  await page.locator('input[type=file]').setInputFiles('tests/fixtures/h12-square.json')
  await page.getByRole('button',{name:'書き出す'}).click()
  await page.getByRole('button',{name:'動画を作る'}).click()
  await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})
  const video=page.locator('video.export-preview')
  await video.evaluate(async element=>{await (element as HTMLVideoElement).play()})
  await expect.poll(()=>video.evaluate(element=>({time:(element as HTMLVideoElement).currentTime,width:(element as HTMLVideoElement).videoWidth}))).toMatchObject({time:expect.any(Number),width:720})
  await expect.poll(()=>video.evaluate(element=>(element as HTMLVideoElement).currentTime)).toBeGreaterThan(1)
})

test('H1〜H12の正方形・縦長を実動画で描く',async({page})=>{
  await page.goto('/')
  const directory=mkdtempSync(join(tmpdir(),'cover-heroes-'))
  for(const family of ['h1','h2','h3','h4','h5','h6','h7','h8','h9','h10','h11','h12'])for(const format of ['square','portrait']){
    await page.locator('input[type=file]').setInputFiles(`tests/fixtures/${family}-${format}.json`)
    await expect(page.locator('.candidate')).toHaveCount(1)
    await page.getByRole('button',{name:'書き出す'}).click()
    await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
    await page.getByRole('button',{name:'動画を作る'}).click()
    await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})
    const downloadPromise=page.waitForEvent('download')
    await page.getByRole('button',{name:'動画を保存'}).click()
    const download=await downloadPromise,file=join(directory,`${family}-${format}.mp4`);await download.saveAs(file)
    const info=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration','-show_entries','stream=width,height,nb_frames','-of','json',file],{encoding:'utf8'}))
    expect(info.streams[0]).toMatchObject({width:720,height:format==='square'?720:1280,nb_frames:'180'})
    expect(Number(info.format.duration)).toBeCloseTo(6,2)
    await page.getByRole('button',{name:'閉じる'}).click()
  }
  console.log(`Visual video artifacts: ${directory}`)
})

test('キャンセル後に再度動画を作れる',async({page})=>{await page.goto('/');await page.getByRole('button',{name:'書き出す'}).click();await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled();await page.getByRole('button',{name:'動画を作る'}).click();await page.getByRole('button',{name:'キャンセル'}).click();await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled();await expect(page.getByRole('button',{name:'動画を保存'})).toHaveCount(0);await page.getByRole('button',{name:'動画を作る'}).click();await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})})

test('エンコーダ失敗後も再試行できる',async({page})=>{await page.goto('/');await page.getByRole('button',{name:'書き出す'}).click();await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled();await page.evaluate(()=>{const scope=window as unknown as Window & {originalEncode:typeof VideoEncoder.prototype.encode};scope.originalEncode=VideoEncoder.prototype.encode;VideoEncoder.prototype.encode=function(){throw new Error('Injected encoder failure')}});await page.getByRole('button',{name:'動画を作る'}).click();await expect(page.getByText('Injected encoder failure')).toBeVisible();await expect(page.getByRole('button',{name:'動画を保存'})).toHaveCount(0);await page.evaluate(()=>{const scope=window as unknown as Window & {originalEncode:typeof VideoEncoder.prototype.encode};VideoEncoder.prototype.encode=scope.originalEncode});await page.getByRole('button',{name:'動画を作る'}).click();await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})})

test('90フレーム付近でキャンセルして制作に戻れる',async({page})=>{await page.goto('/');await page.getByRole('button',{name:'書き出す'}).click();await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled();await page.getByRole('button',{name:'動画を作る'}).click();await page.waitForFunction(()=>Number(document.querySelector('progress')?.value??0)>=90);await page.getByRole('button',{name:'キャンセル'}).click();await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled();await expect(page.getByRole('button',{name:'動画を保存'})).toHaveCount(0);await page.getByRole('button',{name:'閉じる'}).click();await page.getByRole('button',{name:/4案を見る/}).click();await expect(page.locator('.candidate')).toHaveCount(4)})

test('最終処理中のキャンセルで完成Blobを渡さず再試行できる',async({page})=>{
  await page.goto('/')
  await page.getByRole('button',{name:'書き出す'}).click()
  await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
  await page.evaluate(()=>{
    const scope=window as unknown as Window & {originalFlush:typeof VideoEncoder.prototype.flush}
    scope.originalFlush=VideoEncoder.prototype.flush
    VideoEncoder.prototype.flush=function(){return new Promise((resolve,reject)=>setTimeout(()=>scope.originalFlush.call(this).then(resolve,reject),600))}
  })
  await page.getByRole('button',{name:'動画を作る'}).click()
  await page.waitForFunction(()=>Number(document.querySelector('progress')?.value??0)===180)
  await page.getByRole('button',{name:'キャンセル'}).click()
  await expect(page.getByText('動画をキャンセルしました。')).toBeVisible()
  await expect(page.getByRole('button',{name:'動画を保存'})).toHaveCount(0)
  await page.evaluate(()=>{
    const scope=window as unknown as Window & {originalFlush:typeof VideoEncoder.prototype.flush}
    VideoEncoder.prototype.flush=scope.originalFlush
  })
  await page.getByRole('button',{name:'動画を作る'}).click()
  await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})
})

test('12表現の動画4時刻が同じ描画処理のPNGと一致する',async({page})=>{
  await page.goto('/')
  const directory=mkdtempSync(join(tmpdir(),'cover-frame-match-'))
  for(const family of ['h1','h2','h3','h4','h5','h6','h7','h8','h9','h10','h11','h12']){
    await page.locator('input[type=file]').setInputFiles(`tests/fixtures/${family}-square.json`)
    await expect(page.locator('.candidate')).toHaveCount(1)
    await page.getByRole('button',{name:'書き出す'}).click()
    await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
    await page.getByRole('button',{name:'動画を作る'}).click()
    await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})
    const moviePending=page.waitForEvent('download')
    await page.getByRole('button',{name:'動画を保存'}).click()
    const movie=await moviePending,moviePath=join(directory,`${family}.mp4`)
    await movie.saveAs(moviePath)
    for(const frame of [0,45,90,135]){
      await page.locator('dialog input[type=range]').evaluate((element,value)=>{
        const setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value')!.set!
        setter.call(element,String(value))
        element.dispatchEvent(new Event('input',{bubbles:true}))
        element.dispatchEvent(new Event('change',{bubbles:true}))
      },frame)
      await expect(page.getByText(`PNGのフレーム ${frame}/179`)).toBeVisible()
      const pngPending=page.waitForEvent('download')
      await page.getByRole('button',{name:'PNG 1080px'}).click()
      const png=await pngPending,pngPath=join(directory,`${family}-${frame}.png`)
      await png.saveAs(pngPath)
      const reference=execFileSync('ffmpeg',['-loglevel','error','-i',pngPath,'-vf','scale=720:720','-pix_fmt','rgb24','-f','rawvideo','-'],{maxBuffer:10*1024*1024})
      const decoded=execFileSync('ffmpeg',['-loglevel','error','-i',moviePath,'-vf',`select=eq(n\\,${frame})`,'-vsync','0','-frames:v','1','-pix_fmt','rgb24','-f','rawvideo','-'],{maxBuffer:10*1024*1024})
      expect(reference.length).toBe(decoded.length)
      let total=0;for(let i=0;i<reference.length;i++)total+=Math.abs(reference[i]-decoded[i])
      const mae=total/reference.length
      expect(mae,`${family} frame ${frame} MAE ${mae}`).toBeLessThan(12)
      console.log(`${family} frame=${frame} MAE=${mae.toFixed(2)}/255`)
    }
    await page.getByRole('button',{name:'閉じる'}).click()
  }
})
