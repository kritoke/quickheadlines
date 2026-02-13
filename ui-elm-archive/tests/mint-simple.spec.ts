import { test, expect } from '@playwright/test';

test('Mint frontend renders Timeline component', async ({ page }) => {
  await page.goto('http://127.0.0.1:8080/timeline');
  await page.waitForLoadState('networkidle');
  
  // Wait a bit for JS to execute
  await page.waitForTimeout(2000);
  
  // Check if our test text is visible
  const bodyText = await page.locator('body').textContent();
  console.log('Body content:', bodyText);
  
  // Check for the text
  if (bodyText && bodyText.includes('Timeline page is working')) {
    console.log('SUCCESS: Mint component rendered!');
  } else {
    console.log('ISSUE: Mint component did not render');
  }
});
