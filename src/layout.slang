doctype html
html
  head
    meta(charset="utf-8")
    meta(name="color-scheme" content="light dark")
    meta(name="viewport" content="width=device-width, initial-scale=1.0")
    link(rel="icon" href="/favicon.ico")
    link(rel="icon" type="image/svg+xml" href="/favicon.svg" sizes="any")
    link(rel="icon" type="image/png" href="/favicon.png")
    title = title
    script(src="https://unpkg.com/morphdom/dist/morphdom-umd.min.js")
    script(src="https://cdnjs.cloudflare.com/ajax/libs/color-thief/2.3.2/color-thief.umd.js")
    script
      |
        // Cookie helper functions
        function getCookie(name) {
          const value = `; ${document.cookie}`;
          const parts = value.split(`; ${name}=`);
          if (parts.length === 2) return parts.pop().split(';').shift();
          return null;
        }

        function setCookie(name, value, days) {
          const expires = new Date();
          expires.setTime(expires.getTime() + (days * 24 * 60 * 60 * 1000));
          document.cookie = `${name}=${value};expires=${expires.toUTCString()};path=/;SameSite=Lax`;
        }

        // Initialize theme from cookie or system preference
        const themeCookie = getCookie('theme');
        const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        if (themeCookie === 'dark' || (!themeCookie && systemPrefersDark)) {
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
      header(class="mb-4")
        div(class="flex flex-col md:flex-row md:items-center justify-between py-3 border-b border-slate-200 dark:border-slate-700 gap-2 md:gap-0")
          div.flex.items-center.gap-3.w-full.md:w-auto
            img.w-8.h-8(srcset="/favicon.svg 1x, /favicon.png 1x" src="/favicon.png" alt="Logo" width="32" height="32")
            h1.text-2xl.md:text-3xl.font-semibold.tracking-tight = title
          div(class="flex items-center justify-end gap-0.25 md:justify-between md:gap-3 w-full md:w-auto bg-slate-100 dark:bg-slate-800 px-2 py-1.5 md:px-3 md:py-1.5 rounded-full border border-slate-200 dark:border-slate-700")
            span#last-update-time(class="text-sm font-medium text-slate-600 dark:text-slate-300 mr-1" title="Last updated time")
              = last_updated_format(Time.parse_iso8601(updated_at))
            a#timeline-link(href="/timeline" class="p-1.5 rounded-md hover:bg-slate-200 dark:hover:bg-slate-700 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600 flex items-center justify-center" aria-label="View Timeline" title="View Timeline")
              svg.w-5.h-5(viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" class="text-slate-700 dark:text-slate-300")
                circle(cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round")
                path(d="M12 3v6l4 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round")
            button#theme-toggle(class="p-1.5 rounded-md hover:bg-slate-200 dark:hover:bg-slate-700 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600 flex items-center justify-center" aria-label="Toggle Theme" onclick="toggleTheme()")
              span(class="text-slate-700 dark:hidden transition-transform duration-200 hover:scale-110 inline-block") 🌙
              span(class="text-yellow-500 hidden dark:inline-block transition-transform duration-200 hover:scale-110") ☀️

      nav.tab-container
        - tabs.each do |tab|
          - is_active = (active_tab == tab.name)
          a(class="tab-link text-lg md:text-2xl #{is_active ? "active" : ""}" href="/?tab=#{tab.name}" onclick="switchTab(event, '#{tab.name}')")
            = tab.name

      section#feed-grid(class="grid w-full gap-4 md:gap-5 lg:gap-6 grid-cols-1 md:grid-cols-2 lg:grid-cols-3 text-[0.95rem] md:text-[1rem]")
        - render_feed_boxes(io, active_tab)
    script
      |
        (function() {
          const intervalMs = 30000;
          let last = null;
          const grid = document.getElementById('feed-grid');
          const lastUpdateLabel = document.getElementById('last-update-time');
          window.feedHeaderCache = window.feedHeaderCache || {};

          window.toggleTheme = function() {
            const isDark = document.documentElement.classList.toggle('dark');
            setCookie('theme', isDark ? 'dark' : 'light', 365);
            if (window.updateAdaptiveColors) window.updateAdaptiveColors();
            if (window.updateScrollShadows) window.updateScrollShadows();
          };

          window.loadTab = async function(tabName, pushState = true) {
            document.querySelectorAll('.tab-link').forEach(link => {
              link.classList.toggle('active', link.innerText.trim() === tabName);
            });

            if (pushState) {
              const url = new URL(window.location);
              url.searchParams.set('tab', tabName);
              window.history.pushState({tab: tabName}, '', url);
            }

            try {
              const res = await fetch('/feeds?tab=' + encodeURIComponent(tabName));
              if (!res.ok) return;
              const html = await res.text();
              if (window.morphdom) {
                const clone = grid.cloneNode(false);
                clone.innerHTML = html;
                morphdom(grid, clone);
              } else {
                grid.innerHTML = html;
              }
              window.updateAdaptiveColors();
              window.updateScrollShadows();
            } catch(e) {}
          };

          window.switchTab = (e, name) => { e.preventDefault(); window.loadTab(name); };
          window.addEventListener('popstate', () => {
            const tab = new URLSearchParams(window.location.search).get('tab') || document.querySelector('.tab-link')?.innerText.trim();
            if (tab) window.loadTab(tab, false);
          });
          const initialTab = new URLSearchParams(window.location.search).get('tab') || document.querySelector('.tab-link.active')?.innerText.trim();
          if (initialTab) window.history.replaceState({tab: initialTab}, '', window.location);

          window.updateScrollShadows = function() {
            document.querySelectorAll('.feed-body').forEach(el => {
              const box = el.closest('.feed-box');
              if (box) {
                const isAtBottom = el.scrollHeight - el.scrollTop <= el.clientHeight + 5;
                box.classList.toggle('is-at-bottom', isAtBottom);
              }
            });
          };

          window.addEventListener('scroll', (e) => {
            if (e.target.classList && e.target.classList.contains('feed-body')) {
              const el = e.target;
              const box = el.closest('.feed-box');
              if (box) {
                const isAtBottom = el.scrollHeight - el.scrollTop <= el.clientHeight + 5;
                box.classList.toggle('is-at-bottom', isAtBottom);
              }
            }
          }, true);

          window.updateAdaptiveColors = function() {
            if (typeof ColorThief === 'undefined') return;
            const colorThief = new ColorThief();

            document.querySelectorAll('.feed-header').forEach(header => {
              // Check if a custom color is explicitly set in the config.
              // If the attribute is true but the style is transparent/empty (e.g., empty string in config),
              // we should treat it as "no custom color" and allow adaptive colors to run.
              if (header.dataset.hasCustomColor === 'true') {
                const bg = header.style.backgroundColor;
                if (bg && bg !== 'transparent' && bg !== '' && bg !== 'rgba(0, 0, 0, 0)') {
                  return; // A valid color is set, do not override
                }
              }

              const link = header.querySelector('a.feed-title-link');
              const feedUrl = link ? link.href : null;

              if (feedUrl && window.feedHeaderCache[feedUrl]) {
                const cached = window.feedHeaderCache[feedUrl];
                header.style.backgroundColor = cached.bg;
                header.style.color = cached.text;
                if (link) link.style.color = cached.text;
                header.dataset.adaptive = 'true';
                return;
              }

              let img = header.querySelector('img');
              // Fallback: If the image is not inside the header, search within the parent .feed-box
              if (!img) {
                const box = header.closest('.feed-box');
                if (box) {
                  img = box.querySelector('img');
                }
              }

              if (!img || !img.getAttribute('src') || header.dataset.adaptive) return;

              const proxy = new Image();
              proxy.crossOrigin = 'Anonymous';
              // Local favicons don't need proxying - they're on the same origin
              if (img.src.startsWith('data:') || img.src.startsWith('/favicons/')) {
                proxy.src = img.src;
              } else {
                proxy.src = '/proxy_image?url=' + encodeURIComponent(img.src);
              }

              proxy.onload = function() {
                try {
                  const palette = colorThief.getPalette(proxy, 5);
                  if (!palette || !palette.length) return;

                  let color = palette[0];

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
                  const bgColor = 'rgb(' + r + ',' + g + ',' + b + ')';

                  header.style.backgroundColor = bgColor;
                  header.style.color = textColor;
                  if (link) link.style.color = textColor;

                  if (feedUrl) {
                    window.feedHeaderCache[feedUrl] = { bg: bgColor, text: textColor };
                  }

                  header.dataset.adaptive = 'true';
                } catch (e) {}
              };
            });
          }

          window.loadMore = async function(btn) {
            const url = btn.dataset.url;
            const currentCount = parseInt(btn.dataset.currentCount);

            const originalText = btn.innerText;
            btn.innerText = "Loading...";
            btn.disabled = true;

            try {
              // Request next 10 items starting from currentCount
              const res = await fetch(`/feed_more?url=${encodeURIComponent(url)}&limit=10&offset=${currentCount}`);
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
              window.updateScrollShadows();
            } catch (e) {
              console.error('Load More error:', e);
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
                const params = new URLSearchParams(window.location.search);
                const currentTab = params.get('tab') || "";
                const feedRes = await fetch('/feeds' + (currentTab ? '?tab=' + encodeURIComponent(currentTab) : ''), {cache: 'no-store'});
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
              window.updateScrollShadows();
                const d = new Date(parseInt(v));
                if (lastUpdateLabel) {
                  const localDate = new Date(d.toLocaleString('en-US', { timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone }));
                  lastUpdateLabel.innerText = localDate.toLocaleString('en-US', {
                    hour: 'numeric',
                    minute: '2-digit',
                    hour12: true,
                    timeZoneName: 'short',
                    month: 'long',
                    day: 'numeric',
                    year: 'numeric'
                  });
                }
                last = v;
              }
            } catch (_) {}
          }
          check();
          window.updateAdaptiveColors();
          window.updateScrollShadows();
          setInterval(check, intervalMs);
        })();``````