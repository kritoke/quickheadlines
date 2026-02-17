require "./spec_helper"
require "lexis-minhash"

describe ClusteringUtilities do
  describe "#normalize_headline" do
    it "removes stop words" do
      ClusteringUtilities.normalize_headline("The Bitcoin price says experts are worried")
        .should eq("bitcoin price experts worried")
    end

    it "handles empty string" do
      ClusteringUtilities.normalize_headline("").should eq("")
    end

    it "converts to lowercase" do
      ClusteringUtilities.normalize_headline("BITCOIN PRICE SURGE").should eq("bitcoin price surge")
    end
  end

  describe "#word_count" do
    it "counts words after normalization" do
      ClusteringUtilities.word_count("The Bitcoin price is surging").should eq(3)
    end

    it "returns 0 for empty string" do
      ClusteringUtilities.word_count("").should eq(0)
    end

    it "counts only non-stop words" do
      ClusteringUtilities.word_count("The and for of Bitcoin").should eq(1)
    end
  end
end

describe LexisMinhash::Engine do
  describe "#compute_signature" do
    it "returns 100-element signature" do
      doc = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      sig = LexisMinhash::Engine.compute_signature(doc)
      sig.size.should eq(100)
    end

    it "handles short headlines with filtering" do
      doc = LexisMinhash::SimpleDocument.new("Short")
      sig = LexisMinhash::Engine.compute_signature(doc)
      sig.should eq(Array(UInt32).new(100, 0_u32))
    end
  end

  describe "#generate_bands" do
    it "generates 20 bands from signature" do
      doc = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      sig = LexisMinhash::Engine.compute_signature(doc)
      bands = LexisMinhash::Engine.generate_bands(sig)
      bands.size.should eq(20)
    end

    it "produces consistent bands for same content" do
      doc = LexisMinhash::SimpleDocument.new("Machine learning advances continue")
      sig = LexisMinhash::Engine.compute_signature(doc)
      bands1 = LexisMinhash::Engine.generate_bands(sig)
      bands2 = LexisMinhash::Engine.generate_bands(sig)

      bands1.should eq(bands2)
    end

    it "produces higher similarity for similar content than different" do
      doc1 = LexisMinhash::SimpleDocument.new("Python 3.14 released with performance improvements")
      doc2 = LexisMinhash::SimpleDocument.new("Python 3.14 brings new performance enhancements")
      doc3 = LexisMinhash::SimpleDocument.new("Weather forecast shows rain tomorrow")

      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig3 = LexisMinhash::Engine.compute_signature(doc3)

      sim_similar = LexisMinhash::Engine.similarity(sig1, sig2)
      sim_different = LexisMinhash::Engine.similarity(sig1, sig3)

      sim_similar.should be > sim_different
    end

    it "produces fewer matching bands for different content" do
      doc1 = LexisMinhash::SimpleDocument.new("Bitcoin hits new all-time high")
      doc2 = LexisMinhash::SimpleDocument.new("New Rust book released for beginners")

      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)

      bands1 = LexisMinhash::Engine.generate_bands(sig1)
      bands2 = LexisMinhash::Engine.generate_bands(sig2)

      matching_bands = bands1.each_index.count { |i| bands1[i] == bands2[i] }
      matching_bands.should be <= 2
    end
  end

  describe "#similarity" do
    it "returns 1.0 for identical documents" do
      doc = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues today")
      sig1 = LexisMinhash::Engine.compute_signature(doc)
      sig2 = LexisMinhash::Engine.compute_signature(doc)
      LexisMinhash::Engine.similarity(sig1, sig2).should eq(1.0)
    end

    it "returns high similarity for similar documents" do
      doc1 = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      doc2 = LexisMinhash::SimpleDocument.new("Bitcoin price continues to surge")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      LexisMinhash::Engine.similarity(sig1, sig2).should be > 0.3
    end

    it "returns low similarity for different documents" do
      doc1 = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      doc2 = LexisMinhash::SimpleDocument.new("New Python release adds async features")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      LexisMinhash::Engine.similarity(sig1, sig2).should be < 0.5
    end

    it "clusters same story from different sources (relative comparison)" do
      # Simulating same story covered by different tech news sites
      story1 = "OpenAI releases GPT-5 with improved reasoning capabilities"
      story2 = "OpenAI announces GPT-5 with improved reasoning"
      story3 = "OpenAI GPT-5 brings improved reasoning capabilities"
      # Known different story
      story4 = "Local weather forecast predicts rain for weekend"

      doc1 = LexisMinhash::SimpleDocument.new(story1)
      doc2 = LexisMinhash::SimpleDocument.new(story2)
      doc3 = LexisMinhash::SimpleDocument.new(story3)
      doc4 = LexisMinhash::SimpleDocument.new(story4)

      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig3 = LexisMinhash::Engine.compute_signature(doc3)
      sig4 = LexisMinhash::Engine.compute_signature(doc4)

      # Similar stories should have higher similarity than different stories
      sim_similar_12 = LexisMinhash::Engine.similarity(sig1, sig2)
      sim_similar_23 = LexisMinhash::Engine.similarity(sig2, sig3)
      sim_different = LexisMinhash::Engine.similarity(sig1, sig4)

      sim_similar_12.should be > sim_different
      sim_similar_23.should be > sim_different
    end

    it "distinguishes similar topics from same story" do
      # Same topic (AI) but different stories
      story1 = "OpenAI releases GPT-5 with improved reasoning"
      story2 = "Anthropic releases Claude 4 with better safety"

      doc1 = LexisMinhash::SimpleDocument.new(story1)
      doc2 = LexisMinhash::SimpleDocument.new(story2)

      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)

      # Should have some similarity (both about AI) but not too high
      similarity = LexisMinhash::Engine.similarity(sig1, sig2)
      similarity.should be < 0.8
    end

    it "handles very different stories (relative comparison)" do
      # Very different topics
      story1 = "SpaceX launches new Starlink satellites"
      story2 = "New dental study shows coffee prevents cavities"
      # Similar to story1 for comparison
      story3 = "SpaceX launches additional Starlink satellites into orbit"

      doc1 = LexisMinhash::SimpleDocument.new(story1)
      doc2 = LexisMinhash::SimpleDocument.new(story2)
      doc3 = LexisMinhash::SimpleDocument.new(story3)

      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig3 = LexisMinhash::Engine.compute_signature(doc3)

      sim_different = LexisMinhash::Engine.similarity(sig1, sig2)
      sim_similar = LexisMinhash::Engine.similarity(sig1, sig3)

      sim_different.should be < sim_similar
    end
  end
end
