import { test } from '@playwright/test';

test.describe('Debug Scroll Position', () => {
  test('check scrollTop after scroll', async ({ page }) => {
    page.on('console', msg => console.log(`[${msg.type()}] ${msg.text()}`));

    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    const before = await page.evaluate(() => {
      return { scrollY: window.scrollY, scrollHeight: document.body.scrollHeight, innerHeight: window.innerHeight };
    });
    console.log('Before scroll:', JSON.stringify(before, null, 2));

    // Scroll to bottom using body scroll
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });
    await page.waitForTimeout(500);

    const after = await page.evaluate(() => {
      return { scrollY: window.scrollY, scrollHeight: document.body.scrollHeight, innerHeight: window.innerHeight };
    });
    console.log('After scroll:', JSON.stringify(after, null, 2));

    // Check sentinel position
    const sentinel = await page.evaluate(() => {
      const s = document.getElementById('scroll-sentinel');
      if (!s) return null;
      const rect = s.getBoundingClientRect();
      return { top: rect.top, bottom: rect.bottom, viewportHeight: window.innerHeight };
    });
    console.log('Sentinel position:', JSON.stringify(sentinel, null, 2));
  });
});
