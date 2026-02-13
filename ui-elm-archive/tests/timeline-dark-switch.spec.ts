import { test, expect } from '@playwright/test';

test('timeline dark mode after tab switch', async ({ page }) => {
  // Force dark theme
  await page.goto('/', { waitUntil: 'networkidle' });
  await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'dark'); });
  await page.goto('/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(300);

  // Navigate to timeline
  await page.goto('/timeline', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);

  // Capture initial state
  const beforeCount = await page.evaluate(() => {
    let c = 0;
    document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
      const link = el.querySelector('a[data-display-link="true"]');
      if (!link) return;
      const computed = window.getComputedStyle(link as Element).color;
      if (computed === 'rgb(0, 0, 0)') c++;
    });
    return c;
  });

  // Switch to home tab and back if tabs exist
  const tabs = page.locator('.tab-link');
  const tabCount = await tabs.count();
  if (tabCount >= 2) {
    await tabs.nth(0).click();
    await page.waitForTimeout(400);
    await tabs.nth(1).click();
    await page.waitForTimeout(800);
  } else {
    // Force a rerender via theme toggle
    await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'light'); window.location.reload(); });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(400);
    await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'dark'); window.location.reload(); });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(800);
  }

  const afterCount = await page.evaluate(() => {
    let c = 0;
    document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
      const link = el.querySelector('a[data-display-link="true"]');
      if (!link) return;
      const computed = window.getComputedStyle(link as Element).color;
      if (computed === 'rgb(0, 0, 0)') c++;
    });
    return c;
  });

  // Log and assert
  console.log('timeline dark black link counts before/after:', beforeCount, afterCount);
  expect(afterCount).toBe(0);
});
