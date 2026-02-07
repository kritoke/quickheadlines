const { chromium } = require('playwright');

function parseRGB(s) {
  if (!s) return null;
  const m = s.match(/(\d+),\s*(\d+),\s*(\d+)/);
  if (!m) return null;
  return [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])];
}

function lum([r,g,b]){
  const toLin = (c)=>{ const v=c/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); };
  return 0.2126*toLin(r)+0.7152*toLin(g)+0.0722*toLin(b);
}

function contrast(fg, bg){
  if (!fg || !bg) return null;
  const Lf = lum(fg);
  const Lb = lum(bg);
  return (Math.max(Lf,Lb)+0.05)/(Math.min(Lf,Lb)+0.05);
}

(async ()=>{
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8080/timeline', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.waitForSelector('main');

  const results = await page.evaluate(()=>{
    function pRGB(s){ const m = s && s.match(/(\d+),\s*(\d+),\s*(\d+)/); return m ? [parseInt(m[1]),parseInt(m[2]),parseInt(m[3])] : null; }
    function toLin(c){ const v=c/255; return v<=0.03928? v/12.92 : Math.pow((v+0.055)/1.055,2.4); }
    function lumFrom(c){ return 0.2126*toLin(c[0])+0.7152*toLin(c[1])+0.0722*toLin(c[2]); }
    function contrastC(f,b){ if(!f||!b) return null; const Lf=lumFrom(f); const Lb=lumFrom(b); return (Math.max(Lf,Lb)+0.05)/(Math.min(Lf,Lb)+0.05); }

    const anchors = Array.from(document.querySelectorAll('[data-timeline-item] a'));
    const out = [];
    anchors.forEach(a=>{
      try{
        const cs = window.getComputedStyle(a);
        const fg = pRGB(cs.color);
        // find nearest ancestor with non-transparent background
        let node = a; let bgNode = null;
        while(node && node !== document.documentElement){ const st = window.getComputedStyle(node); const bc = st.backgroundColor; if (bc && bc !== 'rgba(0, 0, 0, 0)' && bc !== 'transparent'){ bgNode = node; break;} node=node.parentElement; }
        const bgStyle = bgNode ? window.getComputedStyle(bgNode).backgroundColor : window.getComputedStyle(document.body).backgroundColor;
        const bg = pRGB(bgStyle);
        const ratio = contrastC(fg,bg);
        out.push({text: a.textContent.trim().slice(0,160), fg: cs.color, bg: bgStyle, ratio: ratio, js_override: a.getAttribute && a.getAttribute('data-js-override')=== 'true', inlineStyle: a.getAttribute('style'), linkOuter: a.outerHTML, timelineAttrs: (()=>{ const it = a.closest('[data-timeline-item]'); if(!it) return null; const o = {}; for(const at of it.attributes) o[at.name]=at.value; return o; })()});
      }catch(e){ }
    });
    return out;
  });

  const failing = results.filter(r=> r.ratio === null ? false : r.ratio < 4.5);
  console.log('Found anchors:', results.length, 'failing:', failing.length);
  failing.slice(0,50).forEach(f=>{
    console.log('----');
    console.log('title:', f.text);
    console.log('fg:', f.fg, 'bg:', f.bg, 'ratio:', f.ratio);
    console.log('js_override:', f.js_override, 'inlineStyle:', f.inlineStyle);
    console.log('timelineAttrs:', JSON.stringify(f.timelineAttrs));
  });

  await browser.close();
})();
