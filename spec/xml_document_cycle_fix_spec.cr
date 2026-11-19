require "spec"
require "../src/xml_document_cycle_fix"

describe "XML::Document cycle fix" do
  it "does not store a raw self pointer in the libxml doc" do
    doc = XML.parse("<rss><item><title>x</title></item></rss>")
    raw = doc.to_unsafe.as(LibXML::Doc*).value._private
    raw.should_not eq(doc.as(Void*))
  end

  it "resolves the same wrapper from nodes and raw pointers" do
    doc = XML.parse("<rss><item><title>x</title></item></rss>")
    doc.xpath_nodes("//title").first.document.should be(doc)
    XML::Document.new(doc.to_unsafe.as(LibXML::Doc*)).should be(doc)
  end

  it "works for HTML documents and repeated parsing" do
    200.times do
      html = XML.parse_html("<html><body><p>hi</p></body></html>")
      html.xpath_string("string(//p)").should eq("hi")
    end
    GC.collect
  end
end
