doctype html
html
  head
    meta(charset="utf-8")
    meta(name="color-scheme" content="light dark")
    meta(name="viewport" content="width=device-width, initial-scale=1.0")
    link(rel="icon" href="/favicon.ico")
    link(rel="icon" type="image/svg+xml" href="/favicon.svg" sizes="any")
    link(rel="icon" type="image/png" href="/favicon.png")
    title Quick Timeline - #{title}
    script(src="https://unpkg.com/morphdom/dist/morphdom-umd.min.js")
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
            a(href="/")
              img.w-8.h-8(srcset="/favicon.svg 1x, /favicon.png 1x" src="/favicon.png" alt="Logo" width="32" height="32")
            h1.text-2xl.md:text-3xl.font-semibold.tracking-tight Quick Timeline
          div(class="flex items-center justify-end gap-0.25 md:justify-between md:gap-3 w-full md:w-auto bg-slate-100 dark:bg-indigo-900 px-2 py-1.5 md:px-3 md:py-1.5 rounded-full border border-slate-200 dark:border-indigo-700")
            span#last-update-time(class="text-sm font-medium text-slate-600 dark:text-indigo-100 mr-1" title="Last updated time")
              = last_updated_format(Time.parse_iso8601(updated_at))
            a#home-link(href="/" class="p-1.5 rounded-md hover:bg-slate-200 dark:hover:bg-slate-700 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600 flex items-center justify-center" aria-label="Go to Feeds" title="Back to Feeds")
              svg.w-5.h-5(viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" class="text-slate-700 dark:text-slate-300" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round")
                path(d="M4 11a9 9 0 0 1 9 9")
                path(d="M4 4a16 16 0 0 1 16 16")
                circle(cx="5" cy="19" r="1.5" fill="currentColor" stroke="none")
            button#theme-toggle(class="p-1.5 rounded-md hover:bg-slate-200 dark:hover:bg-slate-700 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-300 dark:focus:ring-slate-600" aria-label="Toggle Theme" onclick="toggleTheme()")
              span(class="text-slate-700 dark:hidden transition-transform duration-200 hover:scale-110 inline-block") 🌙
              span(class="text-yellow-500 hidden dark:inline-block transition-transform duration-200 hover:scale-110") ☀️

      div#timeline-content
        == rendered_timeline

    script
      |
        (function() {
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

          window.toggleTheme = function() {
            const isDark = document.documentElement.classList.toggle('dark');
            setCookie('theme', isDark ? 'dark' : 'light', 365);
          };

          window.loadMoreTimeline = async function(btn) {
            const offset = parseInt(btn.dataset.offset);

            const originalText = btn.innerText;
            btn.innerText = "Loading...";
            btn.disabled = true;

            try {
              const url = `/timeline_items?limit=100&offset=${offset}`;
              const res = await fetch(url);
              if (!res.ok) throw new Error();
              const html = await res.text();

              const temp = document.createElement('div');
              temp.innerHTML = html;

              const timelineContainer = document.querySelector('.timeline-container');
              if (!timelineContainer) return;

              // Get new items and animate them in
              const newContainer = temp.querySelector('.timeline-container');
              if (newContainer) {
                const newItems = Array.from(newContainer.children).filter(
                  el => el.classList.contains('timeline-item') || el.classList.contains('timeline-day-header')
                );

                // Remove existing load more button
                const existingBtn = timelineContainer.querySelector('button[onclick^="loadMoreTimeline"]');
                if (existingBtn) existingBtn.remove();

                // Append new items with fade-in animation
                newItems.forEach((item, index) => {
                  item.style.opacity = '0';
                  item.style.transform = 'translateY(20px)';
                  item.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
                  timelineContainer.appendChild(item);

                  // Trigger animation
                  setTimeout(() => {
                    item.style.opacity = '1';
                    item.style.transform = 'translateY(0)';
                  }, index * 50);
                });
              }
            } catch (e) {
              console.error('Load More error:', e);
              btn.innerText = "Failed";
              setTimeout(() => { btn.innerText = originalText; btn.disabled = false; }, 2000);
            }
          };
        })();
