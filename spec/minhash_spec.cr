require "./spec_helper"
require "../src/minhash"

describe StoryHasher do
  describe "compute_signature" do
    it "returns an array of the correct size" do
      signature = StoryHasher.compute_signature("Hello World")
      signature.size.should eq(StoryHasher::SIGNATURE_SIZE)
    end

    it "returns zeros for empty string" do
      signature = StoryHasher.compute_signature("")
      signature.should eq(Array(UInt32).new(StoryHasher::SIGNATURE_SIZE, 0_u32))
    end

    it "returns consistent signatures for the same text" do
      sig1 = StoryHasher.compute_signature("Test Article Title")
      sig2 = StoryHasher.compute_signature("Test Article Title")
      sig1.should eq(sig2)
    end

    it "returns different signatures for different texts" do
      sig1 = StoryHasher.compute_signature("First Article")
      sig2 = StoryHasher.compute_signature("Second Article")
      sig1.should_not eq(sig2)
    end

    it "is case insensitive" do
      sig1 = StoryHasher.compute_signature("Hello World")
      sig2 = StoryHasher.compute_signature("hello world")
      sig1.should eq(sig2)
    end
  end

  describe "similarity" do
    it "returns 1.0 for identical signatures" do
      sig = StoryHasher.compute_signature("Same Title")
      StoryHasher.similarity(sig, sig).should eq(1.0_f64)
    end

    it "returns 0.0 for completely different signatures" do
      sig1 = StoryHasher.compute_signature("AAAA")
      sig2 = StoryHasher.compute_signature("BBBB")
      similarity = StoryHasher.similarity(sig1, sig2)
      similarity.should be < 0.5_f64
    end

    it "returns higher similarity for similar texts" do
      sig1 = StoryHasher.compute_signature("Apple announces new iPhone 15 Pro")
      sig2 = StoryHasher.compute_signature("Apple announces new iPhone 15 Pro Max")
      sig3 = StoryHasher.compute_signature("Microsoft releases Windows 12")

      similarity_same = StoryHasher.similarity(sig1, sig2)
      similarity_diff = StoryHasher.similarity(sig1, sig3)

      similarity_same.should be > similarity_diff
    end
  end

  describe "generate_bands" do
    it "returns the correct number of bands" do
      signature = StoryHasher.compute_signature("Test")
      bands = StoryHasher.generate_bands(signature)
      bands.size.should eq(StoryHasher::NUM_BANDS)
    end

    it "returns unique band indices" do
      signature = StoryHasher.compute_signature("Test")
      bands = StoryHasher.generate_bands(signature)
      band_indices = bands.map(&.[0])
      band_indices.uniq.size.should eq(band_indices.size)
    end

    it "returns UInt64 band hashes" do
      signature = StoryHasher.compute_signature("Test")
      bands = StoryHasher.generate_bands(signature)
      bands.each do |_band_index, band_hash|
        band_hash.should be_a(UInt64)
      end
    end
  end

  describe "signature_to_bytes and bytes_to_signature" do
    it "preserves signature data through conversion" do
      original = StoryHasher.compute_signature("Convert This Signature")
      bytes = StoryHasher.signature_to_bytes(original)
      restored = StoryHasher.bytes_to_signature(bytes)
      original.should eq(restored)
    end

    it "handles empty signatures" do
      empty = Array(UInt32).new(StoryHasher::SIGNATURE_SIZE, 0_u32)
      bytes = StoryHasher.signature_to_bytes(empty)
      restored = StoryHasher.bytes_to_signature(bytes)
      empty.should eq(restored)
    end
  end

  describe "detection_probability" do
    it "returns 0.0 for 0 similarity" do
      StoryHasher.detection_probability(0.0_f64).should eq(0.0_f64)
    end

    it "returns 1.0 for 1.0 similarity" do
      prob = StoryHasher.detection_probability(1.0_f64)
      prob.should be_close(1.0_f64, 0.01_f64)
    end

    it "returns higher probability for higher similarity" do
      prob_low = StoryHasher.detection_probability(0.5_f64)
      prob_high = StoryHasher.detection_probability(0.9_f64)
      prob_high.should be > prob_low
    end
  end
end
