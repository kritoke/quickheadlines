component Layout {
  style container {
    max-width: 800px;
    margin: 0 auto;
    padding: 20px;
  }

  style header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 0;
    border-bottom: 1px solid #e5e7eb;
    margin-bottom: 20px;
  }

  style title {
    font-size: 24px;
    font-weight: 700;
    color: #111827;
  }

  style content {
    min-height: calc(100vh - 100px);
  }

  style footer {
    padding: 20px 0;
    border-top: 1px solid #e5e7eb;
    margin-top: 40px;
    text-align: center;
    color: #6b7280;
    font-size: 12px;
  }

  fun render : Html {
    <div::container>
      <div::header>
        <div::title>
        </div>
      </div>
      <div::content>
      </div>
      <div::footer>
      </div>
    </div>
  }
}
