import { test, expect } from '@playwright/test'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test('候補、固定、履歴、お気に入り、再読込、JSON',async({page})=>{
  await page.goto('/')
  await expect(page.getByRole('heading',{name:'動く表紙の試着室'})).toBeVisible()
  await expect(page.locator('.candidate')).toHaveCount(4)
  await page.locator('.candidate-select').nth(1).click()
  await page.getByRole('checkbox',{name:'色',exact:true}).check()
  await page.getByRole('checkbox',{name:'文字組み'}).check()
  await page.getByRole('button',{name:'この案から4案'}).click()
  await expect(page.getByText('元の案から4案を作りました。')).toBeVisible()
  await expect(page.getByRole('checkbox',{name:'色',exact:true})).toBeChecked()
  await page.getByRole('button',{name:'ひとつ前の候補へ'}).click()
  await expect(page.locator('.candidate')).toHaveCount(4)
  await expect(page.locator('.candidate-select').nth(1)).toHaveAttribute('aria-pressed','true')
  await page.getByRole('button',{name:'お気に入り',exact:true}).last().click()
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible()
  await page.reload()
  await expect(page.locator('.candidate-select').nth(1)).toHaveAttribute('aria-pressed','true')
  await page.getByRole('button',{name:'書き出す'}).click()
  const jsonDownload=page.waitForEvent('download')
  await page.getByRole('button',{name:'再編集用JSON'}).click()
  const json=await jsonDownload;const path=await json.path();expect(path).toBeTruthy();expect(JSON.parse(readFileSync(path!,'utf8')).family).toBe('interference')
  await page.getByRole('button',{name:'閉じる'}).click()
  await page.locator('input[type=file]').setInputFiles(path!)
  await expect(page.getByText('JSONから作品を読み込みました。')).toBeVisible()
  await expect(page.locator('.candidate')).toHaveCount(1)
})

test('実PNGと実MP4を作成し、映像の内容を検査',async({page})=>{
  await page.goto('/')
  await page.getByRole('button',{name:'書き出す'}).click()
  const pngDownload=page.waitForEvent('download')
  await page.getByRole('button',{name:'PNG 1080px'}).click()
  const png=await pngDownload;const pngPath=await png.path();expect(readFileSync(pngPath!).subarray(0,8).toString('hex')).toBe('89504e470d0a1a0a')
  await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
  const exportStart=performance.now()
  await page.getByRole('button',{name:'動画を作る'}).click()
  await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000})
  console.log(`720 square export=${Math.round(performance.now()-exportStart)}ms`)
  const movieDownload=page.waitForEvent('download')
  await page.getByRole('button',{name:'動画を保存'}).click()
  const movie=await movieDownload;const dir=mkdtempSync(join(tmpdir(),'moving-cover-')),file=join(dir,movie.suggestedFilename());await movie.saveAs(file)
  const info=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration','-show_entries','stream=codec_name,width,height,nb_frames,r_frame_rate','-of','json',file],{encoding:'utf8'}))
  expect(info.streams).toHaveLength(1);expect(info.streams[0]).toMatchObject({codec_name:'h264',width:720,height:720,nb_frames:'180',r_frame_rate:'30/1'});expect(Number(info.format.duration)).toBeCloseTo(6,2)
})

test('4画面幅で横はみ出しがない',async({page},testInfo)=>{for(const width of [375,768,1024,1440]){await page.setViewportSize({width,height:850});await page.goto('/');await expect(page.locator('.candidate')).toHaveCount(4);expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:testInfo.outputPath(`ui-${width}.png`),fullPage:true})}})

test('縦長JSONから1080pxの実MP4を作成できる',async({page})=>{await page.goto('/');await page.locator('input[type=file]').setInputFiles('tests/fixtures/h1-portrait.json');await expect(page.locator('.candidate')).toHaveCount(1);await page.getByRole('button',{name:'書き出す'}).click();await page.getByLabel('動画のサイズ').selectOption('1080');await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled();const exportStart=performance.now();await page.getByRole('button',{name:'動画を作る'}).click();await expect(page.getByRole('button',{name:'動画を保存'})).toBeVisible({timeout:120000});console.log(`1080 portrait export=${Math.round(performance.now()-exportStart)}ms`);const wait=page.waitForEvent('download');await page.getByRole('button',{name:'動画を保存'}).click();const download=await wait,dir=mkdtempSync(join(tmpdir(),'moving-cover-')),file=join(dir,download.suggestedFilename());await download.saveAs(file);const info=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration','-show_entries','stream=width,height,nb_frames','-of','json',file],{encoding:'utf8'}));expect(info.streams[0]).toMatchObject({width:1080,height:1920,nb_frames:'180'})})

test('別タブ更新を検知し古いタブから上書きしない',async({context,page})=>{await page.goto('/');await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible();const old=await context.newPage();await old.goto('/');await expect(old.getByText('保存済み / この端末のブラウザに保存')).toBeVisible();await page.locator('.candidate-select').nth(1).click();await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible();await expect(old.getByText('別のタブで更新されました。')).toBeVisible();await old.locator('.candidate-select').nth(2).click();await expect(old.getByText('保存できません / この端末のブラウザに保存')).toBeVisible()})
