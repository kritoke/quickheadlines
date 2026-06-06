# MemoryBudget - Plain module for memory budget tracking
#
# Converted from MemoryBudgetActor to a plain module to reduce
# compilation overhead. No Actor macros needed.
#
# Usage:
#   MemoryBudget.can_allocate?("feeds", 50.0)
#   MemoryBudget.allocate("feeds", 50.0)
#   MemoryBudget.release("feeds", 25.0)
#
module MemoryBudget
  extend self

  TOTAL_BUDGET_MB = 750.0

  BUDGETS = {
    "feeds"      => 200.0,
    "websocket"  => 100.0,
    "clustering" => 150.0,
    "caches"     => 100.0,
    "database"   => 50.0,
    "other"      => 50.0,
    "reserve"    => 100.0,
  }

  @@allocated : Hash(String, Float64) = {} of String => Float64
  @@mutex = Mutex.new

  def can_allocate?(subsystem : String, amount_mb : Float64) : Bool
    @@mutex.synchronize do
      budget = BUDGETS[subsystem]? || 0.0
      allocated = @@allocated[subsystem]? || 0.0
      available = budget - allocated

      return false if amount_mb > available

      total_allocated = @@allocated.values.sum
      total_available = TOTAL_BUDGET_MB - total_allocated

      amount_mb <= total_available
    end
  end

  def allocate(subsystem : String, amount_mb : Float64) : Nil
    @@mutex.synchronize do
      unless can_allocate_unsafe(subsystem, amount_mb)
        Log.for("quickheadlines.memory").warn { "Budget allocation denied: #{subsystem} requested #{amount_mb}MB" }
        return
      end

      @@allocated[subsystem] = (@@allocated[subsystem]? || 0.0) + amount_mb
      Log.for("quickheadlines.memory").debug { "Allocated #{amount_mb}MB to #{subsystem} (total: #{@@allocated[subsystem]}MB)" }
    end
  end

  def release(subsystem : String, amount_mb : Float64) : Nil
    @@mutex.synchronize do
      current = @@allocated[subsystem]? || 0.0
      new_allocated = {0.0, current - amount_mb}.max
      @@allocated[subsystem] = new_allocated
      Log.for("quickheadlines.memory").debug { "Released #{amount_mb}MB from #{subsystem} (remaining: #{new_allocated}MB)" }
    end
  end

  def status : {total_budget_mb: Float64, total_allocated_mb: Float64, available_mb: Float64}
    @@mutex.synchronize do
      total_allocated = @@allocated.values.sum
      {
        total_budget_mb:    TOTAL_BUDGET_MB,
        total_allocated_mb: total_allocated,
        available_mb:       TOTAL_BUDGET_MB - total_allocated,
      }
    end
  end

  private def can_allocate_unsafe(subsystem : String, amount_mb : Float64) : Bool
    budget = BUDGETS[subsystem]? || 0.0
    allocated = @@allocated[subsystem]? || 0.0
    available = budget - allocated

    return false if amount_mb > available

    total_allocated = @@allocated.values.sum
    total_available = TOTAL_BUDGET_MB - total_allocated

    amount_mb <= total_available
  end
end
