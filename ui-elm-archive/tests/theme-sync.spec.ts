import { test, expect } from '@playwright/test';

test.describe('Theme Sync', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.evaluate(() => {
      localStorage.removeItem('quickheadlines-theme');
    });
  });

  test('envThemeChanged port exists after Elm init', async ({ page }) => {
    const hasPort = await page.evaluate(() => {
      return !!(window.app && window.app.ports && window.app.ports.envThemeChanged);
    });
    expect(hasPort).toBe(true);
  });

  test('theme changes live when OS preference changes (no saved preference)', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.removeItem('quickheadlines-theme');
    });

    const getTheme = () => document.documentElement.getAttribute('data-theme');

    await page.emulateMedia({ colorScheme: 'dark' });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(300);

    const darkTheme = await page.evaluate(getTheme);
    expect(darkTheme).toBe('dark');

    await page.emulateMedia({ colorScheme: 'light' });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(300);

    const lightTheme = await page.evaluate(getTheme);
    expect(lightTheme).toBe('light');
  });

  test('theme does NOT change when OS preference changes (saved preference exists)', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.setItem('quickheadlines-theme', 'light');
    });
    await page.reload({ waitUntil: 'networkidle' });

    const getTheme = () => document.documentElement.getAttribute('data-theme');
    const initialTheme = await page.evaluate(getTheme);
    expect(initialTheme).toBe('light');

    await page.emulateMedia({ colorScheme: 'dark' });
    await page.waitForTimeout(200);

    const themeAfterOSChange = await page.evaluate(getTheme);
    expect(themeAfterOSChange).toBe('light');
  });

  test('theme sync applies dark theme colors', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.removeItem('quickheadlines-theme');
    });

    await page.emulateMedia({ colorScheme: 'dark' });
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(300);

    const theme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(theme).toBe('dark');

    const header = page.locator('.feed-header').first();
    await expect(header).toBeVisible();
  });

  test('theme sync applies light theme colors', async ({ page }) => {
    await page.evaluate(() => {
      localStorage.setItem('quickheadlines-theme', 'light');
    });
    await page.reload({ waitUntil: 'networkidle' });

    const theme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(theme).toBe('light');

    const header = page.locator('.feed-header').first();
    await expect(header).toBeVisible();
  });
});
