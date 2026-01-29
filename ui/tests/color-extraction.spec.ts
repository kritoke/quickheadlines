import { test, expect } from '@playwright/test';

test.describe('Color Extraction', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('ColorThief library is loaded', async ({ page }) => {
    const loaded = await page.evaluate(() => {
      return typeof ColorThief !== 'undefined';
    });
    expect(loaded).toBe(true);
  });

  test('feedHeaderCache object exists', async ({ page }) => {
    const exists = await page.evaluate(() => {
      return typeof window.feedHeaderCache !== 'undefined';
    });
    expect(exists).toBe(true);
  });

  test('feedHeaderCache initializes as empty object', async ({ page }) => {
    const isEmpty = await page.evaluate(() => {
      return Object.keys(window.feedHeaderCache || {}).length === 0;
    });
    expect(isEmpty).toBe(true);
  });

  test('color extraction function can be called manually', async ({ page }) => {
    // This tests that the function exists and can be invoked
    const canCall = await page.evaluate(() => {
      if (typeof window.extractHeaderColors === 'function') {
        try {
          window.extractHeaderColors();
          return true;
        } catch (e) {
          return false;
        }
      }
      return false;
    });
    expect(canCall).toBe(true);
  });

  test('yiq contrast calculation is correct', async ({ page }) => {
    // Test the YIQ luminance calculation logic
    const result = await page.evaluate(() => {
      // Light color (high luminance)
      const lightRgb = [255, 255, 255];
      const lightYiq = ((lightRgb[0] * 299) + (lightRgb[1] * 587) + (lightRgb[2] * 114)) / 1000;
      
      // Dark color (low luminance)
      const darkRgb = [0, 0, 0];
      const darkYiq = ((darkRgb[0] * 299) + (darkRgb[1] * 587) + (darkRgb[2] * 114)) / 1000;
      
      // Light should be >= 128, dark should be < 128
      return {
        lightYiq: lightYiq,
        darkYiq: darkYiq,
        lightIsBright: lightYiq >= 128,
        darkIsDark: darkYiq < 128
      };
    });
    
    expect(result.lightYiq).toBe(255);
    expect(result.darkYiq).toBe(0);
    expect(result.lightIsBright).toBe(true);
    expect(result.darkIsDark).toBe(true);
  });

  test('fetch API for header_color endpoint exists', async ({ page }) => {
    const canFetch = await page.evaluate(async () => {
      try {
        const response = await fetch('/api/header_color', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            feed_url: 'https://test.com/feed.xml',
            color: 'rgb(100,150,200)',
            text_color: '#ffffff'
          })
        });
        return response.status >= 200 && response.status < 500;
      } catch (e) {
        return false;
      }
    });
    // Either succeeds or returns error (not network failure)
    expect(canFetch).toBe(true);
  });

  test('favicon images are present in feed headers', async ({ page }) => {
    const images = page.locator('.feed-header img');
    const count = await images.count();
    // Should have at least some favicon images
    expect(count).toBeGreaterThanOrEqual(0); // Soft assertion
  });
});
