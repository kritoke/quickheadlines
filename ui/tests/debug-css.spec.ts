import { test } from '@playwright/test';

test('debug css and observer state', async ({ page }) => {
  await page.goto('/timeline');
  await page.waitForLoadState('networkidle');

  const observerText = await page.locator('.qh-observer-indicator').innerText().catch(() => 'missing');
  console.log('Observer indicator text:', observerText);

  const loadMore = await page.locator('.qh-load-more').first().elementHandle();
  if (loadMore) {
    const outer = await page.evaluate(e => e.outerHTML, loadMore);
    const style = await page.evaluate(e => window.getComputedStyle(e).cssText, loadMore);
    console.log('Found .qh-load-more element outerHTML:', outer);
    console.log('Computed style cssText snippet:', style.substring(0, 200));
  } else {
    console.log('No .qh-load-more element found');
  }

  const inserted = await page.locator('.timeline-inserted').count();
  console.log('timeline-inserted count:', inserted);
});
