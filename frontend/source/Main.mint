component Main {
  style base {
    font-family: "Inter var", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    padding: 0;
    margin: 0;
    min-height: 100vh;
    box-sizing: border-box;
    background: #f9fafb;
  }

  style container {
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
  }

  style header {
    padding: 16px 0;
    border-bottom: 1px solid #e5e7eb;
    margin-bottom: 20px;
  }

  style title {
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }

  fun render : Html {
    <div::base>
      <div::container>
        <div::header>
          <div::title>
          </div>
        </div>
        <Timeline/>
      </div>
    </div>
  }
}
