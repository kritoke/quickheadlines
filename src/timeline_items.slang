  - current_day = last_day || ""
  - hidden_counts = {} of Int64 => Int32  # Track hidden items per cluster
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

    -# Calculate if this item should be hidden and track cluster counts
    - is_hidden = !timeline_item.is_representative
    - if is_hidden && (cluster_id = timeline_item.cluster_id)
      - hidden_counts[cluster_id] = (hidden_counts[cluster_id]? || 0) + 1

    .timeline-item.flex.items-start.gap-3.py-2.border-b.border-slate-200.dark:border-slate-700 class=(is_hidden ? "qh-hidden cluster-#{timeline_item.cluster_id}" : "")
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
          - elsif (data = timeline_item.favicon_data) && !data.empty? && data.starts_with?("/favicons/")
            - host = timeline_item.feed_link.empty? ? timeline_item.feed_url : timeline_item.feed_link
            - parsed = URI.parse(host)
            - if parsed && (parsed_host = parsed.host)
              img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64" alt="" style="width: 12px; height: 12px; object-fit: contain;"
            - elsif !data.empty?
              img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="#{data}" alt="" style="width: 12px; height: 12px; object-fit: contain;"
          - elsif (fav = timeline_item.favicon) && !fav.empty? && fav.starts_with?("/favicons/")
            - host = timeline_item.feed_link.empty? ? timeline_item.feed_url : timeline_item.feed_link
            - parsed = URI.parse(host)
            - if parsed && (parsed_host = parsed.host)
              img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64" alt="" style="width: 12px; height: 12px; object-fit: contain;"
            - elsif !fav.empty?
              img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="#{fav}" alt="" style="width: 12px; height: 12px; object-fit: contain;"
          - elsif (fav = timeline_item.favicon) && !fav.empty? && fav.starts_with?("http")
            img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="#{fav}" alt="" style="width: 12px; height: 12px; object-fit: contain;"
          - else
            - host = timeline_item.feed_link.empty? ? timeline_item.feed_url : timeline_item.feed_link
            - parsed = URI.parse(host)
            - if parsed && (parsed_host = parsed.host)
              img.inline.mr-1.align-middle.rounded-sm.bg-white.dark:bg-slate-300.p-0_5 src="https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64" alt="" style="width: 12px; height: 12px; object-fit: contain;"
          = timeline_item.feed_title
        span.text-slate-400.dark:text-slate-600
          | •
        a.timeline-link.text-xs.md:text-sm.font-medium.text-slate-900.dark:text-slate-100.hover:text-blue-600.dark:hover:text-blue-400 href="#{HTML.escape(timeline_item.item.link)}" target="_blank" rel="noopener noreferrer" == HTML.escape(timeline_item.item.title)

        -# Cluster expand/collapse button - only show for representatives with hidden items in view
        - if timeline_item.is_representative && timeline_item.cluster_id && (hidden_count = hidden_counts[timeline_item.cluster_id]?)
          span.cluster-expand-btn.ml-2.text-xs.text-blue-600.dark:text-blue-400.hover:underline.cursor-pointer onclick="expandCluster(#{timeline_item.cluster_id})"
            | ↳ Expand (#{hidden_count} more)
