# Yukiwari

An implementation of PEG parser generator for Ruby

特徴
- 直接間接左再帰を解決する
- 文法を定義した外部ファイルを用いない
- ruleとactionの分離して記述する
- 仮想機械を実行するため処理系の関数コールスタックを食い尽くさない

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

### Grammer Class
Grammerクラスにはrule,action,entry,parserメソッドがある。
非終端記号を表現するオブジェクトは何でもよいが、パフォーマンスのためSymbolを用いることを推奨する。

### Parser Class
Parserクラスにはparse,input,run,accepted?,accepted_string,action_result,resultメソッドがある。
Parserクラスには他にもpublicなメソッドがあるがデバッグ用なので気にしなくて良い。

### ActionArgument Class
actionは非終端記号の受理に成功した時のみに呼ばれる。
ActionArgumentクラスはその時に引数として渡されるオブジェクトである。
ActionArgumentクラスにはstart_pos,end_pos,elements,contentメソッドがある。

### Expr Module
Exprモジュール内に文法定義のためのクラスがある。PEGの式との対応を以下の表にまとめる。

Epsilon
Char
String
Optional
Zero-or-More
One-or-More
And
Not
NT
Choice

なお、連接はrubyのArrayクラスで表現される。

PEGはCFGと大きく異なるため同様の発想で文法を記述すると上手くいかないことが多い。
下記のサンプルコードを参考にしてほしい。
また、左結合の二項オペレータを左再帰を用い自然に書けている点に注目せよ。
通常は左再帰の除去という文法変更を行い、actionで継続渡しを用いる必要がある。

### Sample : Definition of Calculator
PEGの表現
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

```ruby
require 'yukiwari'

grammar = Yukiwari::Grammar.new

E = Yukiwari::Expr
EPS = E::Epsilon[]
grammar.rule(:S, E::NT[:EXPR], E::NT[:EOS])
grammar.rule(:EXPR, E::NT[:ADDSUB])
grammar.rule(:ADDSUB, E::Choice[[E::NT[:ADDSUB], E::NT[:ADDSUB_OP], E::NT[:MULDIV]], E::NT[:MULDIV]])
grammar.rule(:ADDSUB_OP, E::Choice[E::Char["+"], E::Char["-"]])
grammar.rule(:MULDIV, E::Choice[[E::NT[:MULDIV], E::NT[:MULDIV_OP], E::NT[:UNARY]], E::NT[:UNARY]])
grammar.rule(:MULDIV_OP, E::Choice[E::Char["*"], E::Char["/"]])
grammar.rule(:UNARY, E::Choice[[E::NT[:UNARY_OP], E::NT[:UNARY]], E::NT[:TERM]])
grammar.rule(:UNARY_OP, E::Char["-"])
grammar.rule(:TERM, E::Choice[E::NT[:BRACE], E::NT[:NUM]])
grammar.rule(:BRACE, E::Char["("], E::NT[:EXPR], E::Char[")"])
grammar.rule(:NUM, E::Rep1[E::Char[("0".."9").reduce(:+)]])
grammar.rule(:EOS, E::Not[E::Char[""]])

act_through = lambda{|act| act.elements[0]}
grammar.action(:NUM, lambda{|act| act.content.to_i})
grammar.action(:BRACE, act_through)
grammar.action(:TERM, act_through)
grammar.action(:UNARY_OP, lambda{|act|
  case act.content
  when "-"
    lambda{|x| -x}
  else
    raise "unknown operator"
  end
})
grammar.action(:UNARY, lambda{|act|
  if act.elements.length == 2
    act.elements[0].call(act.elements[1])
  elsif act.elements.length == 1
    act.elements[0]
  else
    raise "invalid elements number"
  end
})
grammar.action(:EXPR, act_through)
grammar.action(:S, act_through)
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
grammar.action(:ADDSUB, act_binaryop)
grammar.action(:ADDSUB_OP, act_arithop)
grammar.action(:MULDIV, act_binaryop)
grammar.action(:MULDIV_OP, act_arithop)

grammar.entry(:S)

parser = grammar.parser
p parser.parse("-(-9*-8)/-(3*2)-3*(7-2-1)")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kitsune-udon/yukiwari.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

