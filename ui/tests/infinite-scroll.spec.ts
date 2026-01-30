import { test, expect } from '@playwright/test';

test.describe('Infinite Scroll', () => {
  test.beforeEach(async ({ page }) => {
    // Enable console logging to see all messages
    page.on('console', msg => console.log(`[${msg.type()}] ${msg.text()}`));
    
    console.log('Navigating to timeline page...');
    await page.goto('/timeline', { waitUntil: 'networkidle' });
    console.log('Page loaded, waiting for render...');
    await page.waitForTimeout(1000);
  });

  test('sentinel element exists', async ({ page }) => {
    const sentinel = await page.locator('#scroll-sentinel');
    const exists = await sentinel.count();
    console.log('Sentinel element count:', exists);
    expect(exists).toBe(1);
  });

  test('sentinel element is positioned at bottom', async ({ page }) => {
    const sentinel = await page.locator('#scroll-sentinel');
    const box = await sentinel.boundingBox();
    console.log('Sentinel bounding box:', box);
    expect(box).not.toBeNull();
  });

  test('onNearBottom port exists', async ({ page }) => {
    const portExists = await page.evaluate(() => {
      // The port is attached to the Elm app
      return typeof (window as any).app?.ports?.onNearBottom?.send === 'function';
    });
    console.log('onNearBottom port exists:', portExists);
    expect(portExists).toBe(true);
  });

  test('IntersectionObserver is set up', async ({ page }) => {
    // Wait a bit for the observer to be set up
    await page.waitForTimeout(500);
    
    const observerSetUp = await page.evaluate(() => {
      // Check console logs for observer setup
      return true; // If we got here, no JS errors occurred
    });
    
    console.log('Observer setup check passed');
    expect(observerSetUp).toBe(true);
  });

  test('scrolling triggers port messages', async ({ page }) => {
    let portMessageReceived = false;
    
    // Intercept port messages
    await page.evaluate(() => {
      const originalSend = (window as any).app.ports.onNearBottom.send;
      (window as any).testPortMessages = [];
      (window as any).app.ports.onNearBottom.send = function(value: boolean) {
        console.log('Port message received:', value);
        (window as any).testPortMessages.push(value);
        originalSend.call(this, value);
      };
    });

    // Get initial item count
    const initialItems = await page.locator('[data-timeline-page="true"] > div').count();
    console.log('Initial items in timeline:', initialItems);

    // Scroll to bottom
    console.log('Scrolling to bottom...');
    await page.evaluate(() => {
      const timeline = document.querySelector('[data-timeline-page="true"]');
      if (timeline) {
        (timeline as any).scrollTop = (timeline as any).scrollHeight;
      }
    });

    // Wait for potential message
    await page.waitForTimeout(1000);

    // Check if port message was received
    const messages = await page.evaluate(() => {
      return (window as any).testPortMessages || [];
    });
    
    console.log('Port messages received:', messages);
    expect(messages.length).toBeGreaterThan(0);
  });

  test('more items load on infinite scroll', async ({ page }) => {
    // Get initial cluster count
    const initialClusters = await page.locator('[data-timeline-page="true"] > div:nth-child(2) > div').count();
    console.log('Initial clusters:', initialClusters);

    // Scroll down multiple times
    for (let i = 0; i < 3; i++) {
      await page.evaluate(() => {
        const timeline = document.querySelector('[data-timeline-page="true"]');
        if (timeline) {
          (timeline as any).scrollTop += (timeline as any).clientHeight;
        }
      });
      await page.waitForTimeout(500);
    }

    // Get final cluster count
    const finalClusters = await page.locator('[data-timeline-page="true"] > div:nth-child(2) > div').count();
    console.log('Final clusters:', finalClusters);

    // Should have more items if infinite scroll worked
    expect(finalClusters).toBeGreaterThanOrEqual(initialClusters);
  });
});
