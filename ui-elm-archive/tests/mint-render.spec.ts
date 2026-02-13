import { test, expect } from '@playwright/test';

test('Mint frontend renders content', async ({ page }) => {
  await page.goto('http://127.0.0.1:8080/');

  // Wait for JavaScript to execute
  await page.waitForTimeout(2000);

  // Check if body has content
  const bodyContent = await page.evaluate(() => document.body.innerHTML);
  console.log('Body content:', bodyContent);

  // Check for our test text
  const hasHello = await page.locator('text=HELLO MINT WORKS').isVisible();
  console.log('Has HELLO text:', hasHello);

  // Check body background
  const bgColor = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  console.log('Body background:', bgColor);
});
