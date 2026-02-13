import { test, expect } from '@playwright/test';

test.describe('Timeline contrast checks', () => {
  test('every timeline item link has contrast >= 4.5:1 against its background', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    // Allow JS to render and any Elm client adjustments to complete
    await page.waitForTimeout(2500);

    const failures = await page.evaluate(() => {
      function parseRGB(s: string) {
        const m = s.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
        if (!m) return null;
        return [parseInt(m[1], 10), parseInt(m[2], 10), parseInt(m[3], 10)];
      }

      function srgbToLinear(c: number) {
        const v = c / 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
      }

      function luminance(rgb: number[]) {
        return 0.2126 * srgbToLinear(rgb[0]) + 0.7152 * srgbToLinear(rgb[1]) + 0.0722 * srgbToLinear(rgb[2]);
      }

      function contrastRatio(fg: number[], bg: number[]) {
        const L1 = luminance(fg);
        const L2 = luminance(bg);
        const lighter = Math.max(L1, L2);
        const darker = Math.min(L1, L2);
        return (lighter + 0.05) / (darker + 0.05);
      }

      const out: Array<any> = [];
      document.querySelectorAll('[data-timeline-item="true"]').forEach(el => {
        const link = el.querySelector('a[data-display-link="true"]') as HTMLElement | null;
        if (!link) return;
        const fg = window.getComputedStyle(link as Element).color;
        // Find nearest ancestor with non-transparent background
        let node: HTMLElement | null = link as HTMLElement;
        let bgColor = '';
        while (node) {
          const style = window.getComputedStyle(node);
          const bc = style.backgroundColor;
          if (bc && bc !== 'rgba(0, 0, 0, 0)' && bc !== 'transparent') { bgColor = bc; break; }
          node = node.parentElement;
        }
        if (!bgColor) bgColor = window.getComputedStyle(document.body).backgroundColor || 'rgb(255,255,255)';

        const fgRgb = parseRGB(fg);
        const bgRgb = parseRGB(bgColor);
        if (!fgRgb || !bgRgb) return; // skip if styles couldn't be parsed

        const ratio = contrastRatio(fgRgb, bgRgb);
        const title = (link.textContent || '').trim().slice(0, 80);
        if (ratio < 4.5) {
          out.push({ title, fg, bg: bgColor, ratio });
        }
      });
      return out;
    });

    if (failures.length > 0) {
      console.log('Contrast failures:', JSON.stringify(failures, null, 2));
    }
    expect(failures.length).toBe(0);
  });
});
