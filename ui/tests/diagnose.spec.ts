import { test, expect } from '@playwright/test';

test('diagnose feed DOM, classes, and styles', async ({ page }) => {
  await page.goto('/');
  // wait a bit longer for Elm to render feed cards (network requests + morphdom updates)
  await page.waitForLoadState('networkidle');
  // also wait for a feed header to appear (Elm renders feeds asynchronously)
  try {
    await page.waitForSelector('.feed-header', { timeout: 5000 });
  } catch (e) {
    // ignore, we'll dump DOM below
  }

  const info = await page.evaluate(() => {
    const sheets = Array.from(document.styleSheets).map(s => ({ href: s.href || null, rules: s.cssRules ? Array.from(s.cssRules).map((r: any) => r.selectorText || r.cssText || '') : [] }));

    const feedBoxCount = document.querySelectorAll('.feed-box').length;
    const feedBodyCount = document.querySelectorAll('.feed-body').length;
    const insertedBefore = document.querySelectorAll('.timeline-inserted').length;

    // find first load more button
    const loadMore = document.querySelector('.qh-load-more') as HTMLElement | null;
    const loadMoreExists = !!loadMore;

    function pseudoComputed(el: Element | null, pseudo: string, prop: string) {
      try {
        if (!el) return null;
        return window.getComputedStyle(el as Element, pseudo).getPropertyValue(prop) || null;
      } catch (e) {
        return null;
      }
    }

    const feedBox = document.querySelector('.feed-box');
    const afterBg = pseudoComputed(feedBox, '::after', 'background-image') || pseudoComputed(feedBox, '::after', 'background');

    return {
      sheetsCount: sheets.length,
      sheetsSample: sheets.slice(0,5),
      feedBoxCount,
      feedBodyCount,
      insertedBefore,
      loadMoreExists,
      afterBg,
    };
  });

  console.log('diagnose initial:', info);

  if (info.feedBoxCount === 0) {
    const bodyHtml = await page.evaluate(() => ({ len: document.body.innerHTML.length, snippet: document.body.innerHTML.slice(0, 2000) }));
    console.log('body length and snippet:', bodyHtml);
  }

  // Gather more selectors and samples without failing the test
  const selectors = [
    '.feed-box',
    '.feed-body',
    '.feed-header',
    '.feed-title',
    '[data-adaptive]',
    '[data-timeline-item="true"]',
    '[data-page="home"]',
  ];

  const samples = {} as any;
  for (const sel of selectors) {
    samples[sel] = await page.evaluate((s) => {
      const nodes = Array.from(document.querySelectorAll(s));
      return { count: nodes.length, first: nodes.slice(0,3).map(n => ({ tag: n.tagName, class: (n.className||''), text: (n.textContent||'').trim().slice(0,120) })) };
    }, sel);
  }

  console.log('selector samples:', samples);

  // Also list top-level children in the main app container to see structure
  const topChildren = await page.evaluate(() => {
    const root = document.querySelector('[data-page="home"]') || document.getElementById('elm') || document.body;
    return Array.from((root as Element).children).slice(0,20).map((c: Element) => ({ tag: c.tagName, class: (c.className||''), dataAttrs: Array.from(c.attributes).filter(a => a.name.startsWith('data-')).map(a => ({ name: a.name, value: a.value })) }));
  });
  console.log('topChildren sample:', topChildren.slice(0,10));

  // Print outerHTML of first feed-header and its ancestor chain
  const headerHtml = await page.evaluate(() => {
    const el = document.querySelector('.feed-header');
    if (!el) return null;
    const ancestors = [] as string[];
    let p: Element | null = el.parentElement;
    let depth = 0;
    while (p && depth < 6) {
      ancestors.push(p.tagName + (p.className ? '.' + p.className : ''));
      p = p.parentElement;
      depth += 1;
    }
    return { outer: (el as HTMLElement).outerHTML.slice(0,2000), ancestors };
  });
  console.log('first feed-header outer/ancestors:', headerHtml);

  // Click load more if present
  const loadMore = page.locator('.qh-load-more').first();
  if (await loadMore.count() > 0) {
    await loadMore.click();
    await page.waitForTimeout(600);
  }

  const after = await page.evaluate(() => {
    const inserted = Array.from(document.querySelectorAll('.timeline-inserted')).map(el => {
      // return tag, classes, and a short ancestor chain
      const a = el as HTMLElement;
      const classes = a.className;
      const tag = a.tagName;
      const ancestors = [];
      let p: Element | null = a.parentElement;
      let depth = 0;
      while (p && depth < 6) {
        ancestors.push(p.tagName + (p.className ? '.' + p.className.split(' ').join('.') : ''));
        p = p.parentElement;
        depth += 1;
      }
      return { tag, classes, ancestors };
    });

    const anyInserted = inserted.length > 0;
    const animNames = inserted.map((i: any) => {
      try {
        const firstClass = (i.classes.split(' ').find((c: string) => c) || '');
        const el = firstClass ? document.querySelector('.' + firstClass) as Element | null : null;
        return el ? getComputedStyle(el).getPropertyValue('animation-name') : null;
      } catch (e) { return null; }
    });

    return { insertedCount: inserted.length, insertedSample: inserted.slice(0,5), animNames };
  });

  console.log('diagnose after load more:', after);

});
