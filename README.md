# Yukiwari

An implementation of PEG parser generator for Ruby

特徴
- 直接間接左再帰を解決する
- 文法を定義した外部ファイルを用いない
- ruleとactionの分離して記述する
- 仮想機械を実行するため処理系の関数コールスタックを食い尽くさない

## Installation

    $ cd <cloned or exported dir>

and then execute

    $ bundle && rake build && rake install

or
    $ bundle && gem build yukiwari.gemspec && gem install yukiwari

## Usage

### Grammer Class
- Grammerクラスには*rule,action,entry,parser*メソッドがある。
- 非終端記号を表現するオブジェクトは何でもよいが、パフォーマンスのためSymbolを用いることを推奨する。

### Parser Class
- Parserクラスには*parse,input,run,accepted?,accepted_string,action_result,result*メソッドがある。
- Parserクラスには他にもpublicなメソッドがあるがデバッグ用なので気にしなくて良い。

### ActionArgument Class
- actionは非終端記号の受理に成功した時のみに呼ばれる。
- ActionArgumentクラスはその時に引数として渡されるオブジェクトである。
- ActionArgumentクラスには*start_pos,end_pos,elements,content*メソッドがある。

### Expr Module
- Exprモジュール内に文法定義のためのクラスがある。PEGの式との対応を以下の表にまとめる。

|Class Name|
|:--------:|
|Epsilon|
|Char|
|String|
|Optional|
|Zero-or-More|
|One-or-More|
|And|
|Not|
|NT|
|Choice|

- なお、連接は*ruby*のArrayクラスで表現される。
- PEGはCFGと大きく異なるため同様の発想で文法を記述すると上手くいかないことが多い。下記のサンプルコードを参考にしてほしい。
- また、左結合の二項オペレータを左再帰を用い自然に書けている点に注目せよ。通常は*左再帰の除去*という文法変更を行い、actionで*継続渡し*を用いる必要がある。

### Sample : Calculator
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

## TODO
- 文法を定義する内部DSLの作成

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kitsune-udon/yukiwari.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

