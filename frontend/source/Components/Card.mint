component Card {
  style base {
    background: #ffffff;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    padding: 16px;
    margin-bottom: 12px;
  }

  style compact {
    padding: 12px;
  }

  style bordered {
    border: 1px solid #e5e7eb;
  }

  fun render : Html {
    <div::base>
    </div>
  }
}
