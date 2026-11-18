require "./spec_helper"
require "../src/services/rss_reader"

describe RssReader do
  it "reports real RSS (not the GC-heap fallback) on supported platforms" do
    mb, source = RssReader.read_uncached
    mb.should be > 0.0
    {% if flag?(:linux) %}
      source.should eq("proc")
    {% elsif flag?(:freebsd) %}
      source.should eq("ps")
    {% end %}
  end

  it "parses ps output" do
    {% if flag?(:linux) || flag?(:freebsd) %}
      if mb = RssReader.read_ps
        mb.should be > 0.0
      end
    {% end %}
  end

  it "caches readings" do
    RssReader.read.should eq(RssReader.read)
  end
end
