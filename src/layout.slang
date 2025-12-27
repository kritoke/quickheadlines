doctype html
html
  head
    meta charset="utf-8"
    meta name="color-scheme" content="light dark"
    meta name="viewport" content="width=device-width, initial-scale=1.0"
    link rel="icon" href="/favicon.ico"
    link rel="icon" type="image/svg+xml" href="/favicon.svg" sizes="any"
    link rel="icon" type="image/png" href="/favicon.png"
    title = title
    script src="https://unpkg.com/morphdom/dist/morphdom-umd.min.js"
    script src="https://cdnjs.cloudflare.com/ajax/libs/color-thief/2.3.2/color-thief.umd.js"
    script
      |
        if (localStorage.theme === 'dark' || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
          document.documentElement.classList.add('dark');
        } else {
          document.documentElement.classList.remove('dark');
        }
    style == css
    style
      |
        @keyframes highlight {
          0% { background-color: rgba(253, 224, 71, 0.4); }
          100% { background-color: transparent; }
        }
        .animate-highlight { animation: highlight 2s ease-out; border-radius: 0.25rem; }
  body(class="bg-surface-light text-slate-800 dark:bg-surface-dark dark:text-slate-100 text-[15px] md:text-[16px] leading-7")
    main(class="mx-auto max-w-[1600px] px-4 md:px-12 lg:px-24")
      div.flex.items-center.justify-between.my-3.pl-4
        div.flex.items-center.gap-3
          img.w-8.h-8(srcset="/favicon.svg 1x, /favicon.png 1x" src="/favicon.png" alt="Logo" width="32" height="32")
          h1.text-3xl.font-semibold.tracking-tight = title
        button#theme-toggle(class="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors" onclick="toggleTheme()" aria-label="Toggle Theme")
          span.dark:hidden 🌙
          span.hidden.dark:inline ☀️
      section#feed-grid(class="grid gap-4 md:gap-5 lg:gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3 text-[0.95rem] md:text-[1rem]")
        - render_feed_boxes(io)
      p.updated.mt-3.text-sm.opacity-80.text-left.pl-4
        | Feeds last refreshed on #{updated_at}
    script
      |
        (function() {
          const intervalMs = 30000;
          let last = null;
          const grid = document.getElementById('feed-grid');
          const label = document.querySelector('.updated');

          window.toggleTheme = function() {
            const isDark = document.documentElement.classList.toggle('dark');
            localStorage.theme = isDark ? 'dark' : 'light';
            if (window.updateAdaptiveColors) window.updateAdaptiveColors();
          };

          window.updateAdaptiveColors = function() {
            if (typeof ColorThief === 'undefined') return;
            const colorThief = new ColorThief();
            
            document.querySelectorAll('.feed-header').forEach(header => {
              if (header.dataset.adaptive) return;
              if (header.dataset.hasCustomColor === 'true') return;

              const img = header.querySelector('img');
              if (!img) return;

              const proxy = new Image();
              proxy.crossOrigin = 'Anonymous';
              if (img.src.startsWith('data:')) {
                proxy.src = img.src;
              } else {
                proxy.src = '/proxy_image?url=' + encodeURIComponent(img.src);
              }
              
              proxy.onload = function() {
                try {
                  const palette = colorThief.getPalette(proxy, 5);
                  if (!palette || !palette.length) return;

                  let color = palette[0];

                  // Heuristic: if dominant color is grayscale (low saturation), try next
                  const isGrayscale = (c) => {
                    const max = Math.max(c[0], c[1], c[2]);
                    const min = Math.min(c[0], c[1], c[2]);
                    return (max - min) < 30;
                  };

                  if (isGrayscale(color)) {
                    for (let i = 1; i < palette.length; i++) {
                      if (!isGrayscale(palette[i])) {
                        color = palette[i];
                        break;
                      }
                    }
                  }

                  const [r, g, b] = color;
                  const yiq = ((r * 299) + (g * 587) + (b * 114)) / 1000;
                  const textColor = (yiq >= 128) ? '#1f2937' : '#ffffff';
                  
                  header.style.backgroundColor = 'rgb(' + r + ',' + g + ',' + b + ')';
                  header.style.color = textColor;
                  const link = header.querySelector('a');
                  if (link) link.style.color = textColor;
                  
                  header.dataset.adaptive = 'true';
                } catch (e) {}
              };
            });
          }

          window.loadMore = async function(btn) {
            const url = btn.dataset.url;
            const currentCount = parseInt(btn.dataset.currentCount);
            const newLimit = currentCount + 10;
            
            const originalText = btn.innerText;
            btn.innerText = "Loading...";
            btn.disabled = true;
            
            try {
              const res = await fetch(`/feed_more?url=${encodeURIComponent(url)}&limit=${newLimit}`);
              if (!res.ok) throw new Error();
              const html = await res.text();
              
              const feedBox = btn.closest('.feed-box');
              if (window.morphdom) {
                morphdom(feedBox, html, {
                  onNodeAdded: function(node) {
                    if (node.nodeName === 'LI') node.classList.add('animate-highlight');
                  }
                });
              } else {
                feedBox.outerHTML = html;
              }
              window.updateAdaptiveColors();
            } catch (e) {
              btn.innerText = "Failed";
              setTimeout(() => { btn.innerText = originalText; btn.disabled = false; }, 2000);
            }
          };

          async function check() {
            try {
              const res = await fetch('/version', {cache: 'no-store'});
              if (!res.ok) return;
              const v = await res.text();

              if (last === null) {
                last = v;
                return;
              }

              if (v !== last) {
                const feedRes = await fetch('/feeds', {cache: 'no-store'});
                if (!feedRes.ok) return;
                const html = await feedRes.text();
                if (window.morphdom) {
                  const clone = grid.cloneNode(false);
                  clone.innerHTML = html;
                  morphdom(grid, clone, {
                    onNodeAdded: function(node) {
                      if (node.nodeName === 'LI') {
                        node.classList.add('animate-highlight');
                      }
                    }
                  });
                } else {
                  grid.innerHTML = html;
                }
                window.updateAdaptiveColors();
                const d = new Date(parseInt(v));
                if (label) label.innerText = "Feeds last refreshed on " + d.toLocaleString();
                last = v;
              }
            } catch (_) {}
          }
          check();
          window.updateAdaptiveColors();
          setInterval(check, intervalMs);
        })();
