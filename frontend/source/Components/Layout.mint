component Layout {
  style container {
    max-width: 800px;
    margin: 0 auto;
    padding: #{DesignTokens.GAP};
  }

  style header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 0;
    border-bottom: 1px solid #{DesignTokens.BORDER_DARK};
    margin-bottom: #{DesignTokens.GAP};
  }

  style title {
    font-size: #{DesignTokens.FONT_SIZE_2XL};
    font-weight: 700;
    color: #{DesignTokens.TEXT_LIGHT};
  }

  style content {
    min-height: calc(100vh - 100px);
  }

  style footer {
    padding: 20px 0;
    border-top: 1px solid #{DesignTokens.BORDER_DARK};
    margin-top: 40px;
    text-align: center;
    color: #{DesignTokens.TEXT_GRAY};
    font-size: #{DesignTokens.FONT_SIZE_SMALL};
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
