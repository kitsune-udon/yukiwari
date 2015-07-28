class Yukiwari::Parser
  APP = Yukiwari
  attr_reader :breakpoints, :step_count, :history
  attr_accessor :debug

  def initialize(m,assembly,label_table)
    @m = m
    @assembly = assembly
    @label_table = label_table
    @breakpoints = {}
    @step_count = 0
    @history = []
    @debug = false
  end

  def reset
    @m.reset
    @step_count = 0
    @history = []
    self
  end

  def input(input_string, offset=0)
    @m.input_string = input_string
    @m.offset = offset
    reset
    self
  end

  def resolve_address(ip)
    case ip
    when ::Integer
      ip
    when APP::Label
      i = @label_table[ip.v]
      unless i
        raise "label not found in table (%s)" % [ip.v]
      end
      i
    else
      raise "invalid addressing (%s)" % [ip.inspect]
    end
  end

  def current_inst
    inst = @assembly[@m.ip]
    raise "invalid instruction pointer (%s)" % [@m.ip] unless inst

    inst
  end

  def step(force=false)
    @m.ip = resolve_address(@m.ip)

    if !force && @breakpoints[@m.ip]
      @m.running = false
      return
    end

    h = pre_exec_state if @debug

    inst = current_inst
    inst.v.call(@m)

    if @debug
      h.merge!(post_exec_state)
      add_machine_state_history(h)
    end

    @step_count += 1

    self
  end

  def run(max_step=nil)
    if @breakpoints[resolve_address(@m.ip)]
      @m.running = true
      step(true)
    end
    step while @m.running && (max_step ? (@step_count < max_step) : true)

    self
  end

  def accepted?
    if (top = @m.call_stack[-1]) && (top[0] == -1)
      @m.return_value
    else
      raise "invalid call_stack state"
    end
  end

  def accepted_string
    if accepted?
      if s = @m.input_string
        s[@m.offset...@m.cursor]
      else
        raise "invalid input_string state"
      end
    else
      nil
    end
  end

  def action_result
    if accepted?
      if (top = @m.call_stack[-1]) &&
        ::Array===(top) && (ip = top[0]) &&
        ip == -1 && (action_results = top[3])
        action_results[0]
      else
        raise "invalid call_stack state"
      end
    else
      nil
    end
  end

  def parse(input_string)
    input(input_string)
    run
    accepted?
  end

  def result
    [accepted?,accepted_string,action_result]
  end

  def dump_assembly
    table = {}

    @label_table.each do |k,v|
      table[v] ||= []
      table[v] << k
    end

    @assembly.map.with_index{|inst,addr|
      e = [addr, inst.s]
      labels = table[addr]
      e << labels if labels
      e
    }
  end

  def set_breakpoint(addr)
    @breakpoints[addr] = true
    self
  end

  def unset_breakpoint(addr)
    @breakpoints.delete(addr)
    self
  end

  def clear_breakpoints
    @break_points = {}
    self
  end

  private
  def pre_exec_state
    {
      :step_count => @step_count,
      :inst => @assembly[resolve_address(@m.ip)].s,
      :call_stack_pre => @m.call_stack.inspect,
      :ip_pre => resolve_address(@m.ip),
      :cursor_pre => @m.cursor,
      :memo_pre => @m.memo.inspect,
      :return_value_pre => @m.return_value.inspect,
    }
  end

  def post_exec_state
    {
      :call_stack_post => @m.call_stack.inspect,
      :ip_post => resolve_address(@m.ip),
      :cursor_post => @m.cursor,
      :memo_post => @m.memo.inspect,
      :return_value_post => @m.return_value.inspect,
    }
  end

  def add_machine_state_history(h)
    @history << h
  end
end
