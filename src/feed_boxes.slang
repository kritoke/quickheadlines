- feeds.each do |feed|
  article.feed-box.min-w-0.break-words.rounded-xl.shadow-sm.p-4
    - color_css = HTML.escape(feed.display_header_color)
    - has_custom = !feed.header_color.nil?
    .feed-header style="background: #{color_css};" data-has-custom-color="#{has_custom}"
      h2.feed-title.flex.items-center.gap-2
        - if data = feed.favicon_data
          img.w-5.h-5.rounded-sm src="#{data}" loading="lazy" alt=""
        - elsif fav = feed.favicon
          img.w-5.h-5.rounded-sm src="#{HTML.escape(fav)}" loading="lazy" alt=""
        a.feed-title-link.hover:underline href="#{HTML.escape(feed.display_link)}" target="_blank" rel="noopener noreferrer"
          = feed.title

    .feed-body
      ul.space-y-1.leading-relaxed
        - feed.items.each do |item|
          li
            a.feed-link.hover:underline href="#{HTML.escape(item.link)}" target="_blank" rel="noopener noreferrer"
              = item.title
            - if date = item.pub_date
              span.text-xs.text-slate-500.ml-2.dark:text-slate-400 title="#{date.to_local.to_s("%A, %b %d, %Y at %I:%M %p")}"
                = relative_time(date)
      - if feed.items.size > 0
        div.mt-4.text-center
          button.text-xs.font-medium.text-slate-500.hover:text-slate-800.dark:text-slate-400.dark:hover:text-slate-200.transition-colors.px-3.py-1.rounded-md.bg-slate-100.dark:bg-slate-800.hover:bg-slate-200.dark:hover:bg-slate-700 onclick="loadMore(this)" data-url="#{HTML.escape(feed.url)}" data-current-count="#{feed.items.size}"
            | Load More
