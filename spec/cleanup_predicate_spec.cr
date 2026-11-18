require "./spec_helper"

private def insert_item(db : DB::Database, feed_id : Int64, link : String, pub_date : Time, cluster_id : Int64? = nil) : Int64
  db.exec("INSERT INTO items (feed_id, title, link, normalized_link, pub_date) VALUES (?, ?, ?, ?, ?)",
    feed_id, "t #{link}", link, link, pub_date.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT))
  id = db.scalar("SELECT MAX(id) FROM items").as(Int64)
  db.exec("UPDATE items SET cluster_id = ? WHERE id = ?", cluster_id, id) if cluster_id
  id
end

private def ids(db : DB::Database) : Array(Int64)
  db.query_all("SELECT id FROM items ORDER BY id", as: Int64)
end

describe "CleanupStore#cleanup_old_articles" do
  it "deletes old members, keeps a rep while it has members, then deletes it" do
    cache = create_test_feed_cache
    db = cache.db
    db.exec("INSERT INTO feeds (url, title, last_fetched) VALUES ('http://f.test/rss', 'F', ?)", Time.utc.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT))
    feed_id = db.scalar("SELECT id FROM feeds").as(Int64)
    old = Time.utc - 30.days
    recent = Time.utc - 1.hour

    lone_old = insert_item(db, feed_id, "a", old)
    rep_old = insert_item(db, feed_id, "rep", old)
    db.exec("UPDATE items SET cluster_id = id WHERE id = ?", rep_old)
    member_old = insert_item(db, feed_id, "m-old", old, rep_old)
    member_new = insert_item(db, feed_id, "m-new", recent, rep_old)
    fresh = insert_item(db, feed_id, "fresh", recent)

    cache.cleanup_store.cleanup_old_articles(7)
    remaining = ids(db)
    remaining.should_not contain(lone_old)
    remaining.should_not contain(member_old)
    remaining.should contain(rep_old) # still referenced by member_new
    remaining.should contain(member_new)
    remaining.should contain(fresh)

    # Once the last member goes, the old rep is removed on the next run.
    db.exec("DELETE FROM items WHERE id = ?", member_new)
    cache.cleanup_store.cleanup_old_articles(7)
    ids(db).should_not contain(rep_old)
  end
end
