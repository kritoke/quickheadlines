import { test, expect } from '@playwright/test';

test.describe('Timeline favicon visual regression', () => {
  test('desktop snapshot (1280px)', async ({ page }) => {
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.waitForTimeout(500);
    const shot = await page.screenshot({ fullPage: true });
    expect(shot).toMatchSnapshot('timeline-1280.png');
  });

  test('mobile snapshot (320px)', async ({ page }) => {
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    await page.setViewportSize({ width: 320, height: 800 });
    await page.waitForTimeout(500);
    const shot = await page.screenshot({ fullPage: true });
    expect(shot).toMatchSnapshot('timeline-320.png');
  });
});
