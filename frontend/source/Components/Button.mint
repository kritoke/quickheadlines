component Button {
  style base {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 8px 16px;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    border: none;
  }

  style primary {
    background: #2563eb;
    color: #ffffff;
  }

  style secondary {
    background: #f3f4f6;
    color: #1f2937;
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
