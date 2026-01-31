import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './ui/tests',
  timeout: 30000,
  retries: 0,
  use: {
    baseURL: 'http://127.0.0.1:3030',
    headless: true,
    browserName: 'chromium',
  },
  reporter: 'list',
});
