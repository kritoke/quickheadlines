require "spec"
require "../src/fetcher/semaphore_pool"

describe RefreshLoop::SemaphorePool do
  it "defaults to Constants::CONCURRENCY permits" do
    RefreshLoop::SemaphorePool.new.limit.should eq(QuickHeadlines::Constants::CONCURRENCY)
  end

  it "allows up to limit concurrent holders, then blocks until a release" do
    pool = RefreshLoop::SemaphorePool.new(2)
    pool.acquire
    pool.acquire

    acquired = Channel(Nil).new(1)
    spawn do
      pool.acquire
      acquired.send(nil)
    end

    select
    when acquired.receive
      fail "third acquire should block while two permits are held"
    when timeout(50.milliseconds)
    end

    pool.release
    select
    when acquired.receive
    when timeout(1.second)
      fail "blocked acquirer did not unblock after release"
    end
  end

  it "release never blocks while permits are held" do
    pool = RefreshLoop::SemaphorePool.new(1)
    pool.acquire
    pool.release
    pool.acquire
    pool.release
  end
end
