# Yukiwari

An implementation of PEG's parser generator

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yukiwari'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install yukiwari

## Usage
Sample : Calculator's definition
```ruby
require 'yukiwari'

parser = Yukiwari::Grammar.new

E = Yukiwari::Expr
EPS = E::Epsilon[]
parser.rule(:S, E::NT[:EXPR], E::NT[:EOS])
parser.rule(:EXPR, E::NT[:ADDSUB])
parser.rule(:ADDSUB, E::Choice[[E::NT[:ADDSUB], E::NT[:ADDSUB_OP], E::NT[:MULDIV]], E::NT[:MULDIV]])
parser.rule(:ADDSUB_OP, E::Choice[E::Char["+"], E::Char["-"]])
parser.rule(:MULDIV, E::Choice[[E::NT[:MULDIV], E::NT[:MULDIV_OP], E::NT[:UNARY]], E::NT[:UNARY]])
parser.rule(:MULDIV_OP, E::Choice[E::Char["*"], E::Char["/"]])
parser.rule(:UNARY, E::Choice[[E::NT[:UNARY_OP], E::NT[:UNARY]], E::NT[:TERM]])
parser.rule(:UNARY_OP, E::Char["-"])
parser.rule(:TERM, E::Choice[E::NT[:BRACE], E::NT[:NUM]])
parser.rule(:BRACE, E::Char["("], E::NT[:EXPR], E::Char[")"])
parser.rule(:NUM, E::Rep1[E::Char[("0".."9").reduce(:+)]])
parser.rule(:EOS, E::Not[E::Char[""]])

act_through = lambda{|act| act.elements[0]}
parser.action(:NUM, lambda{|act| act.content.to_i})
parser.action(:BRACE, act_through)
parser.action(:TERM, act_through)
parser.action(:UNARY_OP, lambda{|act|
  case act.content
  when "-"
    lambda{|x| -x}
  else
    raise "unknown operator"
  end
})
parser.action(:UNARY, lambda{|act|
  if act.elements.length == 2
    act.elements[0].call(act.elements[1])
  elsif act.elements.length == 1
    act.elements[0]
  else
    raise "invalid elements number"
  end
})
parser.action(:EXPR, act_through)
parser.action(:S, act_through)
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
parser.action(:ADDSUB, act_binaryop)
parser.action(:ADDSUB_OP, act_arithop)
parser.action(:MULDIV, act_binaryop)
parser.action(:MULDIV_OP, act_arithop)

parser.entry(:S)

runner = parser.generate_runner
str = "-(-9*-8)/-(3*2)-3*(7-2-1)"
p runner.input(str).run.result
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kitsune-udon/yukiwari.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

