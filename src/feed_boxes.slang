- feeds.each do |feed|
  article.feed-box.min-w-0.break-words.rounded-xl.shadow-sm.p-4
    - color_css = HTML.escape(feed.display_header_color)
    .feed-header style="background: #{color_css};"
      h2.feed-title
        a.feed-title-link href="#{HTML.escape(feed.display_link)}" target="_blank" rel="noopener noreferrer"
          = feed.title

    .feed-body
      ul.space-y-1.leading-relaxed
        - feed.items.each do |item|
          li
            a.feed-link href="#{HTML.escape(item.link)}" target="_blank" rel="noopener noreferrer"
              = item.title
