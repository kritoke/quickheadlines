import { test } from '@playwright/test';

test.describe('Debug Timeline Scroll', () => {
  test('check timeline scroll container', async ({ page }) => {
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    const info = await page.evaluate(() => {
      const mainContent = document.getElementById('main-content');
      const layoutContainer = document.querySelector('[data-semantic="layout-container"]');

      const getStyle = (el: Element | null, prop: string) => el ? window.getComputedStyle(el)[prop as any] : null;

      return {
        mainContent: {
          offsetHeight: mainContent?.offsetHeight,
          scrollHeight: mainContent?.scrollHeight,
          clientHeight: mainContent?.clientHeight,
          styleHeight: getStyle(mainContent, 'height'),
          styleFlex: getStyle(mainContent, 'flex'),
          styleMinHeight: getStyle(mainContent, 'minHeight'),
          styleOverflowY: getStyle(mainContent, 'overflowY')
        },
        layoutContainer: {
          offsetHeight: layoutContainer?.offsetHeight,
          styleHeight: getStyle(layoutContainer, 'height'),
          styleMinHeight: getStyle(layoutContainer, 'minHeight'),
          styleFlex: getStyle(layoutContainer, 'flex')
        },
        body: {
          offsetHeight: document.body.offsetHeight,
          clientHeight: document.body.clientHeight,
          styleOverflow: getStyle(document.body, 'overflow')
        },
        window: {
          innerHeight: window.innerHeight
        }
      };
    });
    console.log('Scroll debug:', JSON.stringify(info, null, 2));
  });
});
