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
        .timeline-item { opacity: 1; transform: translateY(0); }
        .timeline-item.fade-in {
          animation: fadeIn 0.3s ease-out forwards;
        }
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .loading-sentinel {
          height: 60px;
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 1rem 0;
        }
        .loading-spinner {
          width: 24px;
          height: 24px;
          border: 3px solid #e2e8f0;
          border-top-color: #6366f1;
          border-radius: 50%;
          animation: spin 0.8s linear infinite;
        }
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
        .end-message {
          text-align: center;
          padding: 1.5rem;
          color: #64748b;
          font-size: 0.875rem;
        }
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

          window.expandCluster = function(clusterId) {
            var clusterItems = document.querySelectorAll('.cluster-' + clusterId);
            clusterItems.forEach(function(el) {
              el.classList.remove('hidden');
            });
            var expandBtn = document.querySelector('.cluster-expand-btn[onclick^="expandCluster(' + clusterId + ')"]');
            if (expandBtn) {
              expandBtn.style.display = 'none';
            }
            var collapseBtn = document.createElement('span');
            collapseBtn.className = 'cluster-collapse-btn ml-2 text-xs text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 cursor-pointer';
            collapseBtn.textContent = ' Collapse';
            collapseBtn.onclick = function() { collapseCluster(clusterId); };
            var representative = document.querySelector('.cluster-' + clusterId + ':not(.hidden)');
            if (representative) {
              representative.querySelector('.timeline-content').appendChild(collapseBtn);
            }
          };

          window.collapseCluster = function(clusterId) {
            var clusterItems = document.querySelectorAll('.cluster-item.cluster-' + clusterId);
            clusterItems.forEach(function(el) {
              el.classList.add('hidden');
            });
            var expandBtn = document.querySelector('.cluster-expand-btn[onclick^="expandCluster(' + clusterId + ')"]');
            if (expandBtn) {
              expandBtn.style.display = 'inline';
            }
            var collapseBtns = document.querySelectorAll('.cluster-' + clusterId + ' .cluster-collapse-btn');
            collapseBtns.forEach(function(btn) {
              btn.remove();
            });
          };

          // Infinite scroll implementation
          let currentOffset = 0; // Will be calculated from rendered items
          let isLoading = false;
          let hasMore = true;
          let observer = null;

          function calculateInitialOffset() {
            const timelineContainer = document.querySelector('.timeline-container');
            if (timelineContainer) {
              // Count the number of timeline items rendered
              const items = timelineContainer.querySelectorAll('.timeline-item:not(.hidden)');
              currentOffset = items.length;
            }
          }

          function showEndMessage() {
            const sentinel = document.getElementById('infinite-scroll-sentinel');
            if (sentinel) {
              sentinel.innerHTML = '<div class="end-message">You\'ve reached the end of the timeline</div>';
            }
          }

          async function loadMoreItems() {
            if (isLoading || !hasMore) return;
            
            isLoading = true;
            const sentinel = document.getElementById('infinite-scroll-sentinel');
            if (sentinel) {
              sentinel.innerHTML = '<div class="loading-spinner"></div>';
            }

            try {
              // Capture the last day header to prevent duplicate headers
              const lastDayHeader = document.querySelector('.timeline-day-header:last-of-type');
              const lastDay = lastDayHeader ? lastDayHeader.textContent.trim() : null;
              const url = `/timeline_items?limit=30&offset=${currentOffset}&last_day=${encodeURIComponent(lastDay || '')}`;
              const res = await fetch(url);
              if (!res.ok) throw new Error();
              const html = await res.text();

              // Parse the response HTML (contains items directly, no container)
              const temp = document.createElement('div');
              temp.innerHTML = html;

              // Get the existing timeline container from the page
              const timelineContainer = document.querySelector('.timeline-container');
              if (!timelineContainer) {
                hasMore = false;
                isLoading = false;
                return;
              }

              // Get new items from the response (items and day headers)
              const newItems = Array.from(temp.children).filter(
                el => el.classList.contains('timeline-item') || el.classList.contains('timeline-day-header')
              );

              if (newItems.length === 0) {
                // No more items
                hasMore = false;
                showEndMessage();
                isLoading = false;
                return;
              }

              // Append new items with fade-in animation
              newItems.forEach((item) => {
                item.classList.add('fade-in');
                timelineContainer.appendChild(item);
              });

              currentOffset += newItems.length;
            } catch (e) {
              console.error('Infinite scroll error:', e);
              if (sentinel) {
                sentinel.innerHTML = '<div class="end-message">Error loading more items</div>';
              }
            }

            isLoading = false;

            // Update sentinel for next load or show end message
            if (hasMore && sentinel) {
              sentinel.innerHTML = '<div class="loading-spinner"></div>';
            }
          }

          // Set up Intersection Observer for infinite scroll
          function setupInfiniteScroll() {
            // First calculate the initial offset from rendered items
            calculateInitialOffset();

            const sentinel = document.getElementById('infinite-scroll-sentinel');
            if (!sentinel) return;

            observer = new IntersectionObserver((entries) => {
              entries.forEach(entry => {
                if (entry.isIntersecting && hasMore && !isLoading) {
                  loadMoreItems();
                }
              });
            }, {
              rootMargin: '100px', // Start loading before reaching the bottom
              threshold: 0.1
            });

            observer.observe(sentinel);
          }

          // Initialize infinite scroll when DOM is ready
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', setupInfiniteScroll);
          } else {
            setupInfiniteScroll();
          }
        })();
