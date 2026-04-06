require "./spec_helper"

describe "ColorExtractor helpers" do
  it "converts rgb array to hex" do
    ColorExtractor.rgb_to_hex([255, 0, 0]).should eq("#ff0000")
  end

  it "samples pixels from a small canvas buffer" do
    width = 2
    height = 2
    pixels = [] of UInt8
    pixels.concat([255_u8, 0_u8, 0_u8, 255_u8])
    pixels.concat([0_u8, 255_u8, 0_u8, 255_u8])
    pixels.concat([0_u8, 0_u8, 255_u8, 255_u8])
    pixels.concat([255_u8, 255_u8, 255_u8, 255_u8])

    avg = ColorExtractor.test_calculate_dominant_color_from_buffer(pixels, width, height)
    avg.should_not be_nil
    avg.should be_a(Array(Int32))
    avg.size.should eq(3)
    avg[0].should be >= 0
    avg[0].should be <= 255
    avg[1].should be >= 0
    avg[1].should be <= 255
    avg[2].should be >= 0
    avg[2].should be <= 255
  end

  it "finds readable foreground for a light background" do
    rgb = [250, 250, 250]
    t = ColorExtractor.suggest_foreground_for_bg(rgb)
    t.should be_a(String)
    t.should start_with("#")
  end

  it "upgrades auto theme when both roles meet contrast" do
    theme = {"bg" => "#ffffff", "text" => {"light" => "#000000", "dark" => "#000000"}, "source" => "auto"}.to_json
    res = ColorExtractor.upgrade_theme_json(theme)
    res.should_not be_nil
    parsed = JSON.parse(res.as(String))
    parsed["source"].should eq("auto-corrected")
  end

  it "does not upgrade when source is not auto" do
    theme = {"bg" => "#ffffff", "text" => {"light" => "#000000", "dark" => "#000000"}, "source" => "manual"}.to_json
    ColorExtractor.upgrade_theme_json(theme).should be_nil
  end
end
