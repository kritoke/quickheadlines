require "spec"
require "lexis-minhash"

describe LexisMinhash::Engine do
  describe "#compute_signature" do
    it "returns an array of the correct size" do
      doc = LexisMinhash::SimpleDocument.new("Hello World Today")
      signature = LexisMinhash::Engine.compute_signature(doc)
      signature.size.should eq(100)
    end

    it "returns zeros for empty string" do
      doc = LexisMinhash::SimpleDocument.new("")
      signature = LexisMinhash::Engine.compute_signature(doc)
      signature.should eq(Array(UInt32).new(100, 0_u32))
    end

    it "returns consistent signatures for the same text" do
      doc1 = LexisMinhash::SimpleDocument.new("Test Article Title News")
      doc2 = LexisMinhash::SimpleDocument.new("Test Article Title News")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig1.should eq(sig2)
    end

    it "returns different signatures for different texts" do
      doc1 = LexisMinhash::SimpleDocument.new("Technology company announces revolutionary new product update")
      doc2 = LexisMinhash::SimpleDocument.new("Government officials discuss new policy changes for citizens")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig1.should_not eq(sig2)
    end

    it "is case insensitive" do
      doc1 = LexisMinhash::SimpleDocument.new("Hello World Test")
      doc2 = LexisMinhash::SimpleDocument.new("hello world test")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig1.should eq(sig2)
    end
  end

  describe "#similarity" do
    it "returns 1.0 for identical signatures" do
      doc = LexisMinhash::SimpleDocument.new("Same Title News")
      sig = LexisMinhash::Engine.compute_signature(doc)
      LexisMinhash::Engine.similarity(sig, sig).should eq(1.0_f64)
    end

    it "returns low similarity for completely different signatures" do
      doc1 = LexisMinhash::SimpleDocument.new("AAAA BBBB CCCC DDDD EEEE FFFF")
      doc2 = LexisMinhash::SimpleDocument.new("1111 2222 3333 4444 5555 6666")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      similarity = LexisMinhash::Engine.similarity(sig1, sig2)
      similarity.should be < 0.5_f64
    end

    it "returns higher similarity for similar texts" do
      doc1 = LexisMinhash::SimpleDocument.new("Apple announces new iPhone 15 Pro")
      doc2 = LexisMinhash::SimpleDocument.new("Apple announces new iPhone 15 Pro Max")
      doc3 = LexisMinhash::SimpleDocument.new("Microsoft releases Windows 12")

      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig3 = LexisMinhash::Engine.compute_signature(doc3)

      similarity_same = LexisMinhash::Engine.similarity(sig1, sig2)
      similarity_diff = LexisMinhash::Engine.similarity(sig1, sig3)

      similarity_same.should be > similarity_diff
    end
  end

  describe "#generate_bands" do
    it "returns the correct number of bands" do
      doc = LexisMinhash::SimpleDocument.new("Test Document Here")
      signature = LexisMinhash::Engine.compute_signature(doc)
      bands = LexisMinhash::Engine.generate_bands(signature)
      bands.size.should eq(20)
    end

    it "returns unique band indices" do
      doc = LexisMinhash::SimpleDocument.new("Test Document For")
      signature = LexisMinhash::Engine.compute_signature(doc)
      bands = LexisMinhash::Engine.generate_bands(signature)
      band_indices = bands.map(&.[0])
      band_indices.uniq.size.should eq(band_indices.size)
    end

    it "returns UInt64 band hashes" do
      doc = LexisMinhash::SimpleDocument.new("Test Data Now")
      signature = LexisMinhash::Engine.compute_signature(doc)
      bands = LexisMinhash::Engine.generate_bands(signature)
      bands.each do |_band_index, band_hash|
        band_hash.should be_a(UInt64)
      end
    end
  end

  describe "#signature_to_bytes and #bytes_to_signature" do
    it "preserves signature data through conversion" do
      doc = LexisMinhash::SimpleDocument.new("Convert This Signature")
      original = LexisMinhash::Engine.compute_signature(doc)
      bytes = LexisMinhash::Engine.signature_to_bytes(original)
      restored = LexisMinhash::Engine.bytes_to_signature(bytes)
      original.should eq(restored)
    end

    it "handles empty signatures" do
      empty = Array(UInt32).new(100, 0_u32)
      bytes = LexisMinhash::Engine.signature_to_bytes(empty)
      restored = LexisMinhash::Engine.bytes_to_signature(bytes)
      empty.should eq(restored)
    end
  end
end
