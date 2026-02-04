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

    it "produces matching bands for similar content" do
      doc1 = LexisMinhash::SimpleDocument.new("Python 3.14 released with performance improvements")
      doc2 = LexisMinhash::SimpleDocument.new("Python 3.14 brings new performance enhancements")
      
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      
      bands1 = LexisMinhash::Engine.generate_bands(sig1)
      bands2 = LexisMinhash::Engine.generate_bands(sig2)
      
      # At least some bands should match for similar content
      matching_bands = bands1.each_index.count { |i| bands1[i] == bands2[i] }
      matching_bands.should be >= 1
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
      doc = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      sig1 = LexisMinhash::Engine.compute_signature(doc)
      sig2 = LexisMinhash::Engine.compute_signature(doc)
      LexisMinhash::Engine.similarity(sig1, sig2).should eq(1.0)
    end

    it "returns high similarity for similar documents" do
      doc1 = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      doc2 = LexisMinhash::SimpleDocument.new("Bitcoin price continues to surge")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      LexisMinhash::Engine.similarity(sig1, sig2).should be > 0.5
    end

    it "returns low similarity for different documents" do
      doc1 = LexisMinhash::SimpleDocument.new("Bitcoin price surge continues")
      doc2 = LexisMinhash::SimpleDocument.new("New Python release adds async features")
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      LexisMinhash::Engine.similarity(sig1, sig2).should be < 0.3
    end

    it "clusters same story from different sources" do
      # Simulating same story covered by different tech news sites
      story1 = "OpenAI releases GPT-5 with improved reasoning capabilities"
      story2 = "OpenAI announces GPT-5 with improved reasoning"
      story3 = "OpenAI GPT-5 brings improved reasoning capabilities"
      
      doc1 = LexisMinhash::SimpleDocument.new(story1)
      doc2 = LexisMinhash::SimpleDocument.new(story2)
      doc3 = LexisMinhash::SimpleDocument.new(story3)
      
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      sig3 = LexisMinhash::Engine.compute_signature(doc3)
      
      # All three variations should have moderate pairwise similarity
      LexisMinhash::Engine.similarity(sig1, sig2).should be > 0.4
      LexisMinhash::Engine.similarity(sig2, sig3).should be > 0.4
      LexisMinhash::Engine.similarity(sig1, sig3).should be > 0.3
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
      similarity.should be < 0.7
    end

    it "handles very different stories with near-zero similarity" do
      story1 = "SpaceX launches new Starlink satellites"
      story2 = "New dental study shows coffee prevents cavities"
      
      doc1 = LexisMinhash::SimpleDocument.new(story1)
      doc2 = LexisMinhash::SimpleDocument.new(story2)
      
      sig1 = LexisMinhash::Engine.compute_signature(doc1)
      sig2 = LexisMinhash::Engine.compute_signature(doc2)
      
      LexisMinhash::Engine.similarity(sig1, sig2).should be < 0.2
    end
  end
end

