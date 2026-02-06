import { test, expect } from '@playwright/test';

test.describe('Timeline contrast', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(600);
  });

  test('timeline item text remains readable after tab switch / theme toggle', async ({ page }) => {
    // Collect initial timeline item colors keyed by item title text
    const before = await page.evaluate(() => {
      const out: Record<string, { linkComputed: string; headerComputed: string; server: string | null }> = {};
      document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
        const link = el.querySelector('a[data-display-link="true"]');
        const key = link ? (link as HTMLAnchorElement).innerText : Math.random().toString();
        const linkComputed = link ? window.getComputedStyle(link as Element).color : '';
        const headerComputed = window.getComputedStyle(el as Element).color;
        out[key] = { linkComputed, headerComputed, server: (el as HTMLElement).getAttribute('data-use-server-colors') };
      });
      return out;
    });

    // Force a re-render (toggle theme) to simulate tab switch / reflow
    await page.evaluate(() => {
      const cur = localStorage.getItem('quickheadlines-theme') || 'light';
      localStorage.setItem('quickheadlines-theme', cur === 'light' ? 'dark' : 'light');
      window.location.reload();
    });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(800);

    const after = await page.evaluate(() => {
      const out: Record<string, { linkComputed: string; headerComputed: string; server: string | null; linkInline: string | null }> = {};
      document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
        const link = el.querySelector('a[data-display-link="true"]');
        const key = link ? (link as HTMLAnchorElement).innerText : Math.random().toString();
        const linkComputed = link ? window.getComputedStyle(link as Element).color : '';
        const headerComputed = window.getComputedStyle(el as Element).color;
        out[key] = { linkComputed, headerComputed, server: (el as HTMLElement).getAttribute('data-use-server-colors'), linkInline: link ? link.getAttribute('style') : null };
      });
      return out;
    });

    const mismatches: any[] = [];
    for (const k of Object.keys(before)) {
      if (after[k]) {
        const b = before[k];
        const a = after[k];
        const issues: string[] = [];
        if (a.linkComputed === 'rgb(0, 0, 0)') issues.push('link_black');
        if (a.headerComputed === 'rgb(0, 0, 0)') issues.push('header_black');
        if (b.server === 'true' && a.server !== 'true') issues.push('lost_server_flag');
        if (issues.length) mismatches.push({ key: k, before: b, after: a, issues });
      }
    }

    if (mismatches.length) console.log('Timeline contrast mismatches:', JSON.stringify(mismatches, null, 2));
    expect(mismatches.length).toBe(0);
  });
});
