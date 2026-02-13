import { test, expect } from '@playwright/test';

test('Mint frontend renders Timeline component', async ({ page }) => {
  // Navigate to the timeline page
  await page.goto('http://127.0.0.1:8080/timeline');
  
  // Wait for the page to load
  await page.waitForLoadState('networkidle');
  
  // Check if our test text is visible
  const timelineText = page.getByText('Timeline page is working');
  await expect(timelineText).toBeVisible({ timeout: 10000 });
  
  // Also check for QuickHeadlines heading
  const heading = page.getByText('QuickHeadlines');
  await expect(heading).toBeVisible({ timeout: 10000 });
});
