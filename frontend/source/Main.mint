component Main {
  style base {
    font-family: "Inter var", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    padding: 0;
    margin: 0;
    min-height: 100vh;
    box-sizing: border-box;
    background: #1a1a1b;
  }

  style container {
    max-width: 800px;
    margin: 0 auto;
    padding: 15px;
  }

  style header {
    padding: 16px 0;
    border-bottom: 1px solid #343536;
    margin-bottom: 15px;
  }

  style title {
    font-size: 24px;
    font-weight: 700;
    color: #d7dadc;
  }

  fun render : Html {
    <div::base>
      <div::container>
        <div::header>
          <div::title>
            { "QuickHeadlines" }
          </div>
        </div>
        <Timeline/>
      </div>
    </div>
  }
}
