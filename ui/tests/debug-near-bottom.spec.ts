import { test } from '@playwright/test';

test.describe('Debug Scroll Detection', () => {
  test('check if nearBottom is triggered on scroll', async ({ page }) => {
    page.on('console', msg => {
      if (msg.text().includes('near:') || msg.text().includes('checkSentinelVisibility')) {
        console.log(`[${msg.type()}] ${msg.text()}`);
      }
    });

    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Check initial state
    const initial = await page.evaluate(() => {
      const sentinel = document.getElementById('scroll-sentinel');
      const rect = sentinel?.getBoundingClientRect();
      const main = document.getElementById('main-content');
      return {
        sentinelTop: rect?.top,
        scrollTop: main?.scrollTop,
        items: document.querySelectorAll('[data-timeline-item="true"]').length
      };
    });
    console.log('Initial:', JSON.stringify(initial, null, 2));

    // Scroll to bottom
    await page.evaluate(() => {
      const main = document.getElementById('main-content');
      if (main) main.scrollTop = main.scrollHeight;
    });
    await page.waitForTimeout(2000);

    // Check after scroll
    const after = await page.evaluate(() => {
      const sentinel = document.getElementById('scroll-sentinel');
      const rect = sentinel?.getBoundingClientRect();
      const main = document.getElementById('main-content');
      return {
        sentinelTop: rect?.top,
        scrollTop: main?.scrollTop,
        items: document.querySelectorAll('[data-timeline-item="true"]').length
      };
    });
    console.log('After scroll:', JSON.stringify(after, null, 2));
  });
});
