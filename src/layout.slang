doctype html
html
  head
    meta charset="utf-8"
    meta name="color-scheme" content="light dark"
    meta name="viewport" content="width=device-width, initial-scale=1.0"
    link rel="icon" type="image/svg+xml" href="/favicon.svg" 
    link rel="shortcut icon" href="/favicon.ico" sizes="any" 
    link rel="alternate icon" type="image/png" href="/favicon.png"
    title = title
    script src="https://cdn.tailwindcss.com"
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
  body(class="bg-surface-light text-slate-800 dark:bg-surface-dark dark:text-slate-100 text-[15px] md:text-[16px] leading-7")
    main(class="mx-auto max-w-[1800px] px-4")
      h1.text-3xl.font-semibold.tracking-tight.my-4 = title
      section#feed-grid(class="grid gap-4 grid-cols-1 md:grid-cols-2 lg:grid-cols-3 text-[0.95rem] md:text-[1rem]")
        == render_feed_boxes(io)
      p.updated.mt-3.text-sm.opacity-80.text-left
        | Feeds last refreshed on #{updated_at}
    script
      |
        (function() {
          const intervalMs = 10000;
          let last = null;
          async function check() {
            try {
              const res = await fetch('/version', {cache: 'no-store'});
              if (!res.ok) return;
              const v = await res.text();
              if (last === null) {
                last = v;
              } else if (v !== last) {
                location.reload();
              }
            } catch (_) {}
          }
          check();
          setInterval(check, intervalMs);
        })();
