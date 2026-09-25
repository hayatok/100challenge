import { test, expect } from '@playwright/test'
import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
const artifacts='docs/verification/artifacts'
test('Japanese copy exports independent HTML and audio MP4',async({page})=>{
  test.setTimeout(180000)
  await page.goto('/')
  await page.getByLabel('一行一場面で入力').fill('ひらめきを\n動かそう\n光が生まれる\n影がめぐる\n星 太陽 月\n言葉が映像になる')
  await page.getByRole('button',{name:'映像を組む'}).click()
  await expect(page.getByText('24.0 SEC')).toBeVisible()
  let downloadPromise=page.waitForEvent('download');await page.getByRole('button',{name:'単体HTML'}).click();await(await downloadPromise).saveAs(`${artifacts}/japanese-standalone.html`)
  const standalone=await page.context().newPage(),network:string[]=[];standalone.on('request',request=>{if(/^https?:/.test(request.url()))network.push(request.url())});await standalone.goto(pathToFileURL(resolve(`${artifacts}/japanese-standalone.html`)).href);await expect(standalone.getByText('再生できます')).toBeVisible();await standalone.getByRole('button',{name:'再生'}).click();await expect(standalone.getByRole('button',{name:'一時停止'})).toBeVisible();await standalone.getByRole('button',{name:'一時停止'}).click();expect(network).toEqual([]);await standalone.close()
  downloadPromise=page.waitForEvent('download',{timeout:120000});await page.getByRole('button',{name:'動画を書き出す'}).click();await(await downloadPromise).saveAs(`${artifacts}/japanese-720p.mp4`)
  await expect(page.getByText(/MP4を書き出しました/)).toBeVisible()
})
test('standalone HTML keeps project text as data',async({page})=>{
  await page.goto('/')
  await page.getByRole('textbox',{name:'作品名'}).fill('</script><script>window.pwned=1</script>')
  const downloadPromise=page.waitForEvent('download')
  await page.getByRole('button',{name:'単体HTML'}).click()
  await(await downloadPromise).saveAs(`${artifacts}/injection-standalone.html`)
  const standalone=await page.context().newPage()
  await standalone.goto(pathToFileURL(resolve(`${artifacts}/injection-standalone.html`)).href)
  await expect(standalone.getByText('再生できます')).toBeVisible()
  expect(await standalone.evaluate(()=>(window as typeof window & {pwned?:number}).pwned)).toBeUndefined()
  await standalone.close()
})
test('portrait layout exports an audio MP4',async({page})=>{
  test.setTimeout(180000);await page.goto('/');await page.getByRole('combobox',{name:'画面比率'}).selectOption('portrait');await expect(page.locator('.preview-head span')).toContainText('9:16')
  const downloadPromise=page.waitForEvent('download',{timeout:120000});await page.getByRole('button',{name:'動画を書き出す'}).click();await(await downloadPromise).saveAs(`${artifacts}/celestial-portrait-720p.mp4`)
})
test('1080p CELESTIAL audio MP4',async({page})=>{
  test.setTimeout(180000);await page.goto('/');await page.getByRole('combobox',{name:'解像度'}).selectOption('1080');const started=Date.now(),downloadPromise=page.waitForEvent('download',{timeout:120000});await page.getByRole('button',{name:'動画を書き出す'}).click();await(await downloadPromise).saveAs(`${artifacts}/celestial-1080p.mp4`);await writeFile(`${artifacts}/export-1080p-metrics.json`,JSON.stringify({elapsedMs:Date.now()-started,browser:await page.evaluate(()=>navigator.userAgent)},null,2))
})
test('60 second upper-bound project exports',async({page})=>{
  test.setTimeout(300000);await page.goto('/');const p=JSON.parse(await readFile('src/celestial.project.json','utf8'));p.id=crypto.randomUUID();p.name='60秒の検証';for(const scene of p.scenes)scene.durationTicks=9600;await page.locator('input[type=file]').setInputFiles({name:'sixty.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(p))});await expect(page.getByText('60.0 SEC')).toBeVisible();await page.getByRole('combobox',{name:'解像度'}).selectOption('1080');const started=Date.now(),downloadPromise=page.waitForEvent('download',{timeout:240000});await page.getByRole('button',{name:'動画を書き出す'}).click();await(await downloadPromise).saveAs(`${artifacts}/sixty-1080p.mp4`);await writeFile(`${artifacts}/export-sixty-metrics.json`,JSON.stringify({elapsedMs:Date.now()-started,browser:await page.evaluate(()=>navigator.userAgent)},null,2))
})
