import { test, expect } from '@playwright/test'

test('同じ作品と時刻は候補を切り替えても同じ画素',async({page})=>{await page.goto('/');await page.getByRole('button',{name:'停止'}).click();await expect(page.getByRole('button',{name:'再生'})).toBeVisible();await page.waitForTimeout(100);const first=await page.locator('.candidate .cover').first().evaluate((canvas)=> (canvas as HTMLCanvasElement).toDataURL());await page.locator('.candidate-select').nth(1).click();await page.locator('.candidate-select').first().click();await page.waitForTimeout(100);const again=await page.locator('.candidate .cover').first().evaluate((canvas)=> (canvas as HTMLCanvasElement).toDataURL());expect(again).toBe(first)})

test('reduced-motionは停止し明示再生できる',async({page})=>{await page.emulateMedia({reducedMotion:'reduce'});await page.goto('/');await expect(page.getByRole('button',{name:'再生'})).toBeVisible();await page.getByRole('button',{name:'再生'}).click();await expect(page.getByRole('button',{name:'停止'})).toBeVisible()})

test('ダイアログはキーボードで開閉しフォーカスを戻す',async({page})=>{await page.goto('/');const button=page.getByRole('button',{name:'書き出す'});await button.focus();await page.keyboard.press('Enter');await expect(page.getByRole('dialog')).toBeVisible();await expect(page.getByRole('button',{name:'閉じる'})).toBeFocused();await page.keyboard.press('Escape');await expect(page.getByRole('dialog')).not.toBeVisible();await expect(button).toBeFocused()})

test('保存不能でも制作とJSON保存を続けられる',async({page},testInfo)=>{await page.addInitScript(()=>{Object.defineProperty(indexedDB,'open',{configurable:true,value:()=>{throw new Error('Injected storage failure')}})});await page.goto('/');await expect(page.getByText('保存できません / この端末のブラウザに保存')).toBeVisible();await page.screenshot({path:testInfo.outputPath('save-error.png')});await page.getByRole('button',{name:/4案を見る/}).click();await expect(page.locator('.candidate')).toHaveCount(4);await page.getByRole('button',{name:'書き出す'}).click();const download=page.waitForEvent('download');await page.getByRole('button',{name:'再編集用JSON'}).click();await download})

test('動画不可でもPNGとJSONを使える',async({page},testInfo)=>{await page.goto('/');await page.evaluate(()=>{Object.defineProperty(window,'VideoEncoder',{configurable:true,value:undefined})});await page.getByRole('button',{name:'書き出す'}).click();await expect(page.getByText('この環境では動画を作れません。')).toBeVisible();await expect(page.getByRole('button',{name:'PNG 1080px'})).toBeEnabled();await expect(page.getByRole('button',{name:'再編集用JSON'})).toBeEnabled();await page.screenshot({path:testInfo.outputPath('video-unavailable.png')})})

test('短文・長文・和欧混植と補助文を複数表現で描ける',async({page})=>{await page.goto('/');for(const title of ['あ','『つづき』は、ここから。','生成する2026 / PLAY','あ'.repeat(32),'LONGWORDWITHOUTSPACESABCDEFGHIJK']){await page.getByRole('textbox',{name:'タイトル'}).fill(title);await page.getByRole('textbox',{name:'補助テキスト（任意）'}).fill('開催日 2026年9月25日');await page.getByRole('button',{name:/4案を見る/}).click();await expect(page.locator('.candidate')).toHaveCount(4);await expect(page.locator('[role=alert]')).toHaveCount(0)}})

