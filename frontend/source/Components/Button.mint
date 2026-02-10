component Button {
  style base {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 8px 16px;
    border-radius: #{DesignTokens.RADIUS};
    font-size: #{DesignTokens.FONT_SIZE_BASE};
    font-weight: 500;
    cursor: pointer;
    border: none;
    transition: all 0.2s ease;
  }

  style primary {
    background: #{DesignTokens.ACCENT};
    color: white;
  }

  style secondary {
    background: #{DesignTokens.BORDER_DARK};
    color: #{DesignTokens.TEXT_LIGHT};
  }

  style disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  fun render : Html {
    <button::base::primary::disabled class={disabledClass}>
    </button>
  }

  fun disabledClass : String {
    if (disabled) {
      "disabled"
    } else {
      ""
    }
  }
}
