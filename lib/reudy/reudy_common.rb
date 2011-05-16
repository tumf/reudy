#Copyright (C) 2003 Gimite 市川 <gimite@mx12.freecom.ne.jp>

#日本語文字コード判定用コメント
$KCODE= "EUC"
require 'kconv'
require 'jcode'


module Gimite


#日本語の出力
def jprint_to(io, *objs)
  str= objs.join("")
  raise(ScriptError.new("$OUT_KCODE is not set.")) if !$OUT_KCODE
  case $OUT_KCODE
    when /^e/i
      io.print(Kconv.toeuc(str))
    when /^s/i
      io.print(Kconv.tosjis(str))
    when /^u/i
      io.print(Kconv.toutf8(str))
    else
      io.print(Kconv.tojis(str))
  end
end

#日本語の出力
def jprint(*objs)
  jprint_to($stdout, *objs)
end

#日本語対応printf
def jprintf(*args)
  jprint(format(*args))
end

#日本語対応puts(手抜き)
def jputs(str)
  jprint(str+"\n")
end

#デバッグ出力
def dprint(caption, *objs)
  strs= []
  for obj in objs
    strs.push(obj.inspect())
  end
  jprint_to($stderr, caption+": "+strs.join("/")+"\n")
end

#contの全ての要素に対してpredが真を返すか。
def for_all?(cont, &pred)
  for item in cont
    return false if !pred.call(item)
  end
  return true
end

#contの中にpredが真を返す要素が存在するか。
def there_exists?(cont, &pred)
  for item in cont
    return true if pred.call(item)
  end
  return false
end

def sigma(range, &block)
  sum= nil
  for v in range
    sum= sum ? (sum+block.call(v)) : block.call(v)
  end
  return sum
end

module_function(:jprint_to, :jprint, :jprintf, :dprint, :for_all?, :there_exists?, :sigma)


end #module Gimite

