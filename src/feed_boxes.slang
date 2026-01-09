- all_content = feeds + releases
- all_content.each do |feed|
  article.feed-box.w-full.min-w-0.shadow-sm
    - color_css = HTML.escape(feed.display_header_color)
    - has_custom = !feed.header_color.nil?
    - is_sw_default = feed.url == "software://releases" && feed.header_color == "#24292e"
    - header_style = has_custom ? "background-color: #{color_css};" : ""
    - header_style += " color: white;" if is_sw_default
    .feed-header style="#{header_style}" data-has-custom-color="#{has_custom}"
      h2.feed-title.flex.items-center.gap-2
        - if feed.favicon_data == "internal:code_icon"
          svg.w-5.h-5 xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"
            polyline points="16 18 22 12 16 6"
            polyline points="8 6 2 12 8 18"
        - elsif (data = feed.favicon_data) && !data.empty?
          img class="w-5 h-5 rounded-sm bg-white dark:bg-slate-300 p-0.5 ring-1 ring-black/5 dark:ring-black/60 flex-shrink-0" src="#{data}" loading="lazy" alt=""
        - elsif (fav = feed.favicon) && !fav.empty?
          img class="w-5 h-5 rounded-sm bg-white dark:bg-slate-300 p-0.5 ring-1 ring-black/5 dark:ring-black/60 flex-shrink-0" src="#{fav}" loading="lazy" alt=""
        a.feed-title-link.hover:underline href="#{HTML.escape(feed.display_link)}" target="_blank" rel="noopener noreferrer"
          = feed.title

    .feed-body
      ul.space-y-1.leading-relaxed
        - feed.items.each do |item|
          li
            a.feed-link.hover:underline href="#{HTML.escape(item.link)}" target="_blank" rel="noopener noreferrer"
              = item.title
            span.text-xs.text-slate-500.ml-2.dark:text-slate-400
              - if version = item.version
                = version
                - if item.pub_date
                  |  •
              - if date = item.pub_date
                span title="#{date.to_local.to_s("%A, %b %d, %Y at %I:%M %p")}"
                  = relative_time(date)
              - elsif !item.version
                = current_date_fallback
      - if feed.items.size >= 10 && feed.url != "software://releases"
        div.mt-4.text-center
          button.text-xs.font-medium.text-slate-500.hover:text-slate-800.dark:text-slate-400.dark:hover:text-slate-200.transition-colors.px-3.py-1.rounded-md.bg-slate-100.dark:bg-slate-800.hover:bg-slate-200.dark:hover:bg-slate-700 onclick="loadMore(this)" data-url="#{HTML.escape(feed.url)}" data-current-count="#{feed.items.size}"
            | Load More
