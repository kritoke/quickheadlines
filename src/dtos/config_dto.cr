class QuickHeadlines::DTOs::ConfigResponse
  include JSON::Serializable

  property refresh_minutes : Int32
  property item_limit : Int32
  property debug : Bool

  def initialize(@refresh_minutes : Int32, @item_limit : Int32, @debug : Bool)
  end
end
