require "db"

module Quickheadlines::Repositories
  class ClusterRepository
    @db : DB::Database

    def initialize(@db : DB::Database)
    end

    def find_all : Array(Quickheadlines::Entities::Cluster)
      clusters = [] of Quickheadlines::Entities::Cluster

      query = <<-SQL
        SELECT
          c.id as cluster_id,
          c.representative_id,
          i.id as item_id,
          i.title as item_title,
          i.link as item_link,
          i.pub_date as item_pub_date,
          f.url as feed_url,
          f.title as feed_title,
          f.favicon,
          f.header_color
        FROM (
          SELECT cluster_id as id, MIN(id) as representative_id
          FROM items
          WHERE cluster_id IS NOT NULL
          GROUP BY cluster_id
        ) c
        JOIN items i ON i.cluster_id = c.id
        JOIN feeds f ON i.feed_id = f.id
        ORDER BY c.id, i.id ASC
        SQL

      cluster_items = Hash(Int64, Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})).new

      @db.query(query) do |rows|
        rows.each do
          cluster_id = rows.read(Int64)
          _representative_id = rows.read(Int64)
          item_id = rows.read(Int64)
          item_title = rows.read(String)
          item_link = rows.read(String)
          item_pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          item_pub_date = item_pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          cluster_items[cluster_id] ||= [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}
          cluster_items[cluster_id] << {
            id:           item_id,
            title:        item_title,
            link:         item_link,
            pub_date:     item_pub_date,
            feed_url:     feed_url,
            feed_title:   feed_title,
            favicon:      favicon,
            header_color: header_color,
          }
        end
      end

      cluster_items.each do |_cluster_id, items|
        next if items.empty?

        rep_data = items.first

        representative = Quickheadlines::Entities::Story.new(
          id: rep_data[:id].to_s,
          title: rep_data[:title],
          link: rep_data[:link],
          pub_date: rep_data[:pub_date],
          feed_title: rep_data[:feed_title],
          feed_url: rep_data[:feed_url],
          feed_link: "",
          favicon: rep_data[:favicon],
          favicon_data: rep_data[:favicon],
          header_color: rep_data[:header_color]
        )

        others = items[1..].map do |item|
          Quickheadlines::Entities::Story.new(
            id: item[:id].to_s,
            title: item[:title],
            link: item[:link],
            pub_date: item[:pub_date],
            feed_title: item[:feed_title],
            feed_url: item[:feed_url],
            feed_link: "",
            favicon: item[:favicon],
            favicon_data: item[:favicon],
            header_color: item[:header_color]
          )
        end

        clusters << Quickheadlines::Entities::Cluster.new(
          id: items.first[:id].to_s,
          representative: representative,
          others: others,
          size: items.size
        )
      end

      clusters
    end

    def find_items(cluster_id : Int64) : Array(Quickheadlines::Entities::Story)
      stories = [] of Quickheadlines::Entities::Story

      @db.query(
        "SELECT i.id, i.title, i.link, i.pub_date, f.title as feed_title, f.url as feed_url, f.site_link as feed_link, f.favicon, f.header_color
         FROM items i
         JOIN feeds f ON i.feed_id = f.id
         WHERE i.cluster_id = ?
         ORDER BY i.id ASC",
        cluster_id
      ) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_title = rows.read(String)
          feed_url = rows.read(String)
          feed_link = rows.read(String?)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          stories << Quickheadlines::Entities::Story.new(
            id: id.to_s,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_title: feed_title,
            feed_url: feed_url,
            feed_link: feed_link || "",
            favicon: favicon,
            favicon_data: favicon,
            header_color: header_color
          )
        end
      end

      stories
    end

    def assign_cluster(item_id : Int64, cluster_id : Int64?) : Void
      @db.exec(
        "UPDATE items SET cluster_id = ? WHERE id = ?",
        cluster_id,
        item_id
      )
    end

    def clear_all_metadata : Void
      @db.exec("UPDATE items SET cluster_id = NULL")
      @db.exec("DELETE FROM lsh_bands")
    end
  end
end
