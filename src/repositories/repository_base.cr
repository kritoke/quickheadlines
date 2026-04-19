require "db"
require "../services/database_service"

module QuickHeadlines::Repositories
  abstract class RepositoryBase
    getter db : DB::Database

    def initialize(db_service : DatabaseService)
      @db = db_service.db
    end

    private def parse_db_time(str : String?) : Time?
      self.class.parse_db_time(str)
    end

    def self.parse_db_time(str : String?) : Time?
      str.try { |time_str| Time.parse(time_str, QuickHeadlines::Constants::DB_TIME_FORMAT, Time::Location::UTC) }
    rescue Time::Format::Error
      nil
    end

    def self.placeholders(count : Int) : String
      Array.new(count, "?").join(",")
    end
  end
end
