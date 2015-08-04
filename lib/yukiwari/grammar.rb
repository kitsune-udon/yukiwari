class Yukiwari::Grammar
  APP = Yukiwari
  INST = APP::ISet
  E = APP::Expr

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

  def parser
    assembly, label_table = compile
    insert_entrycall(assembly, @entry_id) if @entry_id
    m = APP::Machine.new(@actions, leftrec_info)

    APP::Parser.new(m, assembly, label_table)
  end

  private
  def expr_to_nullability(expr_array)
    expr_array.reduce(APP::Nullability[:Nullable]){|acc,e|
      case e
      when ::Array
        acc * expr_to_nullability(e)
      when E::NT
        acc * APP::Nullability[:Dependent, [[e.v]]]
      when E::Epsilon,E::Rep0,E::Optional,E::And,E::Not
        acc * APP::Nullability[:Nullable]
      when E::Rep1
        acc * expr_to_nullability(::Array===(e.v) ? e.v : [e.v])
      when E::Char,E::String
        acc * APP::Nullability[:NotNullable]
      when E::Choice
        r = e.v.map{|f| ::Array===(f) ? f : [f]}.map{|f| expr_to_nullability(f)}
        acc * r.reduce(APP::Nullability[:NotNullable]){|acc,f| acc + f}
      else
        raise "unknown expr"
      end
    }
  end

  def nullability_info
    deps = []
    resolved = {}
    @rules.each do |r|
      id, expr = r
      r = expr_to_nullability(expr)
      case r.type
      when :Nullable,:NotNullable
        resolved[id] = r
      when :Dependent
        deps << [id, r]
        resolved[id] = r
      else
        raise "unknown nullability type"
      end
    end

    while deps.length > 0
      t = []
      deps.each do |d|
        id, state = d
        r = state.v.map{|xs| xs.reduce(APP::Nullability[:Nullable]){|acc,id|
          acc * resolved[id]
        }}

        if r.any?{|e| e.type == :Nullable}
          resolved[id] = APP::Nullability[:Nullable]
        elsif r.all?{|e| e.type == :NotNullable}
          resolved[id] = APP::Nullability[:NotNullable]
        else
          t << [id, state]
        end
      end
      unless t.length < deps.length
        raise "invalid grammer (nullability undecidable)"
      end
      deps = t
    end

    resolved.to_a.map{|e| [e[0], (e[1].type == :Nullable)]}.to_h
  end

  def insert_entrycall(assembly, entry_id)
    assembly[0] = INST::CALL.call(entry_id)
  end

  def leftrec_info
    def inner(nullability, expr_array)
      head = expr_array[0]
      return [] unless head

      r = []
      case head
      when ::Array
        r += inner(nullability, head)
      when E::Char, E::String
      when E::NT
        if nullability[head.v]
          r << head.v
          remain = expr_array[1..-1]
          r += inner(nullability, remain) if remain
        else
          r << head.v
        end
      when E::Epsilon
        remain = expr_array[1..-1]
        r += inner(nullability, remain) if remain
      when E::Rep0,E::And,E::Not,E::Optional
        case head.v
        when ::Array
          r += inner(nullability, head.v)
        when E::Expr
          r += inner(nullability, [head.v])
        else
          raise "unknown expression"
        end
        remain = expr_array[1..-1]
        r += inner(nullability, remain) if remain
      when E::Rep1
        case head.v
        when ::Array
          r += inner(nullability, head.v)
        when E::Expr
          r += inner(nullability, [head.v])
        else
          raise "unknown expression"
        end
      when E::Choice
        head.v.each do |e|
          case e
          when ::Array
            r += inner(nullability, e)
          when E::Expr
            r += inner(nullability, [e])
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

    nullability = nullability_info

    h = {}
    @rules.each do |r|
      id, expr = r
      h[id] ||= []
      h[id] += inner(nullability, expr)
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
