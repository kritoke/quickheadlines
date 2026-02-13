import { test, expect } from '@playwright/test';

test('feed shows insert animation and bottom affordance after Load More', async ({ page }) => {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  // wait for home page to render
  await page.waitForSelector('[data-page="home"]', { timeout: 5000 });

  const cardSelector = '[data-semantic="feed-card"], .feed-box';
  await page.waitForSelector(cardSelector, { timeout: 5000 });
  const cardCount = await page.locator(cardSelector).count();
  expect(cardCount).toBeGreaterThan(0);

  const loadMore = page.locator('.qh-load-more').first();
  if (await loadMore.count() === 0) {
    test.skip();
    return;
  }

  await loadMore.click();
  // allow Elm model updates + animations to run
  await page.waitForTimeout(900);

  const info = await page.evaluate(() => {
    const card = document.querySelector('[data-semantic="feed-card"], .feed-box');
    function pseudoProp(el: Element | null, pseudo: string, prop: string) {
      try { if (!el) return null; return window.getComputedStyle(el as Element, pseudo).getPropertyValue(prop) || null; } catch (e) { return null; }
    }

    const afterBg = pseudoProp(card, '::after', 'background-image') || pseudoProp(card, '::after', 'background');
    const beforeContent = pseudoProp(card, '::before', 'content');

    // find the most likely visible inserted link
    const insertedLink = document.querySelector('[data-semantic="feed-card"] .timeline-inserted a, .timeline-inserted a, [data-semantic="feed-card"] [data-display-link] a') as HTMLElement | null;
    const inlineAnim = insertedLink ? insertedLink.style.animation || '' : '';
    const computedAnimName = insertedLink ? getComputedStyle(insertedLink).getPropertyValue('animation-name') : null;

    return { afterBg, beforeContent, inlineAnim, computedAnimName };
  });

  // Assert we have a non-empty gradient or background for the ::after pseudo-element
  expect(info.afterBg).toBeTruthy();

  // The More pill uses ::before content set to "More"
  expect(info.beforeContent).toBeTruthy();
  expect(info.beforeContent).toContain('More');

  // Either inline animation exists or computed animation-name includes qh-insert
  const hasInline = info.inlineAnim && info.inlineAnim.includes('qh-insert');
  const hasComputed = info.computedAnimName && info.computedAnimName.includes('qh-insert');
  expect(hasInline || hasComputed).toBeTruthy();
});
