require "./spec_helper"

describe "Favicon magic bytes" do
  it "detects PNG magic" do
    data = Bytes[0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A] + Bytes[0x00]
    test_png_magic?(data).should be_true
  end

  it "detects JPEG magic" do
    data = Bytes[0xFF,0xD8,0xFF,0x00]
    test_jpeg_magic?(data).should be_true
  end

  it "detects ICO magic" do
    data = Bytes[0x00,0x00,0x01,0x00]
    test_ico_magic?(data).should be_true
  end

  it "detects SVG magic (<?xml)" do
    data = Bytes[0x3C,0x3F,0x78,0x6D,0x6C]
    test_svg_magic?(data).should be_true
  end

  it "detects WEBP magic" do
    data = Bytes[0x52,0x49,0x46,0x46,0x00,0x00,0x00,0x00,0x57,0x45,0x42,0x50]
    test_webp_magic?(data).should be_true
  end
end
