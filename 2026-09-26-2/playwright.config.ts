import { defineConfig } from '@playwright/test'
export default defineConfig({testDir:'tests',testMatch:'*.spec.ts',timeout:120000,use:{baseURL:'http://127.0.0.1:5173',browserName:'chromium'},webServer:{command:'npm run dev',url:'http://127.0.0.1:5173',reuseExistingServer:true,timeout:30000}})
