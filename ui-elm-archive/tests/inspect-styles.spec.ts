import { test, expect } from '@playwright/test';

test('inspect loaded styles and interaction', async ({ page }) => {
  await page.goto('/timeline');
  await page.waitForLoadState('networkidle');

  const sheets = await page.evaluate(() => {
    return Array.from(document.styleSheets).map(s => ({ href: s.href || null, rules: s.cssRules ? Array.from(s.cssRules).map(r => r.selectorText || r.cssText) : [] }));
  });
  console.log('Loaded stylesheets (count):', sheets.length);
  sheets.forEach((s, i) => console.log(i, s.href, (s.rules || []).slice(0,5)));

  const hasLoadMoreRule = await page.evaluate(() => {
    for (const s of document.styleSheets) {
      try {
        for (const r of (s.cssRules || [])) {
          if (r.selectorText && r.selectorText.includes('.qh-load-more')) return true;
        }
      } catch (e) { /* ignore CORS */ }
    }
    return false;
  });
  console.log('.qh-load-more rule present in any stylesheet?:', hasLoadMoreRule);

  const loadMore = await page.locator('.qh-load-more').first();
  expect(await loadMore.count()).toBeGreaterThan(0);

  const bg = await page.evaluate(el => getComputedStyle(el).getPropertyValue('background-image') || getComputedStyle(el).getPropertyValue('background'), await loadMore.elementHandle());
  const boxShadow = await page.evaluate(el => getComputedStyle(el).getPropertyValue('box-shadow'), await loadMore.elementHandle());
  console.log('Load more computed background:', bg);
  console.log('Load more computed box-shadow:', boxShadow);

  // Scroll timeline container to bottom and click Load more
  await page.evaluate(() => {
    const root = document.querySelector('[data-timeline-page="true"]');
    if (root) { root.scrollTop = root.scrollHeight; }
  });

  // click manual load more to trigger insertion
  await loadMore.click();
  await page.waitForTimeout(600);

  const insertedCount = await page.evaluate(() => document.querySelectorAll('.timeline-inserted').length);
  console.log('Inserted items after Load more:', insertedCount);
  // inspect computed animation name for inserted element if present
  if (insertedCount > 0) {
    const animName = await page.evaluate(() => {
      const el = document.querySelector('.timeline-inserted');
      return el ? getComputedStyle(el).getPropertyValue('animation-name') : null;
    });
    console.log('animation-name on inserted element:', animName);
  }
});
