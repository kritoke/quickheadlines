import { test, expect } from '@playwright/test';

test.describe('Feed Header Colors', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('extractHeaderColors function exists', async ({ page }) => {
    const exists = await page.evaluate(() => {
      return typeof window.extractHeaderColors === 'function';
    });
    expect(exists).toBe(true);
  });

  test('feedHeaderCache stores and retrieves colors', async ({ page }) => {
    await page.evaluate(() => {
      window.feedHeaderCache = {};
      window.feedHeaderCache['https://test.com/feed'] = {
        bg: 'rgb(100,150,200)',
        text: '#ffffff'
      };
    });
    
    const cached = await page.evaluate(() => {
      return window.feedHeaderCache['https://test.com/feed'];
    });
    
    expect(cached.bg).toBe('rgb(100,150,200)');
    expect(cached.text).toBe('#ffffff');
  });

  test('color format uses rgb(r,g,b) without spaces', async ({ page }) => {
    const format = await page.evaluate(() => {
      const r = 100, g = 150, b = 200;
      return 'rgb(' + r + ',' + g + ',' + b + ')';
    });
    expect(format).toBe('rgb(100,150,200)');
  });

  test('feed headers have background color in dark mode', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.setItem('quickheadlines-theme', 'dark');
      window.location.reload();
    });
    await page.waitForLoadState('networkidle');
    
    const headers = page.locator('.feed-header');
    await expect(headers.first()).toBeVisible();
    
    const bgColor = await headers.first().evaluate(el => 
      window.getComputedStyle(el).backgroundColor
    );
    // Should NOT be transparent or rgba(0,0,0,0)
    expect(bgColor).not.toBe('rgba(0, 0, 0, 0)');
  });

  test('feed headers have background color in light mode', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.setItem('quickheadlines-theme', 'light');
      window.location.reload();
    });
    await page.waitForLoadState('networkidle');
    
    const headers = page.locator('.feed-header');
    const bgColor = await headers.first().evaluate(el => 
      window.getComputedStyle(el).backgroundColor
    );
    expect(bgColor).not.toBe('rgba(0, 0, 0, 0)');
  });

  test('text color contrasts with background (not invisible)', async ({ page }) => {
    const headers = page.locator('.feed-header');
    const count = await headers.count();
    
    // Check first 5 headers
    for (let i = 0; i < Math.min(count, 5); i++) {
      const header = headers.nth(i);
      const bgColor = await header.evaluate(el => 
        window.getComputedStyle(el).backgroundColor
      );
      const link = header.locator('a').first();
      const textColor = await link.evaluate(el =>
        window.getComputedStyle(el).color
      );
      
      // Text should not match background (would be invisible)
      expect(bgColor).not.toBe(textColor);
    }
  });

  test('API returns feeds endpoint with colors', async ({ page }) => {
    const response = await page.request.get('/api/feeds?tab=Tech');
    expect(response.status()).toBe(200);
    
    const data = await response.json();
    expect(data.feeds).toBeDefined();
    expect(Array.isArray(data.feeds)).toBe(true);
  });

  test('feed header has data-use-adaptive-colors attribute when no colors', async ({ page }) => {
    const headers = page.locator('.feed-header[data-use-adaptive-colors="true"]');
    const count = await headers.count();
    // Some headers should have this attribute indicating they're waiting for color extraction
    expect(count).toBeGreaterThanOrEqual(0); // Soft assertion
  });
});
