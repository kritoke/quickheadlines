- feeds.each do |feed|
  article.feed-box.min-w-0.break-words.rounded-xl.shadow-sm.p-4
    - head_color = (feed.header_color.try &.strip).presence || "transparent"
    - color_css = HTML.escape(head_color)
    .feed-header style="background: #{color_css};"
      - site_href = HTML.escape(feed.site_link.empty? ? feed.url : feed.site_link)
      h2.feed-title
        a.feed-title-link href=site_href target="_blank" rel="noopener noreferrer"
          = feed.title

    .feed-body
      ul.space-y-1.leading-relaxed
        - feed.items.each do |item|
          - title = HTML.escape(item.title)
          - link  = HTML.escape(item.link)
          li
            a.feed-link href=link target="_blank" rel="noopener noreferrer"
              = title
