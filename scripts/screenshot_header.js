const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 375, height: 800 }, deviceScaleFactor: 2 });
  const page = await context.newPage();
  try {
    await page.goto('http://127.0.0.1:8080', { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.qh-site-header', { timeout: 8000 });

    // Full viewport screenshot (mobile)
    const outDir = 'public/screenshots';
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    const fullPath = `${outDir}/header-full-mobile.png`;
    await page.screenshot({ path: fullPath, fullPage: false });

    // Screenshot of header element only
    const header = await page.$('.qh-site-header');
    if (header) {
      const headerPath = `${outDir}/header-element-mobile.png`;
      await header.screenshot({ path: headerPath });
      console.log('Saved:', fullPath, headerPath);
    } else {
      console.log('Header element not found; saved full-page only:', fullPath);
    }
  } catch (e) {
    console.error('screenshot failed', e && e.message);
    process.exitCode = 2;
  } finally {
    await browser.close();
  }
})();
