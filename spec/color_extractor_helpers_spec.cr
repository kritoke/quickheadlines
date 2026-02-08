require "./spec_helper"

describe "ColorExtractor helpers" do
  it "converts rgb array to hex" do
    ColorExtractor.rgb_to_hex_public([255, 0, 0]).should eq("#ff0000")
  end

  it "finds readable dark text for a light background" do
    rgb = [250, 250, 250]
    t = ColorExtractor.find_dark_text_for_bg_public(rgb)
    t.should be_a(String)
    t.should start_with("#")
  end

  it "upgrades auto theme when both roles meet contrast" do
    theme = {"bg" => "#ffffff", "text" => {"light" => "#000000", "dark" => "#000000"}, "source" => "auto"}.to_json
    res = ColorExtractor.auto_upgrade_to_auto_corrected(theme)
    res.should_not be_nil
    parsed = JSON.parse(res.not_nil!)
    parsed["source"].should eq("auto-corrected")
  end

  it "does not upgrade when source is not auto" do
    theme = {"bg" => "#ffffff", "text" => {"light" => "#000000", "dark" => "#000000"}, "source" => "manual"}.to_json
    ColorExtractor.auto_upgrade_to_auto_corrected(theme).should be_nil
  end
end
