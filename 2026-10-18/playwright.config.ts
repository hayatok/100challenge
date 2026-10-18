import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: './tests/browser',
  timeout: 60000,
  expect: { timeout: 15000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list']],
  use: { baseURL: 'http://127.0.0.1:4189', browserName: 'chromium', viewport: { width: 1440, height: 1000 }, acceptDownloads: true },
  webServer: { command: 'npm run preview -- --port 4189 --strictPort', url: 'http://127.0.0.1:4189', reuseExistingServer: !process.env.CI },
})
