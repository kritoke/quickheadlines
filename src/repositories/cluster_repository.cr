require "db"
require "../services/database_service"
require "./repository_base"

module QuickHeadlines::Repositories
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
          f.site_link as feed_link,
          f.favicon,
          f.favicon_data,
          f.header_color,
          f.header_text_color,
          i.comment_url,
          i.commentary_url
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

      cluster_items = Hash(Int64, Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, feed_link: String, favicon: String?, favicon_data: String?, header_color: String?, header_text_color: String?, comment_url: String?, commentary_url: String?})).new

      db.query(query, limit) do |rows|
        rows.each do
          cluster_id = rows.read(Int64)
          item_id = rows.read(Int64)
          item_title = rows.read(String)
          item_link = rows.read(String)
          item_pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          feed_link = rows.read(String?) || ""
          favicon = rows.read(String?)
          favicon_data = rows.read(String?)
          header_color = rows.read(String?)
          header_text_color = rows.read(String?)
          comment_url = rows.read(String?)
          commentary_url = rows.read(String?)

          item_pub_date = parse_db_time(item_pub_date_str)

          cluster_items[cluster_id] ||= [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, feed_link: String, favicon: String?, favicon_data: String?, header_color: String?, header_text_color: String?, comment_url: String?, commentary_url: String?}
          cluster_items[cluster_id] << {
            id:                item_id,
            title:             item_title,
            link:              item_link,
            pub_date:          item_pub_date,
            feed_url:          feed_url,
            feed_title:        feed_title,
            feed_link:         feed_link,
            favicon:           favicon,
            favicon_data:      favicon_data,
            header_color:      header_color,
            header_text_color: header_text_color,
            comment_url:       comment_url,
            commentary_url:    commentary_url,
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
          feed_link: rep_data[:feed_link],
          favicon: rep_data[:favicon],
          favicon_data: rep_data[:favicon_data],
          header_color: rep_data[:header_color],
          header_text_color: rep_data[:header_text_color],
          comment_url: rep_data[:comment_url],
          commentary_url: rep_data[:commentary_url],
        )

        others = items[1..].map do |item|
          QuickHeadlines::Entities::Story.new(
            id: item[:id].to_s,
            title: item[:title],
            link: item[:link],
            pub_date: item[:pub_date],
            feed_title: item[:feed_title],
            feed_url: item[:feed_url],
            feed_link: item[:feed_link],
            favicon: item[:favicon],
            favicon_data: item[:favicon_data],
            header_color: item[:header_color],
            header_text_color: item[:header_text_color],
            comment_url: item[:comment_url],
            commentary_url: item[:commentary_url],
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
