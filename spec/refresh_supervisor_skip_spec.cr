require "./spec_helper"
require "../src/fetcher/refresh_supervisor"

# Test hooks: reach the private guard without running the spawn loop.
class RefreshLoop::Supervisor
  getter stuck_skips : Int32

  def mark_worker_alive_for_test : Nil
    @worker_alive.set(true)
  end

  def run_timed_refresh_for_test : Float64
    run_timed_refresh
  end
end

describe "RefreshLoop::Supervisor worker_alive guard" do
  it "skips the cycle without starting a refresh while the previous worker is alive" do
    config_path = File.join(Dir.tempdir, "qh_skip_#{Process.pid}_#{rand(100000)}.yml")
    File.write(config_path, "cache_dir: #{Dir.tempdir}\nfeeds: []\n")
    config = Config.from_yaml(File.read(config_path))
    cache = create_test_feed_cache
    supervisor = RefreshLoop::Supervisor.new(config, config_path, cache, DatabaseService.instance)

    StateStore.service = QuickHeadlines::Services::AppStateService.new
    StateStore.refreshing = false
    supervisor.mark_worker_alive_for_test

    2.times { supervisor.run_timed_refresh_for_test.should eq(0.0) }
    supervisor.stuck_skips.should eq(2)
    StateStore.refreshing?.should be_false
  ensure
    File.delete(config_path) if config_path && File.exists?(config_path)
  end
end
