const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || '/Users/hayatok/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs');
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.join(root, 'output/mocks');
const browser = await chromium.launch({ headless: true, channel: 'chrome' });
const checks = [];
try {
  for (const filename of (await fs.readdir(dir)).filter(x => x.endsWith('.html')).sort()) {
    for (const [width, height] of [[390, 844], [360, 800]]) {
      const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
      const errors = [];
      page.on('pageerror', e => errors.push(String(e)));
      await page.goto(pathToFileURL(path.join(dir, filename)).href);
      await page.locator('.art').evaluate(async el => {
        const url = getComputedStyle(el).backgroundImage.slice(5, -2);
        const image = new Image(); image.src = url; await image.decode();
      });
      const initial = await page.locator('#description').textContent();
      const layout = await page.evaluate(() => {
        const bad = [...document.querySelectorAll('header,.panel,button')].filter(el => {
          const r = el.getBoundingClientRect();
          return r.left < -1 || r.right > innerWidth + 1 || r.top < -1 || r.bottom > innerHeight + 1 || el.scrollWidth > el.clientWidth + 1;
        }).map(el => el.className || el.tagName);
        return { bad, bodyWidth: document.body.scrollWidth, bodyHeight: document.body.scrollHeight,
          buttons: [...document.querySelectorAll('button')].map(el => ({ label: el.textContent, width: el.offsetWidth, height: el.offsetHeight })) };
      });
      await page.screenshot({ path: path.join(dir, filename.replace('.html', `-${width}.png`)) });
      const target = page.locator('.select');
      let selectCancel = null;
      if (await target.count()) {
        await target.tap();
        const changed = await page.locator('#description').textContent() !== initial;
        await page.locator('.actions button').nth(2).tap();
        selectCancel = changed && await page.locator('#description').textContent() === initial;
        await page.locator('.confirm').tap();
        if (!(await page.locator('#description').textContent()).includes('モック')) errors.push('Confirmation must label mock');
      }
      const result = { filename, width, height, ...layout, selectCancel, errors };
      checks.push(result);
      if (errors.length || layout.bad.length || layout.buttons.some(b => b.height < 44 || b.width < 44) || selectCancel === false) throw new Error(JSON.stringify(result));
      await page.close();
    }
  }
} finally {
  await browser.close();
  await fs.writeFile(path.join(root, 'docs/verification/mobile-layout.json'), JSON.stringify(checks, null, 2));
}
console.log(JSON.stringify({ checked: checks.length, viewportWidths: [390, 360], scope: 'static mock layout and selection/cancel only; not gameplay or physical-device verification' }));
