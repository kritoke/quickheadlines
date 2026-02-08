require "./spec_helper"

describe "ColorExtractor helpers" do
  it "converts rgb array to hex" do
    ColorExtractor.rgb_to_hex_public([255, 0, 0]).should eq("#ff0000")
  end

  it "samples pixels from a small canvas buffer" do
    # Create a 2x2 RGBA buffer (red, green, blue, white)
    width = 2
    height = 2
    pixels = [] of UInt8
    # pixel 0: red
    pixels.concat([255_u8, 0_u8, 0_u8, 255_u8])
    # pixel 1: green
    pixels.concat([0_u8, 255_u8, 0_u8, 255_u8])
    # pixel 2: blue
    pixels.concat([0_u8, 0_u8, 255_u8, 255_u8])
    # pixel 3: white
    pixels.concat([255_u8, 255_u8, 255_u8, 255_u8])

    # Use public wrapper via RGB conversion through a temporary StumpyPNG canvas is heavy in tests,
    # instead call the private method via `send` pattern (Crystal doesn't have send; test uses public API)
    # We can instead call the public compute by writing a tiny PNG to disk — but that's heavy.
    # As a pragmatic alternative, test the private logic by constructing the expected average directly
    avg = ColorExtractor.test_calculate_dominant_color_from_buffer(pixels, width, height)
    avg.should_not be_nil
    # Expect average around (127,127,127) for these pixels
    (120..135).includes?(avg[0]).should be_true
    (120..135).includes?(avg[1]).should be_true
    (120..135).includes?(avg[2]).should be_true
    avg.should be_a(Array(Int32))
    # Expect average around (127,127,127) for these pixels
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
