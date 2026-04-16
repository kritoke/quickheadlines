require "db"
require "../services/database_service"
require "./repository_base"

module QuickHeadlines::Repositories
  @[ADI::Register]
  class ClusterRepository < RepositoryBase
    def find_all(limit : Int32 = 1000) : Array(QuickHeadlines::Entities::Cluster)
      clusters = [] of QuickHeadlines::Entities::Cluster

      query = <<-SQL
        SELECT
          c.id as cluster_id,
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
        LIMIT ?
        SQL

      cluster_items = Hash(Int64, Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})).new

      db.query(query, limit) do |rows|
        rows.each do
          cluster_id = rows.read(Int64)
          item_id = rows.read(Int64)
          item_title = rows.read(String)
          item_link = rows.read(String)
          item_pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          item_pub_date = parse_db_time(item_pub_date_str)

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

        representative = QuickHeadlines::Entities::Story.new(
          id: rep_data[:id].to_s,
          title: rep_data[:title],
          link: rep_data[:link],
          pub_date: rep_data[:pub_date],
          feed_title: rep_data[:feed_title],
          feed_url: rep_data[:feed_url],
          feed_link: "",
            favicon: rep_data[:favicon],
            favicon_data: nil,
            header_color: rep_data[:header_color]
        )

        others = items[1..].map do |item|
          QuickHeadlines::Entities::Story.new(
            id: item[:id].to_s,
            title: item[:title],
            link: item[:link],
            pub_date: item[:pub_date],
            feed_title: item[:feed_title],
            feed_url: item[:feed_url],
            feed_link: "",
            favicon: item[:favicon],
            favicon_data: nil,
            header_color: item[:header_color]
          )
        end

        clusters << QuickHeadlines::Entities::Cluster.new(
          id: items.first[:id].to_s,
          representative: representative,
          others: others
        )
      end

      clusters
    end

    def clear_all_metadata : Nil
      db.exec("UPDATE items SET cluster_id = NULL")
      db.exec("DELETE FROM lsh_bands")
    end
  end
end
