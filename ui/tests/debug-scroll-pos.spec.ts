import { test } from '@playwright/test';

test.describe('Debug Scroll Position', () => {
  test('check scrollTop after scroll', async ({ page }) => {
    page.on('console', msg => console.log(`[${msg.type()}] ${msg.text()}`));

    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    const before = await page.evaluate(() => {
      const main = document.getElementById('main-content');
      return main ? { scrollTop: main.scrollTop, scrollHeight: main.scrollHeight, clientHeight: main.clientHeight } : null;
    });
    console.log('Before scroll:', JSON.stringify(before, null, 2));

    // Scroll to bottom
    await page.evaluate(() => {
      const main = document.getElementById('main-content');
      if (main) main.scrollTop = main.scrollHeight;
    });
    await page.waitForTimeout(500);

    const after = await page.evaluate(() => {
      const main = document.getElementById('main-content');
      return main ? { scrollTop: main.scrollTop, scrollHeight: main.scrollHeight, clientHeight: main.clientHeight } : null;
    });
    console.log('After scroll:', JSON.stringify(after, null, 2));

    // Check sentinel position
    const sentinel = await page.evaluate(() => {
      const s = document.getElementById('scroll-sentinel');
      if (!s) return null;
      const rect = s.getBoundingClientRect();
      return { top: rect.top, bottom: rect.bottom };
    });
    console.log('Sentinel position:', JSON.stringify(sentinel, null, 2));
  });
});
