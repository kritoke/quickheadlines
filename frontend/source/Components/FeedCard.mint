component FeedCard {
  style base {
    display: flex;
    gap: 12px;
    padding: 16px;
    background: #ffffff;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    margin-bottom: 12px;
  }

  style favicon-container {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  style favicon {
    width: 32px;
    height: 32px;
    object-fit: contain;
  }

  style content {
    flex: 1;
    min-width: 0;
  }

  style header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }

  style feed-title {
    font-size: 12px;
    color: #6b7280;
    font-weight: 500;
  }

  style title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
    line-height: 1.4;
    margin: 0 0 4px 0;
  }

  style meta {
    font-size: 12px;
    color: #9ca3af;
  }

  style link {
    color: inherit;
    text-decoration: none;
  }

  fun render : Html {
    <a::link href={item.link} target="_blank" rel="noopener noreferrer">
      <div::base>
        <div::favicon-container style="background-color: {item.headerColor}">
          <img::favicon src={item.favicon} alt={item.feedTitle}/>
        </div>
        <div::content>
          <div::header>
            <span::feed-title style="color: {item.headerTextColor}">
            </span>
          </div>
          <h3::title>
          </h3>
          <div::meta>
          </div>
        </div>
      </div>
    </a>
  }
}
