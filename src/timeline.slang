div.timeline-container.max-w-6xl.mx-auto.px-4.pb-8
  - current_day = nil
  - timeline_items.each do |timeline_item|
    - item_date = timeline_item.item.pub_date
    - if item_date
      - item_day = item_date.to_local.to_s("%A, %B %d, %Y")
      - if item_day != current_day
        - current_day = item_day
        .timeline-day-header.mt-8.mb-6
          .timeline-day-badge.inline-block.rounded-lg.bg-slate-200.dark:bg-indigo-900.px-4.py-2
            h2.timeline-day.text-xl.font-bold.text-slate-800.dark:text-indigo-100
              = current_day

    .timeline-item.flex.items-start.gap-3.py-2.border-b.border-slate-200.dark:border-slate-700
      - if item_date
        span.timeline-time.text-sm.font-medium.text-slate-700.dark:text-slate-300.mt-0_5.min-w-16.text-right.font-mono.bg-slate-100.dark:bg-slate-800.px-2.py-1.rounded-md
          = item_date.to_local.to_s("%I:%M %p")
      - else
        span.timeline-time.text-sm.font-medium.text-slate-700.dark:text-slate-300.mt-0_5.min-w-16.text-right.font-mono.bg-slate-100.dark:bg-slate-800.px-2.py-1.rounded-md
          | ???

      .timeline-content.flex-1.min-w-0
        a.timeline-source-link.text-sm.text-slate-600.dark:text-slate-400.hover:underline.mr-1 href="#{HTML.escape(timeline_item.feed_link)}" target="_blank" rel="noopener noreferrer"
          - if timeline_item.favicon_data == "internal:code_icon"
            svg.inline.mr-1.align-middle xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="width: 12px; height: 12px;"
              polyline points="16 18 22 12 16 6"
              polyline points="8 6 2 12 8 18"
          - elsif (data = timeline_item.favicon_data) && !data.empty?
            img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="#{data}" alt="" style="width: 12px; height: 12px; object-fit: contain;"
          - elsif (fav = timeline_item.favicon) && !fav.empty?
            img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="#{fav}" alt="" style="width: 12px; height: 12px; object-fit: contain;"
          = timeline_item.feed_title
        span.mx-3.text-slate-400.dark:text-slate-600
          | •
        span.ml-4
        a.timeline-link.text-lg.font-medium.text-slate-900.dark:text-slate-100.hover:text-blue-600.dark:hover:text-blue-400 href="#{HTML.escape(timeline_item.item.link)}" target="_blank" rel="noopener noreferrer"
          = timeline_item.item.title

  - if has_more
    div.mt-8.text-center
      button.text-sm.font-medium.text-slate-500.hover:text-slate-800.dark:text-slate-400.dark:hover:text-slate-200.transition-colors.px-4.py-2.rounded-md.bg-slate-100.dark:bg-slate-800.hover:bg-slate-200.dark:hover:bg-slate-700 onclick="loadMoreTimeline(this)" data-offset="#{next_offset}"
        | Load More
