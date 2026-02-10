component FeedBox {
  property source : FeedSource

  style box {
    background: #272729;
    border: 1px solid #343536;
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    height: 500px;
    overflow: hidden;
    box-shadow: 0 4px 6px rgba(0,0,0,0.05);
  }

  style header {
    padding: 12px;
    font-weight: bold;
    border-bottom: 1px solid #343536;
    background: #1a1a1b;
  }

  style itemsList {
    flex: 1;
    overflow-y: auto;
  }

  fun render : Html {
    <div::box data-name="feed-box">
      <div::header>
        <span style="font-weight: bold;">
          Feed
        </span>
      </div>
      <div::itemsList>
        for article of source.articles {
          <FeedCard item={article}/>
        }
      </div>
    </div>
  }
}
