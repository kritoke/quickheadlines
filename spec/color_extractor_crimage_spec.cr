require "./spec_helper"

describe "ColorExtractor CrImage integration" do
  describe ".theme_aware_extract_from_favicon" do
    it "returns nil for non-existent files" do
      result = ColorExtractor.extract_theme_colors("/nonexistent.png", "http://example.com", nil)
      result.should be_nil
    end

    it "returns nil when manual override is set" do
      result = ColorExtractor.extract_theme_colors("/any.png", "http://example.com", "#ff0000")
      result.should be_nil
    end
  end

  describe ".auto_correct_theme_json" do
    it "returns nil when theme_json is nil" do
      result = ColorExtractor.correct_theme_json(nil, nil, nil)
      result.should be_nil
    end

    it "returns corrected theme when text has low contrast" do
      theme = {"bg" => "#808080", "text" => {"primary" => "#808080"}}.to_json
      result = ColorExtractor.correct_theme_json(theme, nil, nil)
      result.should_not be_nil
      parsed = JSON.parse(result.as(String))
      ["auto", "auto-corrected"].includes?(parsed["source"].to_s).should be_true
    end

    it "keeps theme when text meets contrast" do
      theme = {"bg" => "#ffffff", "text" => {"light" => "#000000"}}.to_json
      result = ColorExtractor.correct_theme_json(theme, nil, nil)
      result.should_not be_nil
      parsed = JSON.parse(result.as(String))
      parsed["source"].should eq("auto")
    end
  end

  describe ".upgrade_theme_json" do
    it "returns nil for nil input" do
      result = ColorExtractor.upgrade_theme_json(nil)
      result.should be_nil
    end

    it "returns nil when source is not auto" do
      theme = {"bg" => "#ffffff", "text" => {"light" => "#000000"}, "source" => "manual"}.to_json
      result = ColorExtractor.upgrade_theme_json(theme)
      result.should be_nil
    end
  end

  describe "contrast helpers" do
    it "calculates luminance correctly" do
      ColorExtractor.luminance([255, 255, 255]).should eq(1.0)
      ColorExtractor.luminance([0, 0, 0]).should eq(0.0)
    end

    it "calculates contrast ratio correctly" do
      ratio = ColorExtractor.contrast([0, 0, 0], [255, 255, 255])
      ratio.should be > 20.0
      ratio.should be < 22.0
    end

    it "finds readable foreground for light background" do
      rgb = [250, 250, 250]
      t = ColorExtractor.suggest_foreground_for_bg(rgb)
      t.should be_a(String)
      t.should start_with("#")
    end

    it "finds readable foreground for dark background" do
      rgb = [10, 10, 10]
      t = ColorExtractor.suggest_foreground_for_bg(rgb)
      t.should be_a(String)
      t.should start_with("#")
    end
  end
end