test('巨大文字でも長い和欧混植タイトルと補助文を重ねずに描ける',async({page})=>{
  await page.goto('/')
  await page.getByRole('button',{name:/迫る 巨大な文字が迫る/}).click()
  await page.getByRole('textbox',{name:'タイトル'}).fill('生成する2026 / PLAY')
  await page.getByRole('textbox',{name:'補助テキスト（任意）'}).fill('開催日 2026年9月25日')
  await page.getByRole('button',{name:/4案を見る/}).click()
  await expect(page.getByText('4案を差し替えました。')).toBeVisible()
  await expect(page.locator('.candidate')).toHaveCount(4)
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('スマホの候補も静止せず再生される',async({page})=>{
  await page.setViewportSize({width:375,height:850})
  await page.goto('/')
  await expect(page.getByRole('button',{name:'停止'})).toBeVisible()
  const canvas=page.locator('.candidate canvas').first()
  await canvas.scrollIntoViewIfNeeded()
  await expect.poll(()=>canvas.evaluate(element=>(element as HTMLCanvasElement).getContext('2d')!.getImageData(50,50,1,1).data[3])).toBe(255)
  const frameHash=()=>canvas.evaluate(element=>{const bytes=(element as HTMLCanvasElement).getContext('2d')!.getImageData(0,0,480,480).data;let hash=2166136261;for(let i=0;i<bytes.length;i+=4){hash=Math.imul(hash^bytes[i],16777619);hash=Math.imul(hash^bytes[i+1],16777619);hash=Math.imul(hash^bytes[i+2],16777619)}return hash>>>0})
  const before=await frameHash()
  await page.waitForTimeout(750)
  const after=await frameHash()
  expect(after).not.toBe(before)
  await page.getByRole('button',{name:'停止'}).click()
  await expect(page.getByRole('button',{name:'再生'})).toBeVisible()
  await page.waitForTimeout(300)
  const stopped=await frameHash()
  await page.waitForTimeout(750)
  expect(await frameHash()).toBe(stopped)
  await page.getByRole('button',{name:'再生'}).click()
  await page.waitForTimeout(750)
  expect(await frameHash()).not.toBe(stopped)
})

test('30秒連続プレビューと操作時間を計測',async({page})=>{await page.goto('/');await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible();const start=performance.now();await page.getByRole('button',{name:/4案を見る/}).click();await expect(page.getByText('4案を差し替えました。')).toBeVisible();const generation=Math.round(performance.now()-start);const select=performance.now();await page.locator('.candidate-select').nth(2).click();await expect(page.locator('.candidate-select').nth(2)).toHaveAttribute('aria-pressed','true');const selection=Math.round(performance.now()-select);await page.waitForTimeout(30000);expect(await page.locator('.candidate .cover').first().evaluate(e=>(e as HTMLCanvasElement).getContext('2d')!.getImageData(20,20,1,1).data[3])).toBe(255);console.log(`Performance probe: generation=${generation}ms selection=${selection}ms preview=30000ms`)})

test('調整を閉じると未適用の編集を取り消して操作へ戻れる',async({page})=>{
  await page.goto('/')
  const details=page.locator('details')
  await details.locator('summary').click()
  await details.locator('select').first().selectOption('blue')
  await expect(page.getByRole('button',{name:'書き出す'})).toBeDisabled()
  await details.locator('summary').click()
  await expect(page.getByText('未適用の調整を取り消しました。')).toBeVisible()
  await expect(page.getByRole('button',{name:'書き出す'})).toBeEnabled()
})

test('取得済みフォントならオフラインでも生成とPNGとJSONが使える',async({page,context})=>{
  await page.goto('/')
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible()
  await context.setOffline(true)
  await page.getByRole('button',{name:/4案を見る/}).click()
  await expect(page.getByText('4案を差し替えました。')).toBeVisible()
  await page.getByRole('button',{name:'書き出す'}).click()
  for(const name of ['PNG 1080px','再編集用JSON']){
    const pending=page.waitForEvent('download')
    await page.getByRole('button',{name}).click()
    await pending
  }
})

test('フォント取得失敗を示し再読み込みで復帰する',async({page},testInfo)=>{
  await page.route(/\.woff2?$/,route=>route.abort())
  await page.goto('/')
  await expect(page.getByText('フォント読み込み失敗。再読み込みしてください。')).toBeVisible({timeout:30000})
  await expect(page.getByRole('button',{name:'再試行'})).toBeVisible()
  await page.screenshot({path:testInfo.outputPath('font-error.png')})
  await page.unroute(/\.woff2?$/)
  await page.getByRole('button',{name:'再試行'}).click()
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible({timeout:30000})
})

test('同梱日本語の未使用文字もオフラインで生成できる',async({page,context})=>{
  await page.goto('/')
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible()
  await context.setOffline(true)
  await page.getByRole('textbox',{name:'タイトル'}).fill('鬱')
  await page.getByRole('button',{name:/4案を見る/}).click()
  await expect(page.getByText('4案を差し替えました。')).toBeVisible()
  await expect(page.locator('.candidate')).toHaveCount(4)
  await expect(page.locator('.candidate canvas').first()).toHaveAttribute('aria-label',/鬱/)
})

test('50回の候補切替と3回の出力後も描画hostが増えない',async({page})=>{
  await page.goto('/')
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible()
  await page.getByRole('button',{name:'停止'}).click()
  for(let i=0;i<50;i++)await page.locator('.candidate-select').nth(i%4).click()
  await page.getByRole('button',{name:'書き出す'}).click()
  for(let i=0;i<3;i++){
    const pending=page.waitForEvent('download')
    await page.getByRole('button',{name:'PNG 1080px'}).click()
    await pending
  }
  await page.getByRole('button',{name:'閉じる'}).click()
  expect(await page.locator('body > div[style*="display: none"] canvas').count()).toBe(1)
  await page.getByRole('button',{name:/4案を見る/}).click()
  await expect(page.getByText('4案を差し替えました。')).toBeVisible()
})

test('空・入力エラー・無効・フォーカス状態の画像を残す',async({page},testInfo)=>{
  await page.goto('/')
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible()
  await page.getByRole('button',{name:'お気に入り'}).first().click()
  await expect(page.getByText('お気に入りはまだありません。')).toBeVisible()
  await page.screenshot({path:testInfo.outputPath('favorite-empty.png')})
  await page.getByRole('button',{name:'閉じる'}).click()
  await page.getByRole('textbox',{name:'タイトル'}).fill('')
  await page.getByRole('button',{name:/4案を見る/}).click()
  await expect(page.getByRole('alert')).toBeVisible()
  await page.screenshot({path:testInfo.outputPath('input-error.png')})
  await page.getByRole('textbox',{name:'タイトル'}).fill('余白の、\nその先。')
  for(const name of ['色','文字組み','形','動き'])await page.getByRole('checkbox',{name}).check()
  await expect(page.getByRole('button',{name:'この案から4案'})).toBeDisabled()
  await page.screenshot({path:testInfo.outputPath('all-locked.png')})
  await page.getByRole('button',{name:'書き出す'}).focus()
  await page.keyboard.press('Shift+Tab')
  await page.keyboard.press('Tab')
  await expect(page.getByRole('button',{name:'書き出す'})).toBeFocused()
  await page.screenshot({path:testInfo.outputPath('keyboard-focus.png')})
})

test('フォント読込中は完成作品として見せない',async({page})=>{
  await page.route(/\.woff2?$/,async route=>{await new Promise(resolve=>setTimeout(resolve,1800));await route.continue()})
  await page.goto('/',{waitUntil:'domcontentloaded'})
  await expect(page.getByText('文字と作品を準備しています…')).toBeVisible()
  expect(await page.locator('.candidate .cover').first().evaluate(element=>(element as HTMLCanvasElement).getContext('2d')!.getImageData(20,20,1,1).data[3])).toBe(0)
  await expect(page.getByText('保存済み / この端末のブラウザに保存')).toBeVisible({timeout:30000})
})

test('1080px非対応なら形式を選ばせず720pxへ戻せる',async({page})=>{
  await page.goto('/')
  await page.getByRole('button',{name:'書き出す'}).click()
  await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
  await page.evaluate(()=>{
    const original=VideoEncoder.isConfigSupported
    VideoEncoder.isConfigSupported=async function(config){
      if(config.width>=1080)return {supported:false,config}
      return original.call(this,config)
    }
  })
  await page.getByLabel('動画のサイズ').selectOption('1080')
  await expect(page.getByText('この環境では動画を作れません。')).toBeVisible()
  await page.getByLabel('動画のサイズ').selectOption('720')
  await expect(page.getByRole('button',{name:'動画を作る'})).toBeEnabled()
})

test('入力と作品を外部originへ送らない',async({page})=>{
  const external:string[]=[]
  page.on('request',request=>{if(new URL(request.url()).origin!=='http://127.0.0.1:4177')external.push(request.url())})
  await page.goto('/')
  await page.getByRole('textbox',{name:'タイトル'}).fill('秘密ではない制作テスト')
  await page.getByRole('button',{name:/4案を見る/}).click()
  await expect(page.getByText('4案を差し替えました。')).toBeVisible()
  await page.getByRole('button',{name:'書き出す'}).click()
  const pending=page.waitForEvent('download')
  await page.getByRole('button',{name:'PNG 1080px'}).click()
  await pending
  expect(external).toEqual([])
})
