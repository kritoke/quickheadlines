require "./spec_helper"

describe "ColorExtractor selection" do
  it "uses an existing readable candidate when present" do
    theme = {"bg" => "#000000", "text" => {"primary" => "#ffffff"}}.to_json
    res = ColorExtractor.auto_correct_theme_json(theme, nil, nil)
    res.should_not be_nil
    parsed = JSON.parse(res.as(String))
    parsed["text"].is_a?(JSON::Any).should be_true
    parsed["text"]["light"].to_s.should eq("#ffffff")
    parsed["source"].to_s.should eq("auto")
  end

  it "generates an auto-corrected color when no candidate meets contrast" do
    theme = {"bg" => "#808080", "text" => {"primary" => "#808080"}}.to_json
    res = ColorExtractor.auto_correct_theme_json(theme, nil, nil)
    res.should_not be_nil
    parsed = JSON.parse(res.as(String))
    parsed["source"].should eq("auto-corrected")
  end
end
