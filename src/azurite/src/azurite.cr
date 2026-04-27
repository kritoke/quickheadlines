require "./azurite_constants"
require "./azurite_store"
require "./models/article_content"

module Azurite
  VERSION = "0.1.0"

  def self.create_store(db_path : String) : AzuriteStore
    AzuriteStore.new(db_path)
  end
end