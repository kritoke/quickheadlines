# MinHash and LSH (Locality-Sensitive Hashing) for story similarity detection
# Used to group duplicate or similar headlines from different news sources
require "digest/crc32"
require "set"

module StoryHasher
  # Number of hash functions in the MinHash signature
  SIGNATURE_SIZE = 100

  # Number of bands for LSH (bands * rows = signature_size)
  NUM_BANDS = 20

  # Rows per band (must evenly divide signature_size)
  ROWS_PER_BAND = SIGNATURE_SIZE // NUM_BANDS

  # Similarity threshold for clustering (0.0 to 1.0)
  SIMILARITY_THRESHOLD = 0.7

  # Hash seeds for generating multiple hash functions from a single hash function
  HASH_SEEDS = (0...SIGNATURE_SIZE).to_a

  # Compute MinHash signature for a text string
  # Uses multiple hash functions simulated with different seeds
  def self.compute_signature(text : String) : Array(UInt32)
    # Normalize text: lowercase and strip
    normalized = text.downcase.strip

    # Return empty array for empty text
    return Array(UInt32).new(SIGNATURE_SIZE, 0_u32) if normalized.empty?

    # Compute hash values using different seeds
    HASH_SEEDS.map do |seed|
      hash_value(normalized, seed)
    end
  end

  # Compute hash value with seed
  private def self.hash_value(text : String, seed : Int32) : UInt32
    # Combine text and seed into a single string
    combined = "#{text}#{seed}"

    # Use CRC32 for fast hashing (Crystal's built-in)
    crc = Digest::CRC32.update(combined.to_slice, 0_u32)
    crc
  end

  # Compute Jaccard similarity between two signatures
  # Jaccard similarity = |A ∩ B| / |A ∪ B|
  def self.similarity(sig1 : Array(UInt32), sig2 : Array(UInt32)) : Float64
    return 0.0_f64 if sig1.empty? || sig2.empty?

    # Count matching positions
    matches = 0
    sig1.each_with_index do |val, idx|
      matches += 1 if val == sig2[idx]?
    end

    matches.to_f64 / sig1.size.to_f64
  end

  # Generate LSH bands from a signature
  # Returns array of {band_index, band_hash} tuples
  def self.generate_bands(signature : Array(UInt32)) : Array({Int32, UInt64})
    bands = [] of {Int32, UInt64}

    NUM_BANDS.times do |band_index|
      start_idx = band_index * ROWS_PER_BAND
      end_idx = start_idx + ROWS_PER_BAND

      # Extract this band's hash values
      band_hashes = signature[start_idx...end_idx]

      # Combine into a single 64-bit hash
      band_hash = combine_hashes(band_hashes)

      bands << {band_index, band_hash}
    end

    bands
  end

  # Combine multiple hash values into a single UInt64
  private def self.combine_hashes(hashes : Array(UInt32)) : UInt64
    combined = 0_u64
    hashes.each do |hash_val|
      # Use XOR and shift to combine (simple but effective)
      combined = (combined << 7) ^ hash_val
    end
    combined
  end

  # Estimate probability of detecting similar items
  # Based on s (similarity), b (bands), r (rows per band)
  def self.detection_probability(similarity : Float64) : Float64
    # P = 1 - (1 - s^r)^b
    s_r = similarity ** ROWS_PER_BAND
    1.0_f64 - (1.0_f64 - s_r) ** NUM_BANDS
  end

  # Signature conversion for database storage (Array -> Bytes)
  def self.signature_to_bytes(signature : Array(UInt32)) : Bytes
    bytes = Bytes.new(signature.size * sizeof(UInt32))
    signature.each_with_index do |val, idx|
      bytes[idx * sizeof(UInt32) + 0] = (val & 0xFF).to_u8
      bytes[idx * sizeof(UInt32) + 1] = ((val >> 8) & 0xFF).to_u8
      bytes[idx * sizeof(UInt32) + 2] = ((val >> 16) & 0xFF).to_u8
      bytes[idx * sizeof(UInt32) + 3] = ((val >> 24) & 0xFF).to_u8
    end
    bytes
  end

  # Signature conversion for database storage (Bytes -> Array)
  def self.bytes_to_signature(bytes : Bytes) : Array(UInt32)
    return Array(UInt32).new if bytes.empty?

    signature = [] of UInt32
    (bytes.size // sizeof(UInt32)).times do |idx|
      val = bytes[idx * sizeof(UInt32) + 0].to_u32 |
            (bytes[idx * sizeof(UInt32) + 1].to_u32 << 8) |
            (bytes[idx * sizeof(UInt32) + 2].to_u32 << 16) |
            (bytes[idx * sizeof(UInt32) + 3].to_u32 << 24)
      signature << val
    end
    signature
  end
end
