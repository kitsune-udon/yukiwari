# Yukiwari

An implementation of PEG parser generator for Ruby

Features
- Resolves direct and indirect left-recursion.
- Uses Virtual Machine, so that it doesn't exhaust the Ruby Interpreter's function stack when a long input is given.
- Uses no external grammar definition file.
- Separates the description of semantic actions from that of rules.

## Installation

    $ cd {cloned or exported dir}

and then execute

    $ bundle && rake build && rake install

or

    $ bundle && gem build yukiwari.gemspec && gem install yukiwari

## Usage

### Grammar Class
- Grammar class provides *rule, action, entry, parser* methods.
- You can use any object types as identifier, but recommends Symbol objects in terms of performace.
#### rule(id, ...) -> self
#### action(id, func) -> self
#### entry(id) -> self
#### parser -> Parser

### Parser Class
- Parser class provides *parse, input, run, accepted?, accepted_string, action_result, result* methods.
- Parser class has other public methods, but they are no use for general users because provided for dubugging.
#### parse(input_string) -> Boolean
#### input(input_string, offset=0) -> self
#### run(max_step=nil) -> self
#### accepted? -> Boolean
#### accepted_string -> String
#### action_result -> Object
#### result -> [Boolean, String, Object]

### ActionArgument Class
- Each action is called only if it successes accepting the corresponding nonterminal symbol. Then, an ActionArgument Class object is passed to the action procedure.
- ActionArgument class provides *id, start_pos, end_pos, elements, content* methods.
#### id -> Object
#### start_pos -> Integer
#### end_pos -> Integer
#### elements -> [Object]
#### content -> String

### Expr Module
In Expr module, there are classes corresponding to PEG notations. The relations are as follows.

| Class Name | PEG Notation | Description |
|:---:|:---:|:---|
| Epsilon | ε |  null |
| Char | [ ] | character class |
| String | "..." | string |
| Optional | ? | zero or one element |
| Rep0 | \* | zero or more repetition |
| Rep1 | + | one or more repetition |
| And | & | and predicate, look-ahead without consumption |
| Not | ! | not predicate, look-ahead without consumption (reverse a success/fail result) |
| Choice | / | ordered choice |
| NT | | nonterminal symbol |

Additionally, sequence is represented by the Ruby's Array class. You can use the bracket notation(e.g. [a,b,c]).

### Notes
- PEG sementics is very different from CFG's. So, It doesn't work by the same way. Refer to the following sample code.
- Particularly, look at the point that the left-associative binary operator is written naturally by left-recursion. In the ordinary way, *Elimination of left-recursion* and *Continuation-passing* are necessary.

### Sample : Calculator
Representation by PEG
```
S <- EXPR EOS
EXPR <- ADDSUB
ADDSUB <- ADDSUB ADDSUB_OP MULDIV / MULDIV
ADDSUB_OP <- "+" / "-"
MULDIV <- MULDIV MULDIV_OP UNARY / UNARY
MULDIV_OP <- "*" / "/"
UNARY <- UNARY_OP UNARY / TERM
UNARY_OP <- "-"
TERM <- BRACE / NUM
BRACE <- "(" EXPR ")"
NUM <- [0-9]+
EOS <- !.
```
Ruby Code
```ruby
require 'yukiwari'

E    = Yukiwari::Expr
V    = E::NT
Eps  = E::Epsilon[]
Char = E::Char
Str  = E::String
Rep1 = E::Rep1
Rep0 = E::Rep0
Opt  = E::Optional
And  = E::And
Not  = E::Not
OC   = E::Choice

g = Yukiwari::Grammar.new
g.rule(:S, V[:EXPR], V[:EOS])
g.rule(:EXPR, V[:ADDSUB])
g.rule(:ADDSUB, OC[[V[:ADDSUB], V[:ADDSUB_OP], V[:MULDIV]], V[:MULDIV]])
g.rule(:ADDSUB_OP, OC[Char["+"], Char["-"]])
g.rule(:MULDIV, OC[[V[:MULDIV], V[:MULDIV_OP], V[:UNARY]], V[:UNARY]])
g.rule(:MULDIV_OP, OC[Char["*"], Char["/"]])
g.rule(:UNARY, OC[[V[:UNARY_OP], V[:UNARY]], V[:TERM]])
g.rule(:UNARY_OP, Char["-"])
g.rule(:TERM, OC[V[:BRACE], V[:NUM]])
g.rule(:BRACE, Char["("], V[:EXPR], Char[")"])
g.rule(:NUM, Rep1[Char[("0".."9").reduce(:+)]])
g.rule(:EOS, Not[Char[""]])

act_through = lambda{|act| act.elements[0]}
g.action(:NUM, lambda{|act| act.content.to_i})
g.action(:BRACE, act_through)
g.action(:TERM, act_through)
g.action(:UNARY_OP, lambda{|act|
  case act.content
  when "-"
    lambda{|x| -x}
  else
    raise "unknown operator"
  end
})
g.action(:UNARY, lambda{|act|
  if act.elements.length == 2
    act.elements[0].call(act.elements[1])
  elsif act.elements.length == 1
    act.elements[0]
  else
    raise "invalid elements number"
  end
})
g.action(:EXPR, act_through)
g.action(:S, act_through)
act_binaryop = lambda{|act|
  if act.elements.length == 3
    act.elements[1].call(act.elements[0], act.elements[2])
  else
    act.elements[0]
  end
}
act_arithop = lambda{|act|
  case act.content
  when "+"
    lambda{|x,y| x+y}
  when "-"
    lambda{|x,y| x-y}
  when "*"
    lambda{|x,y| x*y}
  when "/"
    lambda{|x,y| x/y}
  else
    raise "unknown operator"
  end
}
g.action(:ADDSUB, act_binaryop)
g.action(:ADDSUB_OP, act_arithop)
g.action(:MULDIV, act_binaryop)
g.action(:MULDIV_OP, act_arithop)

g.entry(:S)

parser = g.parser
p parser.parse("-(-9*-8)/-(3*2)-3*(7-2-1)")
p parser.action_result
```

## ToDo
- To support a way to define a grammar by Embeded-DSL.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kitsune-udon/yukiwari.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

