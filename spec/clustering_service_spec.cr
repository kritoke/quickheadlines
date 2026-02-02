require "./spec_helper"

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

  describe "#jaccard_similarity" do
    it "returns 1.0 for identical headlines" do
      ClusteringUtilities.jaccard_similarity("Bitcoin price surge continues", "Bitcoin price surge continues")
        .should eq(1.0)
    end

    it "returns high similarity for very similar headlines" do
      similarity = ClusteringUtilities.jaccard_similarity(
        "Bitcoin price surge continues amid market optimism",
        "Bitcoin price surge continues as market watches closely"
      )
      # "price" is a stop word, so both headlines share: bitcoin, surge, continues
      similarity.should be > 0.5
    end

    it "returns low similarity for different headlines" do
      similarity = ClusteringUtilities.jaccard_similarity(
        "Bitcoin price surge continues",
        "Weather forecast calls for rain tomorrow"
      )
      similarity.should be < 0.3
    end

    it "filters stop words in comparison" do
      sim_with_stop = ClusteringUtilities.jaccard_similarity(
        "The Bitcoin price is surging today",
        "Bitcoin price surging today according to reports"
      )
      sim_with_stop.should be > 0.5
    end
  end

  describe "#word_count" do
    it "counts words after normalization" do
      # "The" and "is" are stop words, leaving "Bitcoin", "price", "surging"
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
