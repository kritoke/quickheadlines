component Card {
  style base {
    background: #{DesignTokens.CARD_BG_DARK};
    border-radius: #{DesignTokens.RADIUS};
    box-shadow: #{DesignTokens.SHADOW_SM};
    padding: #{DesignTokens.GAP};
    margin-bottom: #{DesignTokens.GAP};
    border: 1px solid #{DesignTokens.BORDER_DARK};
  }

  style compact {
    padding: 12px;
  }

  fun render : Html {
    <div::base>
    </div>
  }
}
