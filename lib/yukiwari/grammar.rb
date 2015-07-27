class Yukiwari::Grammar
  APP = Yukiwari
  INST = APP::ISet

  def initialize
    @rules = {}
    @actions = {}
  end

  def rule(id, *expr)
    @rules[id] = expr

    self
  end

  def action(id, act)
    @actions[id] = act

    self
  end

  def entry(id)
    @entry_id = id

    self
  end

  def generate_runner
    assembly, label_table = compile
    insert_entrycall(assembly, @entry_id) if @entry_id
    m = APP::Machine.new(@actions, leftrec_info)

    APP::Runner.new(m, assembly, label_table)
  end

  private
  def insert_entrycall(assembly, entry_id)
    assembly[0] = APP::ISet::CALL.call(entry_id)
  end

  def leftrec_info
    def inner(expr_array)
      head = expr_array[0]
      return [] unless head

      r = []
      case head
      when ::Array
        r += inner(head)
      when APP::Expr::Char, APP::Expr::String
      when APP::Expr::NT
        r << head.v
      when APP::Expr::Epsilon
        remain = expr_array[1..-1]
        r += inner(remain) if remain
      when APP::Expr::Rep0,APP::Expr::And,APP::Expr::Not,APP::Expr::Optional
        case head.v
        when ::Array
          r += inner(head.v)
        when APP::Expr::Expr
          r += inner([head.v])
        else
          raise "unknown expression"
        end
        remain = expr_array[1..-1]
        r += inner(remain) if remain
      when APP::Expr::Rep1
        case head.v
        when ::Array
          r += inner(head.v)
        when APP::Expr::Expr
          r += inner([head.v])
        else
          raise "unknown expression"
        end
      when APP::Expr::Choice
        head.v.each do |e|
          case e
          when ::Array
            r += inner(e)
          when APP::Expr::Expr
            r += inner([e])
          else
            raise "unknown expression"
          end
        end
      else
        raise "unknown expression"
      end

      r
    end

    def dfs(h,id,stack)
      if stack.include?(id)
        true
      else
        stack.push(id)
        h[id].each do |child_id|
          if dfs(h,child_id,stack)
            stack.pop
            return true
          end
        end
        stack.pop
        false
      end
    end

    h = {}
    @rules.each do |r|
      id, expr = r
      h[id] ||= []
      h[id] += inner(expr)
    end

    r = {}
    @rules.each_key do |id|
      r[id] = dfs(h,id,[])
    end

    r
  end

  def compile
    APP::Uniq.reset
    code = []

    @rules.each do |r|
      id, expr = r
      id0 = APP::Expr.generate_id
      code += [
        APP::Label[id],
        INST::PUSHCONT.call(id0),
      ]
      code += APP::Expr.generate_code(expr)
      code += [
        INST::POPCONT,
        INST::SET_RETURN_VALUE_TRUE,
        INST::RETURN,
        APP::Label[id0],
        INST::SET_RETURN_VALUE_FALSE,
        INST::RETURN,
      ]
    end

    @code = code
    padded_code = [
      INST::HALT,
      INST::HALT,
    ] + code

    table = {}
    addr = 0
    pending = []
    assembly = []

    padded_code.each do |c|
      case c
      when APP::Label
        pending << c
      when APP::Inst
        if pending.length > 0
          pending.each do |label|
            id = label.v
            table[id] = addr
          end
          pending.clear
        end
        assembly << c
        addr += 1
      else
        raise "invalid code: %s" % [c.inspect]
      end
    end

    [assembly, table]
  end
end
