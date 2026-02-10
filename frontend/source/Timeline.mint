component Timeline {
  connect FeedStore exposing { feeds, loading }

  style gridContainer {
    display: grid;
    gap: 20px;
    padding: 20px;
    height: calc(100vh - 80px);
    overflow-y: auto;
    position: relative;
    grid-template-columns: repeat(3, 1fr);
    background: #1a1a1b;

    @media (max-width: 1100px) {
      grid-template-columns: repeat(2, 1fr);
    }

    @media (max-width: 700px) {
      grid-template-columns: 1fr;
    }
  }

  style bottomShadow {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    height: 60px;
    pointer-events: none;
    z-index: 100;
    background: linear-gradient(transparent, rgba(0,0,0,0.8));
  }

  style loading {
    color: #d7dadc;
    text-align: center;
    padding: 40px;
  }

  fun render : Html {
    <div::gridContainer data-name="feed-grid-root">
      if loading {
        <div::loading>
          "Loading..."
        </div>
      } else {
        <FeedGrid feeds={feeds}/>
      }
      <div::bottomShadow/>
    </div>
  }
}
