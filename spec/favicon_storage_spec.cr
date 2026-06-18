require "spec"
require "../src/favicon_storage"

# Black-box tests for FaviconActor's pure helpers. These cover the ICO
# favicon regression where Variety/Deadline 16x16 ICOs (~318-1500 bytes)
# were mis-classified as "tiny placeholders", triggering a Google fallback
# that returned a smaller stub PNG and overwrote the real favicon.
#
# The public API under test:
#   - FaviconActor.valid_image_data?(data)
#   - FaviconActor.parse_ico_info(data)
#   - FaviconActor.needs_fallback?(data, ext)
#
# These helpers are intentionally pure (no actor state, no I/O) so they
# can be exercised directly without bootstrapping the full app.
describe "FaviconActor pure helpers" do
  describe ".valid_image_data?" do
    it "rejects data smaller than 4 bytes" do
      FaviconActor.valid_image_data?(Bytes.new(3)).should be_false
      FaviconActor.valid_image_data?(Bytes.new(0)).should be_false
    end

    it "accepts a valid PNG signature" do
      # PNG signature: 89 50 4E 47 0D 0A 1A 0A
      png_sig = Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]
      FaviconActor.valid_image_data?(png_sig).should be_true
    end

    it "accepts a valid JPEG signature" do
      jpeg_sig = Bytes[0xFF, 0xD8, 0xFF, 0xE0, 0x00]
      FaviconActor.valid_image_data?(jpeg_sig).should be_true
    end

    it "accepts a valid ICO signature (type 1)" do
      ico_sig = Bytes[0x00, 0x00, 0x01, 0x00, 0x01, 0x00] + Bytes.new(16)
      FaviconActor.valid_image_data?(ico_sig).should be_true
    end

    it "rejects garbage bytes" do
      garbage = Bytes[0x47, 0x49, 0x46, 0x38] # "GIF8" but truncated
      FaviconActor.valid_image_data?(garbage).should be_false
    end
  end

  describe ".parse_ico_info" do
    it "returns nil for non-ICO data" do
      FaviconActor.parse_ico_info(Bytes[0x89, 0x50, 0x4E, 0x47]).should be_nil
    end

    it "returns nil for an ICO with reserved bytes set" do
      bad = Bytes[0xFF, 0xFF, 0x01, 0x00, 0x01, 0x00] + Bytes.new(16)
      FaviconActor.parse_ico_info(bad).should be_nil
    end

    it "returns nil for an ICO with zero frames" do
      bad = Bytes[0x00, 0x00, 0x01, 0x00, 0x00, 0x00] + Bytes.new(16)
      FaviconActor.parse_ico_info(bad).should be_nil
    end

    it "returns nil when there is no directory entry" do
      too_short = Bytes[0x00, 0x00, 0x01, 0x00, 0x01, 0x00]
      FaviconActor.parse_ico_info(too_short).should be_nil
    end

    it "parses a single-frame 16x16 ICO" do
      # 6-byte header + 16-byte directory entry: width=16, height=16
      ico = Bytes[
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00,            # header: 1 frame
        0x10, 0x10, 0x00, 0x00,                          # 16x16, 0 colors, reserved
        0x01, 0x00, 0x20, 0x00,                          # 1 color plane, 32bpp
        0x00, 0x10, 0x00, 0x00,                          # image size (4096 bytes)
        0x16, 0x00, 0x00, 0x00,                          # offset in file (22)
      ]
      info = FaviconActor.parse_ico_info(ico)
      info.should_not be_nil
      info.not_nil![0].should eq(1)  # frame count
      info.not_nil![1].should eq(16) # largest dimension
    end

    it "parses a multi-frame ICO and reports the largest dimension" do
      # Header: 2 frames
      # Entry 1: 16x16 (16 bytes)
      # Entry 2: 32x32 (16 bytes)
      ico = Bytes[
        0x00, 0x00, 0x01, 0x00, 0x02, 0x00,
        0x10, 0x10, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00, 0x10, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, # pad entry 1 to 16 bytes
        0x20, 0x20, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00, 0x20, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, # pad entry 2 to 16 bytes
      ]
      info = FaviconActor.parse_ico_info(ico)
      info.should_not be_nil
      info.not_nil![0].should eq(2)
      info.not_nil![1].should eq(32)
    end

    it "treats width/height byte 0x00 as 256" do
      # Width=0 means 256 (per ICO spec)
      ico = Bytes[
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00, 0x10, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, # pad entry to 16 bytes
      ]
      info = FaviconActor.parse_ico_info(ico)
      info.should_not be_nil
      info.not_nil![1].should eq(256)
    end
  end

  describe ".needs_fallback?" do
    it "is true for any image under the absolute minimum" do
      FaviconActor.needs_fallback?(Bytes.new(50), "ico").should be_true
      FaviconActor.needs_fallback?(Bytes.new(50), "png").should be_true
    end

    it "is true for an ICO with an invalid header (corrupt)" do
      # Not a valid ICO signature
      bad_ico = Bytes[0x89, 0x50, 0x4E, 0x47] + Bytes.new(200)
      FaviconActor.needs_fallback?(bad_ico, "ico").should be_true
    end

    it "is false for a real small ICO (the Variety/Deadline regression)" do
      # Real 16x16 single-frame ICO. ~318 bytes is typical.
      header = Bytes[
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x10, 0x10, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00, 0x10, 0x00, 0x00,
      ]
      # Pad to ~318 bytes total — a realistic single-frame 16x16 ICO size
      real_ico = header + Bytes.new(300)
      FaviconActor.needs_fallback?(real_ico, "ico").should be_false
    end

    it "is false for a real 1500-byte ICO (deadline-style favicon)" do
      header = Bytes[
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x10, 0x10, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00, 0x10, 0x00, 0x00,
      ]
      real_ico = header + Bytes.new(1500)
      FaviconActor.needs_fallback?(real_ico, "ico").should be_false
    end

    it "is false for a normal PNG above the absolute minimum" do
      png = Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + Bytes.new(500)
      FaviconActor.needs_fallback?(png, "png").should be_false
    end

    it "is false for a normal SVG above the absolute minimum" do
      svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>".to_slice + Bytes.new(200)
      FaviconActor.needs_fallback?(svg, "svg").should be_false
    end

    it "is false for ICOs with multiple frames" do
      header = Bytes[0x00, 0x00, 0x01, 0x00, 0x03, 0x00]
      entries = Bytes.new(48) # 3 * 16-byte entries
      multi = header + entries + Bytes.new(400)
      FaviconActor.needs_fallback?(multi, "ico").should be_false
    end
  end
end
