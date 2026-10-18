import { test, expect, type Page } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import { Input, BlobSource, ALL_FORMATS } from 'mediabunny'
import { toneWav } from './helpers'

const ready = (page: Page) => expect(page.getByText('準備完了 — 通信を切っても編集・保存できます。')).toBeVisible()
const upload = (page: Page, buffer = toneWav(), name = 'テスト音声_左右で音が違う.wav') => page.getByLabel('音声ファイル', { exact: true }).setInputFiles({ name, mimeType: 'audio/wav', buffer })
async function select(page: Page, start = '1.125', end = '3.500') {
  await page.getByLabel('開始時刻', { exact: true }).fill(start)
  await page.getByLabel('終了時刻', { exact: true }).fill(end)
}

async function inspect(bytes: Buffer, page: Page) {
  const input = new Input({ source: new BlobSource(new Blob([new Uint8Array(bytes)])), formats: ALL_FORMATS })
  try {
    const track = await input.getPrimaryAudioTrack()
    expect(track).not.toBeNull()
    const codec = await track!.getCodec()
    const sampleRate = await track!.getSampleRate()
    const channels = await track!.getNumberOfChannels()
    const duration = await input.computeDuration()
    const decoded = await page.evaluate(async (base64) => {
      const data = Uint8Array.from(atob(base64), c => c.charCodeAt(0))
      const buffer = await new OfflineAudioContext(2, 1, 48000).decodeAudioData(data.buffer)
      function dominant(channel: number, time: number) {
        const samples = buffer.getChannelData(channel)
        const first = Math.round(time * buffer.sampleRate)
        const size = Math.round(0.1 * buffer.sampleRate)
        const choices = [440, 660, 880, 1320, 1760, 2640]
        return choices.map(f => {
          let real = 0, imag = 0
          for (let i = 0; i < size; i++) {
            const angle = 2 * Math.PI * f * i / buffer.sampleRate
            real += samples[first + i] * Math.cos(angle)
            imag += samples[first + i] * Math.sin(angle)
          }
          return { f, power: real * real + imag * imag }
        }).sort((a,b) => b.power - a.power)[0].f
      }
      return { duration: buffer.duration, channels: buffer.numberOfChannels, left: [dominant(0,0.25), dominant(0,1.25)], right: buffer.numberOfChannels > 1 ? [dominant(1,0.25), dominant(1,1.25)] : [] }
    }, bytes.toString('base64'))
    return { codec, sampleRate, channels, duration, decoded }
  } finally { input.dispose() }
}

test('通信遮断中に両形式を保存し、codec・長さ・左右の選択区間が一致する', async ({ page, context }, info) => {
  const httpRequests: { url: string; method: string }[] = []
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  page.on('request', request => { if (/^https?:/.test(request.url())) httpRequests.push({ url: request.url(), method: request.method() }) })
  await page.goto('/')
  await ready(page)
  expect(httpRequests.every(r => r.method === 'GET' && r.url.startsWith('http://127.0.0.1:4189/'))).toBe(true)
  const initialRequests = httpRequests.length
  await context.setOffline(true)
  await upload(page)
  await expect(page.getByRole('heading', { name: '残す範囲を選ぶ' })).toBeVisible()
  await select(page)
  await expect(page.getByLabel('選択開始', { exact: true })).toHaveAttribute('aria-valuenow', '1.125')
  await page.getByRole('button', { name: '選択範囲を試聴' }).click()
  await expect(page.getByRole('button', { name: '停止', exact: true })).toBeVisible()
  await page.getByRole('button', { name: '停止', exact: true }).click()
  const reports = []
  const files: { format: 'mp3' | 'm4a'; bytes: Buffer }[] = []
  for (const format of ['mp3', 'm4a'] as const) {
    await page.getByRole('radio', { name: format === 'mp3' ? 'MP3' : 'M4A (AAC)', exact: true }).check()
    await page.getByRole('button', { name: `${format.toUpperCase()}を書き出す`, exact: true }).click()
    await expect(page.getByText('書き出しが完了しました', { exact: true })).toBeVisible()
    const downloadPromise = page.waitForEvent('download')
    await page.getByRole('link', { name: 'ファイルを保存', exact: true }).click()
    const download = await downloadPromise
    expect(download.suggestedFilename()).toMatch(new RegExp(`\\.${format}$`))
    const outputPath = info.outputPath(`selected.${format}`)
    await download.saveAs(outputPath)
    const bytes = await readFile(outputPath)
    files.push({ format, bytes })
    expect(bytes.byteLength).toBeGreaterThan(1000)
    if (format === 'm4a') expect(bytes.toString('ascii', 4, 8)).toBe('ftyp')
    const result = await inspect(bytes, page)
    expect(result.codec).toBe(format === 'mp3' ? 'mp3' : 'aac')
    expect(result.channels).toBe(2)
    expect(result.sampleRate).toBe(48000)
    expect(result.duration).toBeGreaterThanOrEqual(2.375)
    expect(result.duration).toBeLessThan(2.475)
    expect(result.decoded.channels).toBe(2)
    expect(result.decoded.left).toEqual([440, 880])
    expect(result.decoded.right).toEqual([660, 1320])
    await page.getByLabel('書き出した音声を確認', { exact: true }).evaluate((element: HTMLAudioElement) => element.play())
    await expect.poll(() => page.locator('audio').evaluate((element: HTMLAudioElement) => element.currentTime)).toBeGreaterThan(0)
    await page.locator('audio').evaluate((element: HTMLAudioElement) => element.pause())
    reports.push({ format, bytes: bytes.byteLength, ...result })
  }
  for (const file of files) {
    await page.getByLabel('音声ファイル', { exact: true }).setInputFiles({ name: `再読込.${file.format}`, mimeType: file.format === 'mp3' ? 'audio/mpeg' : 'audio/mp4', buffer: file.bytes })
    await expect(page.getByText(`再読込.${file.format}`, { exact: true })).toBeVisible()
  }
  expect(httpRequests.slice(initialRequests)).toEqual([])
  expect(errors).toEqual([])
  const evidence = JSON.stringify({ reports, httpAfterReady: httpRequests.slice(initialRequests), errors }, null, 2)
  await info.attach('codec-and-audio-verification', { body: evidence, contentType: 'application/json' })
  const { writeFile } = await import('node:fs/promises')
  await writeFile(info.outputPath('evidence.json'), evidence)
})

