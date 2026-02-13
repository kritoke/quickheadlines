import { test, expect } from '@playwright/test';

test.describe('Tab switch header colors', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForLoadState('networkidle');
  });

  test('header colors persist after switching tabs', async ({ page }) => {
    // Collect initial header colors keyed by feed link href
    const before = await page.evaluate(() => {
      const out: Record<string, { bg: string; text: string; server: string | null }> = {};
      document.querySelectorAll('.feed-header').forEach(h => {
        const link = h.querySelector('a');
        const href = link ? (link as HTMLAnchorElement).href : ('__no_link__' + Math.random());
        const computed = window.getComputedStyle(h as Element);
        const linkEl = link as HTMLElement;
        const linkColor = linkEl ? window.getComputedStyle(linkEl).color : '';
        out[href] = { bg: computed.backgroundColor, text: linkColor, server: (h as HTMLElement).getAttribute('data-use-server-colors') };
      });
      return out;
    });

    // Click the second tab (if present) and then return to the first tab
    const tabs = page.locator('.tab-link');
    const tabCount = await tabs.count();
    if (tabCount >= 2) {
      await tabs.nth(1).click();
      await page.waitForLoadState('networkidle');
      // small pause for Elm render + MutationObserver
      await page.waitForTimeout(600);
      await tabs.nth(0).click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(800);
    } else {
      // If there aren't multiple tabs, force a re-render by toggling theme
      await page.evaluate(() => {
        const cur = localStorage.getItem('quickheadlines-theme') || 'light';
        localStorage.setItem('quickheadlines-theme', cur === 'light' ? 'dark' : 'light');
        window.location.reload();
      });
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(800);
    }

    const after = await page.evaluate(() => {
      const out: Record<string, { bg: string; text: string; server: string | null; headerComputed: string; headerInline: string | null; linkInline: string | null }> = {};
      document.querySelectorAll('.feed-header').forEach(h => {
        const link = h.querySelector('a');
        const href = link ? (link as HTMLAnchorElement).href : ('__no_link__' + Math.random());
        const computed = window.getComputedStyle(h as Element);
        const linkEl = link as HTMLElement;
        const linkColor = linkEl ? window.getComputedStyle(linkEl).color : '';
        out[href] = {
          bg: computed.backgroundColor,
          text: linkColor,
          server: (h as HTMLElement).getAttribute('data-use-server-colors'),
          headerComputed: computed.color,
          headerInline: (h as HTMLElement).getAttribute('style'),
          linkInline: linkEl ? (linkEl.getAttribute('style')) : null
        };
      });
      return out;
    });

    // Compare entries that exist both before and after
    const mismatches: Array<any> = [];
    for (const href of Object.keys(before)) {
      if (after[href]) {
        const b = before[href];
        const a = after[href];

        const issues: string[] = [];
        if (a.bg === 'rgba(0, 0, 0, 0)') issues.push('bg_transparent');
        if (b.server === 'true' && a.server !== 'true') issues.push('lost_server_flag');
        if (a.text === 'rgb(0, 0, 0)') issues.push('text_black');
        if (a.text === 'rgba(0, 0, 0, 0)') issues.push('text_transparent');

        if (issues.length) {
          mismatches.push({ href: href, before: b, after: a, issues });
        }
      }
    }

    if (mismatches.length) {
      console.log('Tab-switch color mismatches:', JSON.stringify(mismatches, null, 2));
    }

    expect(mismatches.length).toBe(0);
  });
});
