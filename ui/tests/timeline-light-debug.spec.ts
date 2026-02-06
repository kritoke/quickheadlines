import { test } from '@playwright/test';

test('debug: timeline light theme check for white links', async ({ page }) => {
  // Force light theme
  await page.goto('/', { waitUntil: 'networkidle' });
  await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'light'); });
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
      if (computed === 'rgb(255, 255, 255)' || (inline && /#?fff|white/i.test(inline))) {
        out.push({ title, computed, inline, parentStyle: (el as HTMLElement).getAttribute('style'), parentComputed: window.getComputedStyle(el).color });
      }
    });
    return out;
  });

  console.log('timeline-light-debug results:', JSON.stringify(results, null, 2));
  // Fail if any white links found
  if (results.length) throw new Error('Found white links in light theme');
});