test('ドラッグ・ハンドル・拡大・時刻入力・試聴ループを操作できる', async ({ page }) => {
  await page.goto('/'); await ready(page); await upload(page)
  const track = page.locator('.wave-track')
  const rect = (await track.boundingBox())!
  await page.mouse.move(rect.x + rect.width * 0.2, rect.y + rect.height * 0.55)
  await page.mouse.down(); await page.mouse.move(rect.x + rect.width * 0.6, rect.y + rect.height * 0.55, { steps: 8 }); await page.mouse.up()
  expect(Number(await page.getByRole('slider', { name: '選択開始', exact: true }).getAttribute('aria-valuenow'))).toBeCloseTo(1.6, 1)
  expect(Number(await page.getByRole('slider', { name: '選択終了', exact: true }).getAttribute('aria-valuenow'))).toBeCloseTo(4.8, 1)
  const before = Number(await page.getByRole('slider', { name: '選択開始' }).getAttribute('aria-valuenow'))
  await page.getByRole('slider', { name: '選択開始' }).press('ArrowRight')
  expect(Number(await page.getByRole('slider', { name: '選択開始' }).getAttribute('aria-valuenow'))).toBeCloseTo(before + 0.01, 3)
  await page.getByRole('button', { name: '波形を拡大', exact: true }).click()
  await expect(page.getByText('2×', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: '全体表示', exact: true }).click()
  await select(page, '1', '1.25')
  await page.getByRole('checkbox', { name: 'ループ再生' }).check()
  await page.getByRole('button', { name: '選択範囲を試聴' }).click()
  await page.waitForTimeout(700)
  await expect(page.getByRole('button', { name: '停止', exact: true })).toBeVisible()
  await page.getByRole('button', { name: '停止', exact: true }).click()
  await page.getByLabel('終了時刻', { exact: true }).fill('0.5')
  await expect(page.getByRole('button', { name: 'MP3を書き出す', exact: true })).toBeDisabled()
  await expect(page.getByRole('button', { name: '選択範囲を試聴' })).toBeDisabled()
  await expect(page.getByRole('alert')).toContainText('終了を開始より後')
  await page.getByLabel('終了時刻', { exact: true }).fill('2.500')
  await expect(page.getByRole('button', { name: 'MP3を書き出す', exact: true })).toBeEnabled()
})

test('空・破損・長すぎる入力から、同じ画面で復帰できる', async ({ page }) => {
  await page.goto('/'); await ready(page)
  await upload(page, Buffer.alloc(0), 'empty.wav')
  await expect(page.getByRole('alert')).toContainText('空のファイル')
  await upload(page, Buffer.from('not audio'), 'broken.wav')
  await expect(page.getByRole('alert')).toContainText('読み込めません')
  await upload(page, toneWav(601, 1, 8000), '10分を超える.wav')
  await expect(page.getByRole('alert')).toContainText('10分を超えています')
  await upload(page, toneWav(2, 6), 'surround.wav')
  await expect(page.getByRole('alert')).toContainText('モノラルまたはステレオ')
  await upload(page, toneWav(4, 1, 22050), 'mono.wav')
  await expect(page.getByText(/モノラル.*編集 48 kHz/)).toBeVisible()
  await select(page, '0', '0.020')
  await page.getByRole('button', { name: 'MP3を書き出す', exact: true }).click()
  await expect(page.getByText('書き出しが完了しました', { exact: true })).toBeVisible()
  await page.getByLabel('開始時刻', { exact: true }).fill('0.050')
  await expect(page.getByRole('link', { name: 'ファイルを保存', exact: true })).toHaveCount(0)
})

