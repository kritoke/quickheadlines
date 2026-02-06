import { test } from '@playwright/test';

test('debug: timeline dark theme check for black links', async ({ page }) => {
  // Force dark theme
  await page.goto('/', { waitUntil: 'networkidle' });
  await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'dark'); });
  await page.goto('/timeline', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);

  const results = await page.evaluate(() => {
    const out: Array<any> = [];
    document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
      const link = el.querySelector('a[data-display-link="true"]') as HTMLElement | null;
      if (!link) return;
      const computed = window.getComputedStyle(link).color;
      const inline = link.getAttribute('style');
      const title = link.innerText || '';
      if (computed === 'rgb(0, 0, 0)' || (inline && /rgb\(0,\s*0,\s*0\)/.test(inline))) {
        out.push({ title, computed, inline, parentStyle: (el as HTMLElement).getAttribute('style'), parentComputed: window.getComputedStyle(el).color });
      }
    });
    return out;
  });

  console.log('timeline-dark-debug results:', JSON.stringify(results, null, 2));
  if (results.length) throw new Error('Found black links in dark theme');
});
