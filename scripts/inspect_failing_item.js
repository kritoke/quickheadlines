const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8080/timeline', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  // Wait for timeline to render
  await page.waitForSelector('main');

  const titles = [
    "CIA’s World Factbook is Gone",
    "Hollywood's AI Bet Isn't Paying Off",
    "Looking For Advanced Aliens?  Search For Exoplanets With Large Coal Deposits",
    "How to watch the Opening Ceremony at the 2026 Milan Cortina Winter Olympics rebr"
  ];

  for (const title of titles) {
    const locator = page.locator(`text="${title}"`);
    const exists = await locator.count();
    if (!exists) {
      console.log(`${title}: NOT FOUND`);
      continue;
    }

    const el = await locator.first();
    const info = await el.evaluate((e) => {
      const cs = window.getComputedStyle(e);
      // find nearest ancestor with non-transparent background
      let node = e;
      let bgNode = null;
      while (node && node !== document.documentElement) {
        const style = window.getComputedStyle(node);
        const bgc = style.backgroundColor;
        if (bgc && bgc !== 'rgba(0, 0, 0, 0)' && bgc !== 'transparent') { bgNode = node; break; }
        node = node.parentElement;
      }
      const bgStyle = bgNode ? window.getComputedStyle(bgNode).backgroundColor : window.getComputedStyle(document.body).backgroundColor;
      return {
        fg: cs.color,
        fgStyle: e.getAttribute('style'),
        fgClass: e.className,
        outerHTML: e.outerHTML,
        parentHTML: e.parentElement ? e.parentElement.outerHTML : null,
        bg: bgStyle,
        bgNodeOuter: bgNode ? bgNode.outerHTML : null,
        timelineItemAttrs: (() => { let it = e.closest('[data-timeline-item]'); if (!it) return null; const out = {}; for (const a of it.attributes) out[a.name]=a.value; return out })()
      };
    });

    console.log(`${title}: fg=${info.fg} bg=${info.bg}\n  style=${info.fgStyle} class=${info.fgClass}\n  outer=${info.outerHTML}\n  parent=${info.parentHTML}\n  bgNode=${info.bgNodeOuter}\n  timelineItemAttrs=${JSON.stringify(info.timelineItemAttrs)}`);
  }

  await browser.close();
})();
