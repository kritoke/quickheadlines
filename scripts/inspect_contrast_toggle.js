const { chromium } = require('playwright');

function pRGB(s) {
  if (!s) return null;
  const m = s.match(/(\d+),\s*(\d+),\s*(\d+)/);
  if (!m) return null;
  return [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])];
}

(async ()=>{
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8080/timeline', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.waitForSelector('main');

  async function snapshot() {
    return await page.evaluate(()=>{
      function pRGBInner(s){ const m = s && s.match(/(\d+),\s*(\d+),\s*(\d+)/); return m ? [parseInt(m[1]),parseInt(m[2]),parseInt(m[3])] : null; }
      function toLin(c){ const v=c/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); }
      function lumFrom(c){ return 0.2126*toLin(c[0])+0.7152*toLin(c[1])+0.0722*toLin(c[2]); }
      function contrastC(f,b){ if(!f||!b) return null; const Lf=lumFrom(f); const Lb=lumFrom(b); return (Math.max(Lf,Lb)+0.05)/(Math.min(Lf,Lb)+0.05); }

      const anchors = Array.from(document.querySelectorAll('[data-timeline-item] a'));
      const out = [];
      anchors.forEach(a=>{
        try{
          const cs = window.getComputedStyle(a);
          const fg = pRGBInner(cs.color);
          // find nearest ancestor with non-transparent background
          let node = a; let bgNode = null;
          while(node && node !== document.documentElement){ const st = window.getComputedStyle(node); const bc = st.backgroundColor; if (bc && bc !== 'rgba(0, 0, 0, 0)' && bc !== 'transparent'){ bgNode = node; break;} node=node.parentElement; }
          const bgStyle = bgNode ? window.getComputedStyle(bgNode).backgroundColor : window.getComputedStyle(document.body).backgroundColor;
          const bg = pRGBInner(bgStyle);
          const ratio = contrastC(fg,bg);
          out.push({text: a.textContent.trim().slice(0,160), fg: cs.color, bg: bgStyle, ratio: ratio, js_override: a.getAttribute && a.getAttribute('data-js-override')=== 'true', inlineStyle: a.getAttribute('style'), linkOuter: a.outerHTML, timelineAttrs: (()=>{ const it = a.closest('[data-timeline-item]'); if(!it) return null; const o = {}; for(const at of it.attributes) o[at.name]=at.value; return o; })()});
        }catch(e){ }
      });
      return out;
    });
  }

  const before = await snapshot();
  console.log('Before: anchors:', before.length, 'failing:', before.filter(r=> r.ratio !== null && r.ratio < 4.5).length);

  // Toggle theme
  await page.evaluate(()=>{
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    // Also flip saved quickheadlines-theme in localStorage to mimic a user toggle
    try { localStorage.setItem('quickheadlines-theme', next); } catch(e) {}
  });

  // Give MutationObserver and cleanup code time to run
  await page.waitForTimeout(800);

  const after = await snapshot();
  console.log('After: anchors:', after.length, 'failing:', after.filter(r=> r.ratio !== null && r.ratio < 4.5).length);

  // Count anchors with inline styles or js_override after toggle
  const inlineAfter = after.filter(a=> a.inlineStyle && a.inlineStyle.trim() !== '');
  const overridesAfter = after.filter(a=> a.js_override === true);
  console.log('Anchors with inline style after toggle:', inlineAfter.length);
  console.log('Anchors marked data-js-override after toggle:', overridesAfter.length);

  if (inlineAfter.length > 0) {
    console.log('Sample inline-styled anchors (up to 10):');
    inlineAfter.slice(0,10).forEach(a=> console.log('-', a.text, 'fg=', a.fg, 'bg=', a.bg, 'inline=', a.inlineStyle));
  }

  if (overridesAfter.length > 0) {
    console.log('Sample data-js-override anchors (up to 10):');
    overridesAfter.slice(0,10).forEach(a=> console.log('-', a.text, 'outer=', a.linkOuter));
  }

  await browser.close();
})();
