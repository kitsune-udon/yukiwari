class Yukiwari::Machine
  APP = Yukiwari
  attr_accessor :input_string, :offset, :cursor, :ip, :running, :actions
  attr_accessor :call_stack, :cont_stack, :counter_stack
  attr_accessor :return_value
  attr_accessor :memo
  attr_accessor :call_count

  def initialize(actions, leftrec_info)
    @actions = actions
    @leftrec_info = leftrec_info

    reset
  end

  def reset
    @running = true
    @ip = 0
    @cursor = @offset
    call_bottom = [-1, nil, nil, []]
    @call_stack = [call_bottom]
    @cont_stack = [APP::Cont.new(0,@offset,1,0,0)]
    @counter_stack = []
    @memo = {}
    @return_value = nil
    @call_count = {}

    self
  end

  def interrupt
    e = @cont_stack.pop
    @ip = e.jump_target
    @cursor = e.cursor
    @call_stack.pop(@call_stack.length - e.call_stack_size)
    @counter_stack.pop(@counter_stack.length - e.counter_stack_size)
    action_results = @call_stack[-1][3]
    action_results.pop(action_results.length - e.action_results_size)

    self
  end

  def readchar(offs)
    if ::String===(@input_string)
      if ::Integer===(offs)
        @input_string[offs]
      else
        nil
      end
    else
      nil
    end
  end

  def read(offs, len)
    if ::String===(@input_string)
      if ::Integer===(offs)
        @input_string[offs,len]
      else
        nil
      end
    else
      nil
    end
  end

  def incl
    @ip += 1

    self
  end

  def leftrec?(id)
    @leftrec_info[id]
  end
end
