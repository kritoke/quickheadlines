require "../infrastructure/actor"

# MemoryBudgetActor - System-wide memory budget management
#
# This actor provides:
# 1. Centralized memory budget allocation
# 2. Budget enforcement across subsystems
# 3. Dynamic budget adjustment based on pressure
# 4. Budget reporting and monitoring
#
# Usage:
#   MemoryBudgetActor.instance.allocate("feeds", 200.0)
#   MemoryBudgetActor.instance.release("feeds", 50.0)
#   MemoryBudgetActor.instance.get_budget_status
#
class MemoryBudgetActor < Actor
  # =========================================================================
  # Types
  # =========================================================================

  struct BudgetStatus
    getter total_budget_mb : Float64
    getter total_allocated_mb : Float64
    getter available_mb : Float64
    getter utilization_percent : Float32
    getter subsystems : Hash(String, SubsystemBudget)

    def initialize(@total_budget_mb, @total_allocated_mb, @subsystems)
      @available_mb = @total_budget_mb - @total_allocated_mb
      @utilization_percent = @total_budget_mb > 0 ? (@total_allocated_mb / @total_budget_mb * 100).to_f32 : 0.0_f32
    end
  end

  struct SubsystemBudget
    getter name : String
    getter budget_mb : Float64
    getter allocated_mb : Float64
    getter available_mb : Float64
    getter utilization_percent : Float32

    def initialize(@name, @budget_mb, @allocated_mb)
      @available_mb = @budget_mb - @allocated_mb
      @utilization_percent = @budget_mb > 0 ? (@allocated_mb / @budget_mb * 100).to_f32 : 0.0_f32
    end
  end

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_budget_status, BudgetStatus
  def_call can_allocate(subsystem : String, amount_mb : Float64), Bool
  def_call get_subsystem_budget(subsystem : String), SubsystemBudget

  # Cast messages (fire-and-forget)
  def_cast allocate(subsystem : String, amount_mb : Float64)
  def_cast release(subsystem : String, amount_mb : Float64)
  def_cast set_budget(subsystem : String, budget_mb : Float64)
  def_cast adjust_budgets_for_pressure(pressure : MemoryMonitorActor::PressureLevel)

  # =========================================================================
  # Actor state
  # =========================================================================

  TOTAL_BUDGET_MB = 750.0

  @budgets : Hash(String, Float64) = {
    "feeds"       => 200.0,  # 27% - Feed data and items
    "websocket"   => 100.0,  # 13% - WebSocket connections
    "clustering"  => 150.0,  # 20% - Clustering operations
    "caches"      => 100.0,  # 13% - In-memory caches
    "database"    => 50.0,   # 7%  - SQLite overhead
    "other"       => 50.0,   # 7%  - Other operations
    "reserve"     => 100.0,  # 13% - Emergency reserve
  }

  @allocated : Hash(String, Float64) = {} of String => Float64

  def initialize(@name : String = "MemoryBudget")
    super(@name, mailbox_size: 100)
  end

  # Singleton access
  @@instance : MemoryBudgetActor?
  @@instance_mutex = Mutex.new

  def self.instance : MemoryBudgetActor
    @@instance_mutex.synchronize do
      @@instance ||= MemoryBudgetActor.new.tap(&.start)
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetBudgetStatus     then message.deliver_reply(handle_get_budget_status)
    when CallCanAllocate         then message.deliver_reply(handle_can_allocate(message.subsystem, message.amount_mb))
    when CallGetSubsystemBudget  then message.deliver_reply(handle_get_subsystem_budget(message.subsystem))
    when CastAllocate            then handle_allocate(message.subsystem, message.amount_mb)
    when CastRelease             then handle_release(message.subsystem, message.amount_mb)
    when CastSetBudget           then handle_set_budget(message.subsystem, message.budget_mb)
    when CastAdjustBudgetsForPressure then handle_adjust_budgets_for_pressure(message.pressure)
    else raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers
  # =========================================================================

  private def handle_get_budget_status : BudgetStatus
    total_allocated = @allocated.values.sum
    subsystems = {} of String => SubsystemBudget

    @budgets.each do |name, budget|
      allocated = @allocated[name]? || 0.0
      subsystems[name] = SubsystemBudget.new(name, budget, allocated)
    end

    BudgetStatus.new(TOTAL_BUDGET_MB, total_allocated, subsystems)
  end

  private def handle_can_allocate(subsystem : String, amount_mb : Float64) : Bool
    budget = @budgets[subsystem]? || 0.0
    allocated = @allocated[subsystem]? || 0.0
    available = budget - allocated

    # Check if subsystem has enough budget
    return false if amount_mb > available

    # Check if total system budget allows
    total_allocated = @allocated.values.sum
    total_available = TOTAL_BUDGET_MB - total_allocated

    amount_mb <= total_available
  end

  private def handle_get_subsystem_budget(subsystem : String) : SubsystemBudget
    budget = @budgets[subsystem]? || 0.0
    allocated = @allocated[subsystem]? || 0.0
    SubsystemBudget.new(subsystem, budget, allocated)
  end

  private def handle_allocate(subsystem : String, amount_mb : Float64) : Nil
    unless handle_can_allocate(subsystem, amount_mb)
      Log.for("quickheadlines.memory").warn { "Budget allocation denied: #{subsystem} requested #{amount_mb}MB" }
      return
    end

    @allocated[subsystem] = (@allocated[subsystem]? || 0.0) + amount_mb
    Log.for("quickheadlines.memory").debug { "Allocated #{amount_mb}MB to #{subsystem} (total: #{@allocated[subsystem]}MB)" }
  end

  private def handle_release(subsystem : String, amount_mb : Float64) : Nil
    current = @allocated[subsystem]? || 0.0
    new_allocated = {0.0, current - amount_mb}.max
    @allocated[subsystem] = new_allocated
    Log.for("quickheadlines.memory").debug { "Released #{amount_mb}MB from #{subsystem} (remaining: #{new_allocated}MB)" }
  end

  private def handle_set_budget(subsystem : String, budget_mb : Float64) : Nil
    @budgets[subsystem] = budget_mb
    Log.for("quickheadlines.memory").info { "Set budget for #{subsystem} to #{budget_mb}MB" }
  end

  private def handle_adjust_budgets_for_pressure(pressure : MemoryMonitorActor::PressureLevel) : Nil
    case pressure
    when .low?
      # No adjustment needed
    when .medium?
      # Reduce non-essential budgets by 20%
      adjust_budgets(0.8)
    when .high?
      # Reduce non-essential budgets by 50%
      adjust_budgets(0.5)
    when .critical?
      # Reduce to minimum, keep only essential services
      adjust_budgets(0.3)
    end
  end

  private def adjust_budgets(factor : Float64) : Nil
    # Essential subsystems that should not be reduced
    essential = {"memory_management", "shutdown"}

    @budgets.each do |name, budget|
      next if essential.includes?(name)
      @budgets[name] = (budget * factor).round(1)
    end

    Log.for("quickheadlines.memory").info { "Adjusted budgets by factor #{factor}" }
  end
end
