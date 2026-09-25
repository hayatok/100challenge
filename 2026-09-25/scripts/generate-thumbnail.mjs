import { chromium } from '@playwright/test'
import { execFileSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root=join(dirname(fileURLToPath(import.meta.url)),'..')
const names=['h10-extrude','h11-concentric','h12-cloud']
const images=names.map(name=>execFileSync('ffmpeg',['-hide_banner','-loglevel','error','-i',join(root,'docs','verification','artifacts',`${name}.mp4`),'-frames:v','1','-f','image2pipe','-vcodec','png','pipe:1'],{maxBuffer:8_000_000}).toString('base64'))
const browser=await chromium.launch({channel:'chrome',headless:true})
try{
  const page=await browser.newPage({viewport:{width:1000,height:460},deviceScaleFactor:1})
  await page.setContent(`<!doctype html><html lang="ja"><meta charset="UTF-8"><style>
    *{box-sizing:border-box}body{margin:0;width:1000px;height:460px;overflow:hidden;background:#111714;color:#f6f2e8;font-family:"Hiragino Sans","Noto Sans JP",sans-serif}
    header{height:70px;margin:0 16px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #627368}
    header div{display:flex;align-items:baseline;gap:17px}h1{margin:0;font-size:30px;letter-spacing:-.07em;line-height:1}.eyebrow{font:bold 12px ui-monospace,monospace;color:#d4f75b;letter-spacing:.12em}.date{font:bold 16px ui-monospace,monospace}
    main{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;padding:10px 16px}.card{min-width:0;overflow:hidden}.card img{display:block;width:100%;height:315px;object-fit:cover}.label{height:48px;padding:12px 0;border-top:1px solid #627368;font-size:16px;font-weight:800;letter-spacing:.04em}.number{color:#d4f75b;margin-right:12px}
  </style><header><div><span class="eyebrow">MOVING COVER STUDIO</span><h1>動く表紙の試着室</h1></div><span class="date">09 / 25</span></header><main>${images.map((src,i)=>`<div class="card"><img src="data:image/png;base64,${src}"><div class="label"><span class="number">0${i+1}</span>${['迫る','干渉','散る'][i]}</div></div>`).join('')}</main></html>`)
  await page.screenshot({path:join(root,'public','moving-cover-studio.png')})
  await page.close()
}finally{await browser.close()}
