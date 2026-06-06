module RefreshLoop
  CONCURRENCY_LIMIT = 4

  @@semaphore : Channel(Nil)?
  @@semaphore_counter : Atomic(Int32)?
  @@repair_mutex : Mutex?
  @@init_mutex = Mutex.new(:unchecked)

  def self.ensure_semaphore_initialized! : Nil
    semaphore
    semaphore_counter
    repair_mutex
    nil
  end

  def self.semaphore : Channel(Nil)
    @@init_mutex.synchronize do
      @@semaphore ||= begin
        ch = Channel(Nil).new(CONCURRENCY_LIMIT)
        CONCURRENCY_LIMIT.times { ch.send(nil) }
        ch
      end
    end
  end

  def self.semaphore_counter : Atomic(Int32)
    @@init_mutex.synchronize do
      @@semaphore_counter ||= Atomic(Int32).new(CONCURRENCY_LIMIT)
    end
  end

  def self.repair_mutex : Mutex
    @@init_mutex.synchronize do
      @@repair_mutex ||= Mutex.new(:unchecked)
    end
  end

  private def self.acquire_semaphore : Nil
    semaphore.receive
    semaphore_counter.add(-1, :relaxed)
  end

  private def self.release_semaphore : Nil
    semaphore_counter.add(1, :relaxed)
    semaphore.send(nil)
  rescue Channel::ClosedError
  end

  def self.semaphore_health_status : {available: Int32, expected: Int32}
    available = semaphore_counter.get
    {available: available, expected: CONCURRENCY_LIMIT}
  end

  def self.reset_semaphore : Nil
    while semaphore_counter.get < CONCURRENCY_LIMIT
      semaphore_counter.add(1, :relaxed)
      semaphore.send(nil)
    end
  end
end
