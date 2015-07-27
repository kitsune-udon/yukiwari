module Yukiwari
  module Helper
    module_function
    def to_string(v)
      [String, Symbol].include?(v.class) ? v.inspect : v.to_s
    end
  end

  class Uniq
    @@id = 0
    def self.id
      r = @@id
      @@id += 1
      r
    end
    def self.reset
      @@id = 0
    end
  end

  class Cont
    def self.[](m,jump_target)
      if (top = m.call_stack[-1]) &&
        (action_results = top[3]) &&
        (action_results_size = action_results.length)
        self.new(jump_target,m.cursor,
                 m.call_stack.length,
                 action_results_size,
                 m.counter_stack.length)
      else
        raise "invalid call_stack state"
      end
    end
    def initialize(
      jump_target,cursor,
      call_stack_size,
      action_results_size,
      counter_stack_size)
      @jump_target,@cursor,
        @call_stack_size,
        @action_results_size,
        @counter_stack_size =
        jump_target,cursor,
        call_stack_size,
        action_results_size,
        counter_stack_size
    end
    def to_s; "Cont(%s)" % [self.inspect]; end
    attr_accessor :jump_target,:cursor
    attr_accessor :call_stack_size,:action_results_size,:counter_stack_size
  end

  class Inst
    def self.[](s,v); self.new(s,v); end
    def initialize(s,v); @s,@v = s,v; end
    def to_s; "Inst(#{@s})"; end
    attr_accessor :s,:v
  end

  class InternalId
    def self.[](v); self.new(v); end
    def initialize(v); @v = v; end
    def to_s
      str = Helper.to_string(@v)
      "InternalId(#{str})"
    end
    attr_accessor :v
  end

  class Label
    def self.[](v); self.new(v); end
    def initialize(v); @v = v; end
    def to_s
      str = Helper.to_string(@v)
      "Label(#{str})"
    end
    attr_accessor :v
  end

  class ActionArgument
    attr_accessor :id, :start_pos, :end_pos, :elements
    def self.[](id,offs,elms,m); self.new(id,offs,elms,m); end
    def initialize(id, offset, elements, machine)
      @id = id
      @start_pos = offset
      @end_pos = machine.cursor
      @elements = elements
      @m = machine
    end
    def content
      @m.input_string[@start_pos...@end_pos]
    end
  end
end
