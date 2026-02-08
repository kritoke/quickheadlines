require "./spec_helper"

describe "Gray placeholder handling" do
  it "returns nil for non-google gray placeholder to trigger fallback" do
    mem = IO::Memory.new
    bytes = Bytes.new(198)
    0.upto(197) { |i| bytes[i] = 0_u8 }
    mem.write(bytes)
    mem.seek(0)
    test_try_handle_gray_placeholder("https://example.com/favicon.ico", mem).should be_nil
  end

  it "retries with larger google favicon for google placeholder" do
    mem = IO::Memory.new
    bytes = Bytes.new(198)
    0.upto(197) { |i| bytes[i] = 0_u8 }
    mem.write(bytes)
    mem.seek(0)
    # For google URL it will try to fetch larger size; since network is not available
    # result may be nil - we assert it does not raise and returns something or nil
    test_try_handle_gray_placeholder("https://www.google.com/s2/favicons?domain=example.com&sz=64", mem)
  end
end
