import { test, expect } from '@playwright/test';

test.describe('Timeline readability comprehensive test', () => {
  test('light mode: all links should be readable (not white)', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'light'); });
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3500); // Wait for all JS fixes to run

    const results = await page.evaluate(() => {
      const out: Array<any> = [];
      document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
        const link = el.querySelector('a[data-display-link="true"]') as HTMLElement | null;
        if (!link) return;
        const computed = window.getComputedStyle(link as Element).color;
        const inline = link.getAttribute('style');
        const title = link.innerText || '';
        const parentStyle = (el as HTMLElement).getAttribute('style');
        const parentComputed = window.getComputedStyle(el as Element).color;
        out.push({ title, computed, inline, parentStyle, parentComputed });
      });
      return out;
    });

    const whiteLinks = results.filter(r => r.computed === 'rgb(255, 255, 255)');
    console.log('Light mode white links:', whiteLinks.length);
    if (whiteLinks.length > 0) {
      console.log('White link details:', JSON.stringify(whiteLinks, null, 2));
    }
    expect(whiteLinks.length).toBe(0);
  });

  test('dark mode: all links should be readable (not black)', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'dark'); });
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3500); // Wait for all JS fixes to run

    const results = await page.evaluate(() => {
      const out: Array<any> = [];
      document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
        const link = el.querySelector('a[data-display-link="true"]') as HTMLElement | null;
        if (!link) return;
        const computed = window.getComputedStyle(link as Element).color;
        const inline = link.getAttribute('style');
        const title = link.innerText || '';
        const parentStyle = (el as HTMLElement).getAttribute('style');
        const parentComputed = window.getComputedStyle(el as Element).color;
        out.push({ title, computed, inline, parentStyle, parentComputed });
      });
      return out;
    });

    const blackLinks = results.filter(r => r.computed === 'rgb(0, 0, 0)');
    console.log('Dark mode black links:', blackLinks.length);
    if (blackLinks.length > 0) {
      console.log('Black link details:', JSON.stringify(blackLinks, null, 2));
    }
    expect(blackLinks.length).toBe(0);
  });

  test('light mode after tab switch should maintain readability', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.evaluate(() => { localStorage.setItem('quickheadlines-theme', 'light'); });
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);

    // Switch to home and back
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(400);
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3500);

    const results = await page.evaluate(() => {
      const out: Array<any> = [];
      document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
        const link = el.querySelector('a[data-display-link="true"]') as HTMLElement | null;
        if (!link) return;
        const computed = window.getComputedStyle(link as Element).color;
        const inline = link.getAttribute('style');
        const title = link.innerText || '';
        const parentStyle = (el as HTMLElement).getAttribute('style');
        const parentComputed = window.getComputedStyle(el as Element).color;
        out.push({ title, computed, inline, parentStyle, parentComputed });
      });
      return out;
    });

    const whiteLinks = results.filter(r => r.computed === 'rgb(255, 255, 255)');
    console.log('After tab switch white links:', whiteLinks.length);
    expect(whiteLinks.length).toBe(0);
  });
});
