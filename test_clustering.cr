require "athena"
require "lexis-minhash"
require "db"
require "sqlite3"

module ClusteringUtilities
  STOP_WORDS = Set.new([
    "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
    "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
    "be", "have", "has", "had", "do", "does", "did", "will", "would",
    "could", "should", "may", "might", "must", "shall", "can", "need",
    "this", "that", "these", "those", "it", "its", "they", "them",
    "time", "times", "day", "days", "week", "weeks", "month", "months",
    "year", "years", "new", "latest", "update", "updates", "report", "reports",
    "says", "said", "just", "now", "how", "what", "when", "where", "why",
  ])

  SHORT_HEADLINE_THRESHOLD = 0.85
  MIN_WORDS_FOR_CLUSTERING =    4

  def self.normalize_headline(text : String) : String
    return "" if text.empty?
    normalized = text.downcase.strip
    words = normalized.split(/\s+/)
    filtered = words.reject { |word| STOP_WORDS.includes?(word) }
    filtered.join(" ")
  end

  def self.jaccard_similarity(text1 : String, text2 : String) : Float64
    norm1 = normalize_headline(text1)
    norm2 = normalize_headline(text2)

    words1 = Set.new(norm1.split(/\s+/))
    words2 = Set.new(norm2.split(/\s+/))

    intersection = words1 & words2
    union = words1 | words2

    return 0.0_f64 if union.empty?
    intersection.size.to_f64 / union.size.to_f64
  end

  def self.word_count(text : String) : Int32
    normalized = normalize_headline(text)
    return 0 if normalized.empty?
    normalized.split(/\s+/).size
  end
end

h1 = "The Mayflies at 3 AM"
h2 = "roberto bot"

puts "Headline 1: #{h1}"
puts "Headline 2: #{h2}"
puts "Normalized 1: '#{ClusteringUtilities.normalize_headline(h1)}'"
puts "Normalized 2: '#{ClusteringUtilities.normalize_headline(h2)}'"
puts "Jaccard Similarity: #{ClusteringUtilities.jaccard_similarity(h1, h2)}"
puts "Word Count 1: #{ClusteringUtilities.word_count(h1)}"
puts "Word Count 2: #{ClusteringUtilities.word_count(h2)}"

puts "\nTesting LSH Signatures:"
doc1 = LexisMinhash::SimpleDocument.new("The Mayflies at 3 AM")
doc2 = LexisMinhash::SimpleDocument.new("roberto bot")
sig1 = LexisMinhash::Engine.compute_signature(doc1)
sig2 = LexisMinhash::Engine.compute_signature(doc2)
puts "LSH Similarity: #{LexisMinhash::Engine.similarity(sig1, sig2)}"

bands1 = LexisMinhash::Engine.generate_bands(sig1)
bands2 = LexisMinhash::Engine.generate_bands(sig2)
shared = bands1.to_set & bands2.to_set
puts "Shared Bands: #{shared.size}"
