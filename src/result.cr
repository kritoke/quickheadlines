struct Result(T, E)
  @value : T?
  @error : E?
  @success : Bool

  private def initialize(@value : T?, @error : E?, @success : Bool)
  end

  def self.success(value : T) : self
    new(value, nil, true)
  end

  def self.failure(error : E) : self
    new(nil, error, false)
  end

  def success? : Bool
    @success
  end

  def failure? : Bool
    !@success
  end

  def value : T
    raise "Result is not successful" unless @success
    @value.not_nil!
  end

  def value? : T?
    @value
  end

  def error : E
    raise "Result is successful" if @success
    @error.not_nil!
  end

  def error? : E?
    @error
  end

  def map(&block : T -> U) : Result(U, E) forall U
    if @success
      Result(U, E).success(yield @value.not_nil!)
    else
      Result(U, E).failure(@error.not_nil!)
    end
  end

  def map_error(&block : E -> F) : Result(T, F) forall F
    if @success
      Result(T, F).success(@value.not_nil!)
    else
      Result(T, F).failure(yield @error.not_nil!)
    end
  end

  def flat_map(&block : T -> Result(U, E)) : Result(U, E) forall U
    if @success
      yield @value.not_nil!
    else
      Result(U, E).failure(@error.not_nil!)
    end
  end

  def value_or(default : T) : T
    @success ? @value.not_nil! : default
  end

  def recover(&block : E -> T) : T
    @success ? @value.not_nil! : yield @error.not_nil!
  end

  def to_s(io : IO) : Nil
    if @success
      io << "Success(" << @value << ")"
    else
      io << "Failure(" << @error << ")"
    end
  end

  def ==(other : Result(T, E)) : Bool
    @success == other.@success && @value == other.@value && @error == other.@error
  end
end

module ResultHelpers
  def self.sequence(results : Array(Result(T, E))) : Result(Array(T), E) forall T, E
    values = [] of T
    results.each do |r|
      return Result(Array(T), E).failure(r.error) if r.failure?
      values << r.value
    end
    Result(Array(T), E).success(values)
  end
end
