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
    script src="https://cdn.tailwindcss.com"
    script src="https://unpkg.com/morphdom/dist/morphdom-umd.min.js"
    script
      |
        tailwind.config = {
          darkMode: 'class',
          theme: {
            extend: {
              colors: {
                surface: { DEFAULT: '#1f2937', light: '#f9fafb', dark: '#111827' },
                card:    { DEFAULT: '#111827', light: '#ffffff' },
                border:  { subtle: '#334155', light: '#e5e7eb' },
              }
            }
          }
        }
    script
      |
        if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
          document.documentElement.classList.add('dark');
        }
    style
      | #{css}
    style
      |
        @keyframes highlight {
          0% { background-color: rgba(253, 224, 71, 0.4); }
          100% { background-color: transparent; }
        }
        .animate-highlight { animation: highlight 2s ease-out; border-radius: 0.25rem; }
  body(class="bg-surface-light text-slate-800 dark:bg-surface-dark dark:text-slate-100 text-[15px] md:text-[16px] leading-7")
    main(class="mx-auto max-w-[1600px] px-4 md:px-12 lg:px-24")
      div.flex.items-center.gap-3.my-3.pl-4
        img.w-8.h-8(srcset="/favicon.svg 1x, /favicon.png 1x" src="/favicon.png" alt="Logo" width="32" height="32")
        h1.text-3xl.font-semibold.tracking-tight = title
      section#feed-grid(class="grid gap-4 md:gap-5 lg:gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3 text-[0.95rem] md:text-[1rem]")
        - render_feed_boxes(io)
      p.updated.mt-3.text-sm.opacity-80.text-left.pl-4
        | Feeds last refreshed on #{updated_at}
    script
      |
        (function() {
          const intervalMs = 10000;
          let last = null;
          const grid = document.getElementById('feed-grid');
          const label = document.querySelector('.updated');

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
                const d = new Date(parseInt(v));
                if (label) label.innerText = "Feeds last refreshed on " + d.toLocaleString();
                last = v;
              }
            } catch (_) {}
          }
          check();
          setInterval(check, intervalMs);
        })();
