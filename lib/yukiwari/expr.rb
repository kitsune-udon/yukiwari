module Yukiwari::Expr
  APP = Yukiwari
  INST = APP::ISet
  EXPR = APP::Expr

  module_function
  def generate_id
    APP::InternalId[APP::Uniq.id]
  end

  class Expr
    attr_accessor :v
  end

  def generate_code(expr)
    case expr
    when ::Array
      expr.inject([]){|acc,e|acc+generate_code(e)}
    when EXPR::Expr
      expr.code
    else
      raise "invalid expression (%s)" % [expr.inspect]
    end
  end

  class NT < Expr
    def self.[](v); self.new(v); end
    def initialize(v); @v = v; end
    def code
      [
        INST::CALL.call(@v),
        INST::ASSERT_RETURN_VALUE_TRUE,
      ]
    end
  end

  class Epsilon < Expr
    def self.[](); self.new(); end
    def initialize(); end
    def code
      []
    end
  end

  class String < Expr
    def self.[](v); self.new(v); end
    def initialize(v)
      unless ::String===(v)
        raise "%s: invalid argument (%s)" % [v.class, v.inspect]
      end
      @v = v
    end
    def code
      [INST::STRING.call(@v)]
    end
  end

  class Char < Expr
    def self.[](v); self.new(v); end
    def initialize(v)
      unless ::String===(v)
        raise "%s: invalid argument (%s)" % [v.class, v.inspect]
      end
      @v = v
    end
    def code
      if @v.length > 0
        [INST::CHAR.call(@v)]
      else
        [INST::CHAR_ANY]
      end
    end
  end

  class Rep1 < Expr
    def self.[](*v); self.new(*v); end
    def initialize(*v); @v = v; end
    def code
      id0 = EXPR.generate_id
      id1 = EXPR.generate_id
      [
        INST::NEW_COUNTER,
        APP::Label[id0],
        INST::PUSHCONT.call(id1),
      ] + EXPR.generate_code(@v) + [
        INST::POPCONT,
        INST::INCL_COUNTER,
        INST::JUMP.call(id0),
        APP::Label[id1],
        INST::ASSERT_COUNTER_GT_0,
        INST::DELETE_COUNTER
      ]
    end
  end

  class Rep0 < Expr
    def self.[](*v); self.new(*v); end
    def initialize(*v); @v = v; end
    def code
      id0 = EXPR.generate_id
      id1 = EXPR.generate_id
      [
        INST::NEW_COUNTER,
        APP::Label[id0],
        INST::PUSHCONT.call(id1),
      ] + EXPR.generate_code(@v) + [
        INST::POPCONT,
        INST::INCL_COUNTER,
        INST::JUMP.call(id0),
        APP::Label[id1],
        INST::ASSERT_COUNTER_GTE_0,
        INST::DELETE_COUNTER
      ]
    end
  end

  class Optional < Expr
    def self.[](*v); self.new(*v); end
    def initialize(*v); @v = v; end
    def code
      id = EXPR.generate_id
      [
        INST::PUSHCONT.call(id),
      ] + EXPR.generate_code(@v) + [
        INST::POPCONT,
        APP::Label[id],
      ]
    end
  end

  class And < Expr
    def self.[](*v); self.new(*v); end
    def initialize(*v); @v = v; end
    def code
      id = EXPR.generate_id
      [
        INST::NEW_COUNTER,
        INST::PUSHCONT.call(id),
      ] + EXPR.generate_code(@v) + [
        INST::INCL_COUNTER,
        INST::INTERRUPT,
        APP::Label[id],
        INST::ASSERT_COUNTER_EQ_1,
        INST::DELETE_COUNTER,
      ]
    end
  end

  class Not < Expr
    def self.[](*v); self.new(*v); end
    def initialize(*v); @v = v; end
    def code
      id = EXPR.generate_id
      [
        INST::NEW_COUNTER,
        INST::PUSHCONT.call(id),
      ] + EXPR.generate_code(@v) + [
        INST::INCL_COUNTER,
        INST::INTERRUPT,
        APP::Label[id],
        INST::ASSERT_COUNTER_EQ_0,
        INST::DELETE_COUNTER,
      ]
    end
  end

  class Choice < Expr
    def self.[](*v); self.new(*v); end
    def initialize(*v); @v = v; end
    def code
      id_goal = EXPR.generate_id
      r = []
      @v.each do |expr|
        id = EXPR.generate_id
        r += [
          INST::PUSHCONT.call(id),
        ] + EXPR.generate_code(expr) + [
          INST::POPCONT,
          INST::JUMP.call(id_goal),
          APP::Label[id],
        ]
      end
      r += [
        INST::INTERRUPT,
        APP::Label[id_goal],
      ]
      r
    end
  end
end
