import { test } from '@playwright/test';

test.describe('Home Page Scroll', () => {
  test('home page should use normal browser scrolling', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Check if body/html have overflow
    const scrollState = await page.evaluate(() => {
      const body = document.body;
      const html = document.documentElement;
      return {
        bodyOverflow: window.getComputedStyle(body).overflow,
        bodyOverflowY: window.getComputedStyle(body).overflowY,
        htmlOverflowY: window.getComputedStyle(html).overflowY,
        bodyScrollHeight: body.scrollHeight,
        bodyClientHeight: body.clientHeight,
        canScroll: body.scrollHeight > body.clientHeight
      };
    });
    console.log('Home page scroll state:', JSON.stringify(scrollState, null, 2));

    // Check scrollbar visibility
    const hasScrollbar = await page.evaluate(() => {
      // Check if there's a visible scrollbar
      const outer = document.createElement('div');
      outer.style.visibility = 'hidden';
      outer.style.overflow = 'scroll';
      document.body.appendChild(outer);
      const inner = document.createElement('div');
      inner.style.width = '100%';
      outer.appendChild(inner);
      const scrollbarWidth = outer.offsetWidth - inner.offsetWidth;
      outer.parentNode.removeChild(outer);
      return scrollbarWidth > 0;
    });
    console.log('Has scrollbar:', hasScrollbar);

    // Test actual scrolling works
    await page.evaluate(() => window.scrollTo(0, 500));
    await page.waitForTimeout(500);
    const scrollPosition = await page.evaluate(() => window.scrollY);
    console.log('Scroll position after scrollTo(0, 500):', scrollPosition);
  });
});
