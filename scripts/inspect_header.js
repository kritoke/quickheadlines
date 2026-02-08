const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 375, height: 800 } });
  const page = await context.newPage();
  try {
    await page.goto('http://127.0.0.1:8080', { waitUntil: 'domcontentloaded' });
    // Wait for Elm to initialize the header
    await page.waitForSelector('.qh-site-header', { timeout: 8000 });

    const result = await page.evaluate(() => {
      function getComputed(el) {
        const cs = window.getComputedStyle(el);
        return {
          outerHTML: el.outerHTML,
          paddingTop: cs.paddingTop,
          paddingBottom: cs.paddingBottom,
          paddingLeft: cs.paddingLeft,
          paddingRight: cs.paddingRight,
          lineHeight: cs.lineHeight,
          width: cs.width
        };
      }

      const header = document.querySelector('.qh-site-header');
      if (!header) return { error: 'header-not-found' };

      // Find brand by searching for the text node
      const brandCandidates = Array.from(header.querySelectorAll('*')).filter(el => el.textContent && el.textContent.trim().includes('Quick'));
      const brand = brandCandidates.length ? brandCandidates[0] : null;

      // Find theme toggle button
      const themeBtn = header.querySelector('button[title]') || document.querySelector('button[title]');

      return {
        header: getComputed(header),
        brand: brand ? getComputed(brand) : null,
        themeButton: themeBtn ? getComputed(themeBtn) : null,
        timestamp: Date.now()
      };
    });

    console.log(JSON.stringify(result, null, 2));
  } catch (e) {
    console.error('inspect failed', e && e.message);
    process.exitCode = 2;
  } finally {
    await browser.close();
  }
})();