test('実デコード待ちをキャンセルし、次の読み込みで古い結果が復活しない', async ({ page }) => {
  await page.addInitScript(() => {
    const original = OfflineAudioContext.prototype.decodeAudioData
    OfflineAudioContext.prototype.decodeAudioData = function(data: ArrayBuffer) {
      return new Promise<AudioBuffer>((resolve, reject) => setTimeout(() => original.call(this, data).then(resolve, reject), 800))
    }
  })
  await page.goto('/'); await ready(page)
  await upload(page, toneWav(4), 'old.wav')
  await page.getByRole('button', { name: '読み込みをキャンセル', exact: true }).click()
  await expect(page.getByText('読み込みをキャンセルしました。ファイルを選び直せます。')).toBeVisible()
  await upload(page, toneWav(3), 'new.wav')
  await expect(page.getByText('new.wav', { exact: true })).toBeVisible()
  await expect(page.getByText('old.wav', { exact: true })).toHaveCount(0)
})

test('書き出しキャンセル後に、別形式で保存し直せる', async ({ page }) => {
  await page.goto('/'); await ready(page); await upload(page, toneWav(60), 'long.wav')
  await page.getByRole('button', { name: 'MP3を書き出す', exact: true }).click()
  await page.getByRole('button', { name: '書き出しをキャンセル', exact: true }).click()
  await expect(page.getByText('書き出しをキャンセルしました。設定を確認して、もう一度書き出せます。')).toBeVisible()
  await select(page, '2', '4')
  await page.getByRole('radio', { name: 'M4A (AAC)', exact: true }).check()
  await page.getByRole('button', { name: 'M4Aを書き出す', exact: true }).click()
  await expect(page.getByText('書き出しが完了しました', { exact: true })).toBeVisible()
})

test('初期準備の一時的な失敗を説明し、再試行できる', async ({ page }) => {
  await page.addInitScript(() => {
    const Original = AudioBuffer
    let once = true
    window.AudioBuffer = new Proxy(Original, { construct(target, args) {
      if (once) { once = false; throw new Error('準備テスト：一時的な初期化失敗') }
      return Reflect.construct(target, args)
    } })
  })
  await page.goto('/')
  await expect(page.getByText(/音声処理を準備できませんでした/)).toBeVisible()
  await page.getByRole('button', { name: '準備を再試行', exact: true }).click()
  await ready(page)
})

test('書き出し中の失敗を説明し、同じ入力から実エンコードを再試行できる', async ({ page }) => {
  await page.addInitScript(() => {
    const original = AudioBuffer.prototype.copyToChannel
    let armed = false, used = false
    document.addEventListener('click', event => {
      if ((event.target as Element).closest('button')?.textContent === 'MP3を書き出す' && !used) armed = true
    }, true)
    AudioBuffer.prototype.copyToChannel = function(...args: Parameters<AudioBuffer['copyToChannel']>) {
      if (armed) { armed = false; used = true; throw new Error('検証用：一時的なバッファ処理失敗') }
      original.apply(this, args)
    }
  })
  await page.goto('/'); await ready(page); await upload(page)
  await select(page)
  await page.getByRole('button', { name: 'MP3を書き出す', exact: true }).click()
  await expect(page.getByRole('alert')).toContainText('書き出せませんでした')
  await expect(page.getByRole('link', { name: 'ファイルを保存', exact: true })).toHaveCount(0)
  await page.getByRole('button', { name: 'もう一度書き出す', exact: true }).click()
  await expect(page.getByText('書き出しが完了しました', { exact: true })).toBeVisible()
})

for (const width of [1440, 768, 375]) test(`${width}pxで長いファイル名と結果がはみ出さない`, async ({ page }, info) => {
  await page.setViewportSize({ width, height: 1000 })
  await page.goto('/'); await ready(page)
  await page.screenshot({ path: info.outputPath(`empty-${width}.png`), fullPage: true })
  await upload(page, toneWav(4), 'とても長いファイル名でも内容を選択して安全に保存できるか確認するためのテスト音声です_2026-10-18.wav')
  await select(page, '0.1', '2.3')
  await page.getByRole('radio', { name: 'M4A (AAC)', exact: true }).check()
  await page.getByRole('button', { name: 'M4Aを書き出す', exact: true }).click()
  await expect(page.getByRole('link', { name: 'ファイルを保存' })).toBeVisible()
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)
  expect(overflow).toBeLessThanOrEqual(1)
  for (const control of [page.getByLabel('開始時刻', { exact: true }), page.getByRole('button', { name: '選択範囲を試聴' }), page.getByRole('link', { name: 'ファイルを保存' })]) {
    const bounds = (await control.boundingBox())!
    expect(bounds.height).toBeGreaterThanOrEqual(44)
    expect(bounds.x).toBeGreaterThanOrEqual(0)
    expect(bounds.x + bounds.width).toBeLessThanOrEqual(width + 1)
  }
  await page.screenshot({ path: info.outputPath(`result-${width}.png`), fullPage: true })
})
